import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_log_model.dart';
import '../constants/app_constants.dart';

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService.instance;
});

final familyActivityLogsProvider = StreamProvider.family<List<ActivityLogModel>, ({String familyId, String? childId, String? type})>((ref, arg) {
  final service = ref.watch(auditServiceProvider);
  return service.getActivityLogsStream(arg.familyId, childId: arg.childId, type: arg.type);
});

class AuditService {
  static final AuditService instance = AuditService._internal();
  factory AuditService() => instance;
  AuditService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsCollection(String familyId) {
    return _firestore
        .collection(AppConstants.familiesCollection)
        .doc(familyId)
        .collection('activity_logs');
  }

  /// Record an audit log event
  Future<void> logEvent({
    required String familyId,
    required String childId,
    required String childName,
    required String actorId,
    required String actorName,
    String actorRole = 'parent',
    required ActivityType type,
    required String title,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (familyId.isEmpty) return;

    final now = DateTime.now();
    final log = ActivityLogModel(
      id: '',
      familyId: familyId,
      childId: childId,
      childName: childName,
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      type: type,
      title: title,
      description: description,
      timestamp: now,
      metadata: metadata,
    );

    try {
      await _logsCollection(familyId).add(log.toFirestore());
    } catch (e) {
      debugPrint('Error logging audit activity: $e');
    }
  }

  /// Stream activity logs for a family with optional filtering
  Stream<List<ActivityLogModel>> getActivityLogsStream(
    String familyId, {
    String? childId,
    String? type,
    int limit = 60,
  }) {
    if (familyId.isEmpty) return Stream.value([]);

    Query<Map<String, dynamic>> query = _logsCollection(familyId);

    if (childId != null && childId.isNotEmpty) {
      query = query.where('childId', isEqualTo: childId);
    }
    if (type != null && type.isNotEmpty && type != 'all') {
      query = query.where('type', isEqualTo: type);
    }

    // Limit and fetch; client-side sort to avoid composite index requirements
    return query.limit(limit).snapshots().map((snap) {
      final list = snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }
}

