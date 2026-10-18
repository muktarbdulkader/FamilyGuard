import 'package:cloud_firestore/cloud_firestore.dart';

enum EduFileType {
  pdf,
  doc,
  presentation,
  video,
  image,
  url;

  String get displayName => switch (this) {
        EduFileType.pdf => 'PDF Document',
        EduFileType.doc => 'Word Document',
        EduFileType.presentation => 'Presentation',
        EduFileType.video => 'Video Lesson',
        EduFileType.image => 'Image / Diagram',
        EduFileType.url => 'Web Link',
      };

  String get badgeLabel => switch (this) {
        EduFileType.pdf => 'PDF',
        EduFileType.doc => 'DOC',
        EduFileType.presentation => 'PPT',
        EduFileType.video => 'MP4',
        EduFileType.image => 'IMG',
        EduFileType.url => 'LINK',
      };

  String get extensionBadge => badgeLabel;

  static EduFileType fromExtension(String? extension, {bool isUrl = false}) {
    if (isUrl) return EduFileType.url;
    final ext = (extension ?? '').toLowerCase().replaceAll('.', '').trim();
    return switch (ext) {
      'pdf' => EduFileType.pdf,
      'doc' || 'docx' => EduFileType.doc,
      'ppt' || 'pptx' => EduFileType.presentation,
      'mp4' || 'm4v' || 'mov' || 'avi' || 'mkv' => EduFileType.video,
      'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => EduFileType.image,
      _ => EduFileType.url,
    };
  }
}

enum LearningStatus {
  pending,
  inProgress,
  completed;

  String get displayName => switch (this) {
        LearningStatus.pending => 'Not Started',
        LearningStatus.inProgress => 'In Progress',
        LearningStatus.completed => 'Completed',
      };

  String get label => displayName;

  static LearningStatus fromString(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'completed' => LearningStatus.completed,
      'inprogress' || 'in_progress' => LearningStatus.inProgress,
      _ => LearningStatus.pending,
    };
  }
}

class ChildLearningProgress {
  final String childId;
  final String childName;
  final LearningStatus status;
  final DateTime? completedAt;
  final DateTime? lastAccessedAt;
  final String? notes;

  const ChildLearningProgress({
    required this.childId,
    this.childName = 'Child',
    this.status = LearningStatus.pending,
    this.completedAt,
    this.lastAccessedAt,
    this.notes,
  });

  factory ChildLearningProgress.fromMap(String childId, Map<String, dynamic> map) {
    return ChildLearningProgress(
      childId: childId,
      childName: (map['childName'] as String?) ?? 'Child',
      status: LearningStatus.fromString(map['status'] as String?),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      lastAccessedAt: (map['lastAccessedAt'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'childName': childName,
      'status': status.name,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'lastAccessedAt': lastAccessedAt != null ? Timestamp.fromDate(lastAccessedAt!) : null,
      if (notes != null) 'notes': notes,
    };
  }

  ChildLearningProgress copyWith({
    LearningStatus? status,
    DateTime? completedAt,
    DateTime? lastAccessedAt,
    String? notes,
  }) {
    return ChildLearningProgress(
      childId: childId,
      childName: childName,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      notes: notes ?? this.notes,
    );
  }
}

class EducationalMaterial {
  final String id;
  final String familyId;
  final String parentId;
  final String parentName;
  final String title;
  final String description;
  final String subject;
  final String gradeLevel;
  final EduFileType materialType;
  final String fileUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final String? storagePath;
  final String? instructions;
  final DateTime? dueDate;
  final List<String> assignedChildIds;
  final Map<String, String> assignedChildNames;
  final Map<String, ChildLearningProgress> childProgress;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EducationalMaterial({
    required this.id,
    required this.familyId,
    required this.parentId,
    this.parentName = 'Parent',
    required this.title,
    this.description = '',
    this.subject = 'General',
    this.gradeLevel = 'All Grades',
    required this.materialType,
    required this.fileUrl,
    this.fileName,
    this.fileSizeBytes,
    this.storagePath,
    this.instructions,
    this.dueDate,
    this.assignedChildIds = const [],
    this.assignedChildNames = const {},
    this.childProgress = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  // Backward-compatible & ergonomic aliases
  EduFileType get type => materialType;
  String get effectiveUrl => fileUrl;
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now());
  bool get isExpired => isOverdue;

  bool isCompletedBy(String childId) {
    return childProgress[childId]?.status == LearningStatus.completed;
  }

  LearningStatus statusFor(String childId) {
    return childProgress[childId]?.status ?? LearningStatus.pending;
  }

  double get completionRate {
    if (assignedChildIds.isEmpty) return 0.0;
    final completedCount = assignedChildIds.where(isCompletedBy).length;
    return completedCount / assignedChildIds.length;
  }

  factory EducationalMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawAssignedIds = (data['assignedChildIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final rawChildNames = <String, String>{};
    if (data['assignedChildNames'] is Map) {
      (data['assignedChildNames'] as Map).forEach((k, v) {
        rawChildNames[k.toString()] = v.toString();
      });
    }

    final progressMap = <String, ChildLearningProgress>{};
    final rawProgress = data['childProgress'] as Map<dynamic, dynamic>? ?? {};
    for (final entry in rawProgress.entries) {
      if (entry.value is Map) {
        try {
          progressMap[entry.key.toString()] = ChildLearningProgress.fromMap(
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (_) {}
      }
    }

    for (final childId in rawAssignedIds) {
      if (!progressMap.containsKey(childId)) {
        progressMap[childId] = ChildLearningProgress(
          childId: childId,
          childName: rawChildNames[childId] ?? 'Child',
          status: LearningStatus.pending,
        );
      }
    }

    final rawType = (data['materialType'] as String?) ?? '';
    final type = EduFileType.values.firstWhere(
      (e) => e.name.toLowerCase() == rawType.toLowerCase(),
      orElse: () => EduFileType.fromExtension(data['fileName'] as String?),
    );

    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return fallback ?? DateTime.now();
    }

    return EducationalMaterial(
      id: doc.id,
      familyId: (data['familyId'] ?? '').toString(),
      parentId: (data['parentId'] ?? '').toString(),
      parentName: (data['parentName'] ?? 'Parent').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      subject: (data['subject'] ?? 'General').toString(),
      gradeLevel: (data['gradeLevel'] ?? 'All Grades').toString(),
      materialType: type,
      fileUrl: (data['fileUrl'] ?? '').toString(),
      fileName: data['fileName'] as String?,
      fileSizeBytes: data['fileSizeBytes'] as int?,
      storagePath: data['storagePath'] as String?,
      instructions: data['instructions'] as String?,
      dueDate: data['dueDate'] != null ? parseDate(data['dueDate'], null) : null,
      assignedChildIds: rawAssignedIds,
      assignedChildNames: rawChildNames,
      childProgress: progressMap,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'parentId': parentId,
      'parentName': parentName,
      'title': title,
      'description': description,
      'subject': subject,
      'gradeLevel': gradeLevel,
      'materialType': materialType.name,
      'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      if (storagePath != null) 'storagePath': storagePath,
      if (instructions != null) 'instructions': instructions,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      'assignedChildIds': assignedChildIds,
      'assignedChildNames': assignedChildNames,
      'childProgress': childProgress.map((k, v) => MapEntry(k, v.toMap())),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EducationalMaterial copyWith({
    String? title,
    String? description,
    String? subject,
    String? gradeLevel,
    EduFileType? materialType,
    String? fileUrl,
    String? fileName,
    int? fileSizeBytes,
    String? storagePath,
    String? instructions,
    DateTime? dueDate,
    List<String>? assignedChildIds,
    Map<String, String>? assignedChildNames,
    Map<String, ChildLearningProgress>? childProgress,
    DateTime? updatedAt,
  }) {
    return EducationalMaterial(
      id: id,
      familyId: familyId,
      parentId: parentId,
      parentName: parentName,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      materialType: materialType ?? this.materialType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      storagePath: storagePath ?? this.storagePath,
      instructions: instructions ?? this.instructions,
      dueDate: dueDate ?? this.dueDate,
      assignedChildIds: assignedChildIds ?? this.assignedChildIds,
      assignedChildNames: assignedChildNames ?? this.assignedChildNames,
      childProgress: childProgress ?? this.childProgress,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
