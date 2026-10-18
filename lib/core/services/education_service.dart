import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/educational_task_model.dart';
import '../models/educational_material_model.dart';
import '../constants/app_constants.dart';

final educationServiceProvider = Provider<EducationService>((ref) {
  return EducationService();
});

final childEducationTasksProvider = StreamProvider.family<List<EducationalTask>, ({String familyId, String childId})>((ref, arg) {
  final service = ref.watch(educationServiceProvider);
  return service.getTasksStream(arg.familyId, arg.childId);
});

final familyEducationalMaterialsProvider = StreamProvider.family<List<EducationalMaterial>, String>((ref, familyId) {
  final service = ref.watch(educationServiceProvider);
  return service.getFamilyMaterialsStream(familyId);
});

final childEducationalMaterialsProvider = StreamProvider.family<List<EducationalMaterial>, ({String familyId, String childId})>((ref, arg) {
  final service = ref.watch(educationServiceProvider);
  return service.getChildMaterialsStream(arg.familyId, arg.childId);
});

class EducationService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  EducationService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _materialsCollection(String familyId) {
    return _firestore
        .collection(AppConstants.familiesCollection)
        .doc(familyId)
        .collection('educational_materials');
  }

  // ── Material CRUD & Storage Operations ───────────────────────────────────

  /// Upload a file to Firebase Storage with progress callback
  Future<({String downloadUrl, String storagePath, int fileSizeBytes, String fileName})> uploadMaterialFile({
    required String familyId,
    required String materialId,
    required PlatformFile file,
    void Function(double progress)? onProgress,
  }) async {
    final cleanFileName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'families/$familyId/education/${materialId}_$cleanFileName';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: _resolveContentType(file.extension),
      customMetadata: {
        'familyId': familyId,
        'materialId': materialId,
        'originalName': file.name,
      },
    );

    UploadTask uploadTask;
    if (file.bytes != null) {
      uploadTask = ref.putData(file.bytes!, metadata);
    } else if (file.path != null) {
      uploadTask = ref.putFile(File(file.path!), metadata);
    } else {
      throw Exception('Selected file has no data or path to upload.');
    }

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return (
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      fileSizeBytes: file.size,
      fileName: file.name,
    );
  }

  String _resolveContentType(String? extension) {
    return switch ((extension ?? '').toLowerCase()) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'mp4' => 'video/mp4',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  /// Create a new educational material and notify assigned children
  Future<void> createMaterial(EducationalMaterial material) async {
    final docRef = _materialsCollection(material.familyId).doc(material.id);
    await docRef.set(material.toFirestore());

    // Send notifications to each assigned child and sync to tasks
    for (final childId in material.assignedChildIds) {
      try {
        await _firestore.collection('notifications').add({
          'familyId': material.familyId,
          'childId': childId,
          'type': 'educational_material',
          'priority': 'normal',
          'title': '📚 New Material: ${material.title}',
          'body': '${material.parentName} assigned a new ${material.subject} material for you.',
          'data': {
            'type': 'educational_material',
            'materialId': material.id,
            'title': material.title,
            'subject': material.subject,
            'fileUrl': material.fileUrl,
            'materialType': material.materialType.name,
          },
          'createdAt': Timestamp.now(),
          'isRead': false,
        });
      } catch (e) {
        debugPrint('Error sending child notification for material: $e');
      }

      // Also create backward-compatible legacy task doc in child subcollection
      final taskMap = {
        'id': material.id,
        'familyId': material.familyId,
        'childId': childId,
        'title': material.title,
        'subject': material.subject,
        'note': material.instructions ?? material.description,
        'url': material.fileUrl,
        'senderName': material.parentName,
        'createdAt': Timestamp.fromDate(material.createdAt),
        'isCompleted': false,
        'completedAt': null,
      };

      try {
        await _tasksCollection(material.familyId, childId).doc(material.id).set(taskMap);
      } catch (_) {}

      try {
        await _childDoc(material.familyId, childId).set({
          'hasEducationTasks': true,
          'educationTasks': FieldValue.arrayUnion([taskMap]),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Update metadata of an existing educational material
  Future<void> updateMaterial(EducationalMaterial material) async {
    final docRef = _materialsCollection(material.familyId).doc(material.id);
    await docRef.set(material.copyWith(updatedAt: DateTime.now()).toFirestore(), SetOptions(merge: true));
  }

  /// Delete an educational material and remove its file from Firebase Storage
  Future<void> deleteMaterial({
    required String familyId,
    required String materialId,
    String? storagePath,
    List<String> assignedChildIds = const [],
  }) async {
    // 1. Delete document
    try {
      await _materialsCollection(familyId).doc(materialId).delete();
    } catch (_) {}

    // 2. Also delete from child tasks
    for (final childId in assignedChildIds) {
      await deleteTask(familyId: familyId, childId: childId, taskId: materialId);
    }

    // 3. Delete file from Storage if applicable
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _storage.ref().child(storagePath).delete();
      } catch (e) {
        debugPrint('Notice: Storage file delete: $e');
      }
    }
  }

  /// Stream of all educational materials in the family for parents
  Stream<List<EducationalMaterial>> getFamilyMaterialsStream(String familyId) {
    if (familyId.isEmpty) return Stream.value([]);

    return _materialsCollection(familyId)
        .snapshots()
        .map((snapshot) {
          final list = <EducationalMaterial>[];
          for (final doc in snapshot.docs) {
            try {
              list.add(EducationalMaterial.fromFirestore(doc));
            } catch (e) {
              debugPrint('Error parsing material ${doc.id}: $e');
            }
          }
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Stream of educational materials assigned to a specific child
  Stream<List<EducationalMaterial>> getChildMaterialsStream(String familyId, String childId) {
    if (familyId.isEmpty || childId.isEmpty) return Stream.value([]);

    return _materialsCollection(familyId)
        .snapshots()
        .map((snapshot) {
          final list = <EducationalMaterial>[];
          for (final doc in snapshot.docs) {
            try {
              final mat = EducationalMaterial.fromFirestore(doc);
              // Include if explicitly assigned to this child OR if assigned to all children (empty list)
              if (mat.assignedChildIds.isEmpty || mat.assignedChildIds.contains(childId)) {
                list.add(mat);
              }
            } catch (e) {
              debugPrint('Error parsing child material ${doc.id}: $e');
            }
          }
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Update a child's learning progress (e.g. mark as completed, in progress)
  Future<void> updateChildProgress({
    required String familyId,
    required String materialId,
    required String childId,
    required LearningStatus status,
    String? childName,
    String? notes,
  }) async {
    final now = DateTime.now();
    final isDone = status == LearningStatus.completed;

    final progress = ChildLearningProgress(
      childId: childId,
      childName: childName ?? 'Child',
      status: status,
      completedAt: isDone ? now : null,
      lastAccessedAt: now,
      notes: notes,
    );

    // Update in family educational_materials collection
    final docRef = _materialsCollection(familyId).doc(materialId);
    await docRef.update({
      'childProgress.$childId': progress.toMap(),
      'updatedAt': Timestamp.fromDate(now),
    });

    // Also update legacy task completion for backward compatibility
    await toggleTaskCompletion(
      familyId: familyId,
      childId: childId,
      taskId: materialId,
      isCompleted: isDone,
    );

    // If completed, notify parent
    if (isDone) {
      try {
        final matDoc = await docRef.get();
        final matTitle = matDoc.data()?['title'] ?? 'Educational Material';
        final resolvedName = childName ?? 'Your child';

        final notifData = {
          'familyId': familyId,
          'childId': childId,
          'childName': resolvedName,
          'type': 'educational_completed',
          'priority': 'normal',
          'title': '🌟 $resolvedName completed a lesson!',
          'body': '$resolvedName finished studying "$matTitle". Great work!',
          'data': {
            'type': 'educational_completed',
            'materialId': materialId,
            'title': matTitle,
            'childId': childId,
          },
          'createdAt': Timestamp.fromDate(now),
          'isRead': false,
        };

        await _firestore.collection('notifications').add(notifData);
        try {
          await _firestore
              .collection(AppConstants.familiesCollection)
              .doc(familyId)
              .collection('notifications')
              .add(notifData);
        } catch (_) {}
      } catch (e) {
        debugPrint('Error writing completion notification: $e');
      }
    }
  }

  // ── Legacy Backwards-Compatible Methods ─────────────────────────────────

  CollectionReference<Map<String, dynamic>> _tasksCollection(String familyId, String childId) {
    return _firestore
        .collection(AppConstants.familiesCollection)
        .doc(familyId)
        .collection(AppConstants.childrenSubcollection)
        .doc(childId)
        .collection('education_tasks');
  }

  DocumentReference<Map<String, dynamic>> _childDoc(String familyId, String childId) {
    return _firestore
        .collection(AppConstants.familiesCollection)
        .doc(familyId)
        .collection(AppConstants.childrenSubcollection)
        .doc(childId);
  }

  Stream<List<EducationalTask>> getTasksStream(String familyId, String childId) {
    if (familyId.isEmpty || childId.isEmpty) {
      return Stream.value([]);
    }

    final controller = StreamController<List<EducationalTask>>.broadcast();
    StreamSubscription? subcollectionSubscription;
    StreamSubscription? fallbackSubscription;

    void startFallback() {
      fallbackSubscription = _childDoc(familyId, childId).snapshots().listen(
        (doc) {
          if (!doc.exists) {
            controller.add([]);
            return;
          }
          final data = doc.data() ?? {};
          final rawList = data['educationTasks'] as List<dynamic>? ?? [];
          final tasks = rawList.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return EducationalTask(
              id: (map['id'] ?? '').toString(),
              familyId: familyId,
              childId: childId,
              title: (map['title'] ?? 'Task').toString(),
              subject: (map['subject'] ?? 'General').toString(),
              note: (map['note'] ?? '').toString(),
              url: map['url'] as String?,
              senderName: (map['senderName'] ?? 'Parent').toString(),
              createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isCompleted: map['isCompleted'] as bool? ?? false,
              completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
            );
          }).toList();
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          controller.add(tasks);
        },
        onError: (err) {
          debugPrint('Fallback tasks stream error: $err');
          controller.add([]);
        },
      );
    }

    subcollectionSubscription = _tasksCollection(familyId, childId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        final tasks = snapshot.docs.map((doc) => EducationalTask.fromFirestore(doc)).toList();
        controller.add(tasks);
      },
      onError: (err) {
        debugPrint('Subcollection education_tasks permission error: $err');
        subcollectionSubscription?.cancel();
        startFallback();
      },
    );

    controller.onCancel = () {
      subcollectionSubscription?.cancel();
      fallbackSubscription?.cancel();
    };

    return controller.stream;
  }

  Future<void> sendEducationalTask({
    required String familyId,
    required String childId,
    required String title,
    required String subject,
    required String note,
    String? url,
    required String senderName,
    String? childName,
    PlatformFile? file,
  }) async {
    final docRef = _tasksCollection(familyId, childId).doc();
    final taskId = docRef.id;

    String fileUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : '';
    String? storagePath;
    String? fileName;
    int? fileSizeBytes;
    EduFileType matType = fileUrl.isNotEmpty ? EduFileType.url : EduFileType.doc;

    if (file != null) {
      try {
        final uploadResult = await uploadMaterialFile(
          familyId: familyId,
          materialId: taskId,
          file: file,
        );
        fileUrl = uploadResult.downloadUrl;
        storagePath = uploadResult.storagePath;
        fileName = uploadResult.fileName;
        fileSizeBytes = uploadResult.fileSizeBytes;
        matType = EduFileType.fromExtension(file.extension);
      } catch (e) {
        debugPrint('Error uploading file in sendEducationalTask: $e');
      }
    }

    final taskMap = {
      'id': taskId,
      'familyId': familyId,
      'childId': childId,
      'title': title.trim(),
      'subject': subject,
      'note': note.trim(),
      'url': fileUrl.isNotEmpty ? fileUrl : null,
      'senderName': senderName,
      'createdAt': Timestamp.now(),
      'isCompleted': false,
      'completedAt': null,
    };

    try {
      await docRef.set(taskMap);
    } catch (_) {}

    try {
      await _childDoc(familyId, childId).set({
        'hasEducationTasks': true,
        'educationTasks': FieldValue.arrayUnion([taskMap]),
      }, SetOptions(merge: true));
    } catch (_) {}

    // Synchronize to educational_materials collection so both parents & children see it
    final now = DateTime.now();
    final material = EducationalMaterial(
      id: taskId,
      familyId: familyId,
      parentId: '',
      parentName: senderName,
      title: title.trim(),
      description: note.trim(),
      subject: subject,
      gradeLevel: 'All Grades',
      materialType: matType,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      storagePath: storagePath,
      instructions: note.trim().isNotEmpty ? note.trim() : null,
      assignedChildIds: [childId],
      assignedChildNames: childName != null ? {childId: childName} : {},
      childProgress: {
        childId: ChildLearningProgress(
          childId: childId,
          childName: childName ?? 'Child',
          status: LearningStatus.pending,
        ),
      },
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _materialsCollection(familyId).doc(taskId).set(material.toFirestore());
    } catch (e) {
      debugPrint('Error writing to materialsCollection in sendEducationalTask: $e');
    }

    // Send notification to child
    try {
      await _firestore.collection('notifications').add({
        'familyId': familyId,
        'childId': childId,
        'type': 'educational_material',
        'priority': 'normal',
        'title': '📚 New Study Material: ${title.trim()}',
        'body': '$senderName assigned a new $subject lesson for you.',
        'data': {
          'type': 'educational_material',
          'materialId': taskId,
          'title': title.trim(),
          'subject': subject,
          'fileUrl': fileUrl,
          'materialType': matType.name,
        },
        'createdAt': Timestamp.now(),
        'isRead': false,
      });
    } catch (_) {}
  }

  Future<void> toggleTaskCompletion({
    required String familyId,
    required String childId,
    required String taskId,
    required bool isCompleted,
  }) async {
    final now = Timestamp.now();
    try {
      await _tasksCollection(familyId, childId).doc(taskId).update({
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? now : null,
      });
    } catch (_) {}

    try {
      final childSnapshot = await _childDoc(familyId, childId).get();
      if (childSnapshot.exists) {
        final rawList = childSnapshot.data()?['educationTasks'] as List<dynamic>? ?? [];
        final updatedList = rawList.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['id'] == taskId) {
            map['isCompleted'] = isCompleted;
            map['completedAt'] = isCompleted ? now : null;
          }
          return map;
        }).toList();
        await _childDoc(familyId, childId).update({'educationTasks': updatedList});
      }
    } catch (_) {}
  }

  Future<void> deleteTask({
    required String familyId,
    required String childId,
    required String taskId,
  }) async {
    try {
      await _tasksCollection(familyId, childId).doc(taskId).delete();
    } catch (_) {}

    try {
      await _materialsCollection(familyId).doc(taskId).delete();
    } catch (_) {}

    try {
      final childSnapshot = await _childDoc(familyId, childId).get();
      if (childSnapshot.exists) {
        final rawList = childSnapshot.data()?['educationTasks'] as List<dynamic>? ?? [];
        final updatedList = rawList.where((item) => (item as Map)['id'] != taskId).toList();
        await _childDoc(familyId, childId).update({'educationTasks': updatedList});
      }
    } catch (_) {}
  }
}
