import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ActivityType {
  ruleChange,
  timeExtension,
  routineToggle,
  permissionTamper,
  emergencySos,
  quizCompleted;

  String get displayName => switch (this) {
        ActivityType.ruleChange => 'Rule Updated',
        ActivityType.timeExtension => 'Screen Time Granted',
        ActivityType.routineToggle => 'Routine Changed',
        ActivityType.permissionTamper => 'Security / Permission Warning',
        ActivityType.emergencySos => 'Emergency SOS Alert',
        ActivityType.quizCompleted => 'Quiz Completed',
      };

  IconData get icon => switch (this) {
        ActivityType.ruleChange => Icons.rule_rounded,
        ActivityType.timeExtension => Icons.more_time_rounded,
        ActivityType.routineToggle => Icons.schedule_rounded,
        ActivityType.permissionTamper => Icons.warning_amber_rounded,
        ActivityType.emergencySos => Icons.emergency_rounded,
        ActivityType.quizCompleted => Icons.school_rounded,
      };

  Color get color => switch (this) {
        ActivityType.ruleChange => const Color(0xFF3B82F6),
        ActivityType.timeExtension => const Color(0xFF10B981),
        ActivityType.routineToggle => const Color(0xFF8B5CF6),
        ActivityType.permissionTamper => const Color(0xFFEF4444),
        ActivityType.emergencySos => const Color(0xFFDC2626),
        ActivityType.quizCompleted => const Color(0xFFF59E0B),
      };

  static ActivityType fromString(String? type) {
    return switch ((type ?? '').toLowerCase()) {
      'time_extension' || 'timeextension' => ActivityType.timeExtension,
      'routine_toggle' || 'routinetoggle' => ActivityType.routineToggle,
      'permission_tamper' || 'permissiontamper' => ActivityType.permissionTamper,
      'emergency_sos' || 'emergencysos' || 'sos' => ActivityType.emergencySos,
      'quiz_completed' || 'quizcompleted' => ActivityType.quizCompleted,
      _ => ActivityType.ruleChange,
    };
  }

  String toDbString() => switch (this) {
        ActivityType.ruleChange => 'rule_change',
        ActivityType.timeExtension => 'time_extension',
        ActivityType.routineToggle => 'routine_toggle',
        ActivityType.permissionTamper => 'permission_tamper',
        ActivityType.emergencySos => 'emergency_sos',
        ActivityType.quizCompleted => 'quiz_completed',
      };
}

class ActivityLogModel {
  final String id;
  final String familyId;
  final String childId;
  final String childName;
  final String actorId;
  final String actorName;
  final String actorRole; // 'parent', 'child', 'system'
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ActivityLogModel({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.childName,
    required this.actorId,
    required this.actorName,
    this.actorRole = 'parent',
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.metadata = const {},
  });

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return ActivityLogModel(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      childName: data['childName'] as String? ?? 'Child',
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'System',
      actorRole: data['actorRole'] as String? ?? 'system',
      type: ActivityType.fromString(data['type'] as String?),
      title: data['title'] as String? ?? 'Activity Log',
      description: data['description'] as String? ?? '',
      timestamp: parseTimestamp(data['timestamp'] ?? data['createdAt']),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'childId': childId,
      'childName': childName,
      'actorId': actorId,
      'actorName': actorName,
      'actorRole': actorRole,
      'type': type.toDbString(),
      'title': title,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

