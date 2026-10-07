import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Enum for different rule types
enum RuleType {
  appLimit,      // Daily time limit for specific app
  appBlock,      // Block app completely
  appSchedule,   // Time window when app is allowed
  screenTime,    // Total device screen time limit
  bedtime,       // Device bedtime schedule
  appRequest,    // Require parent approval for new apps
  category,      // Rules for app categories (games, social, etc.)
}

/// Enum for rule status
enum RuleStatus {
  active,
  paused,
  expired,
  disabled,
}

/// Enum for time periods
enum TimePeriod {
  daily,
  weekly,
  weekdays,
  weekends,
  custom,
}

/// Enum for app categories
enum AppCategory {
  games,
  social,
  educational,
  entertainment,
  productivity,
  communication,
  shopping,
  other,
}

/// Main rule model for parental controls
class RuleModel {
  final String id;
  final String familyId;
  final String childId;
  final String ruleName;
  final RuleType type;
  final RuleStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  
  // App-specific rules
  final String? appPackageName;
  final String? appName;
  final AppCategory? appCategory;
  
  // Time-based settings
  final int? dailyLimitMinutes;
  final int? weeklyLimitMinutes;
  final TimePeriod? timePeriod;
  final TimeOfDay? allowedStartTime;
  final TimeOfDay? allowedEndTime;
  final List<int>? allowedDays; // 1=Monday, 7=Sunday
  
  // Screen time settings
  final int? totalScreenTimeMinutes;
  final TimeOfDay? bedtimeStart;
  final TimeOfDay? bedtimeEnd;
  final bool? bedtimeEnabled;
  
  // Request and notification settings
  final bool? requireApproval;
  final bool? sendNotifications;
  final int? warningMinutes; // Minutes before limit to warn
  
  // Custom settings
  final Map<String, dynamic>? customSettings;
  final String? description;
  final List<String>? tags;

  const RuleModel({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.ruleName,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.activatedAt,
    this.expiresAt,
    this.appPackageName,
    this.appName,
    this.appCategory,
    this.dailyLimitMinutes,
    this.weeklyLimitMinutes,
    this.timePeriod,
    this.allowedStartTime,
    this.allowedEndTime,
    this.allowedDays,
    this.totalScreenTimeMinutes,
    this.bedtimeStart,
    this.bedtimeEnd,
    this.bedtimeEnabled,
    this.requireApproval,
    this.sendNotifications,
    this.warningMinutes,
    this.customSettings,
    this.description,
    this.tags,
  });

  /// Create from Firestore document
  factory RuleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RuleModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      childId: data['childId'] ?? '',
      ruleName: data['ruleName'] ?? '',
      type: RuleType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => RuleType.appLimit,
      ),
      status: RuleStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RuleStatus.active,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      activatedAt: (data['activatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      appPackageName: data['appPackageName'],
      appName: data['appName'],
      appCategory: data['appCategory'] != null
          ? AppCategory.values.firstWhere(
              (e) => e.name == data['appCategory'],
              orElse: () => AppCategory.other,
            )
          : null,
      dailyLimitMinutes: data['dailyLimitMinutes'],
      weeklyLimitMinutes: data['weeklyLimitMinutes'],
      timePeriod: data['timePeriod'] != null
          ? TimePeriod.values.firstWhere(
              (e) => e.name == data['timePeriod'],
              orElse: () => TimePeriod.daily,
            )
          : null,
      allowedStartTime: data['allowedStartTime'] != null
          ? _parseTimeOfDay(data['allowedStartTime'])
          : null,
      allowedEndTime: data['allowedEndTime'] != null
          ? _parseTimeOfDay(data['allowedEndTime'])
          : null,
      allowedDays: data['allowedDays'] != null
          ? List<int>.from(data['allowedDays'])
          : null,
      totalScreenTimeMinutes: data['totalScreenTimeMinutes'],
      bedtimeStart: data['bedtimeStart'] != null
          ? _parseTimeOfDay(data['bedtimeStart'])
          : null,
      bedtimeEnd: data['bedtimeEnd'] != null
          ? _parseTimeOfDay(data['bedtimeEnd'])
          : null,
      bedtimeEnabled: data['bedtimeEnabled'],
      requireApproval: data['requireApproval'],
      sendNotifications: data['sendNotifications'],
      warningMinutes: data['warningMinutes'],
      customSettings: data['customSettings'] != null
          ? Map<String, dynamic>.from(data['customSettings'])
          : null,
      description: data['description'],
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'childId': childId,
      'ruleName': ruleName,
      'type': type.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (appPackageName != null) 'appPackageName': appPackageName,
      if (appName != null) 'appName': appName,
      if (appCategory != null) 'appCategory': appCategory!.name,
      if (dailyLimitMinutes != null) 'dailyLimitMinutes': dailyLimitMinutes,
      if (weeklyLimitMinutes != null) 'weeklyLimitMinutes': weeklyLimitMinutes,
      if (timePeriod != null) 'timePeriod': timePeriod!.name,
      if (allowedStartTime != null) 'allowedStartTime': _timeOfDayToString(allowedStartTime!),
      if (allowedEndTime != null) 'allowedEndTime': _timeOfDayToString(allowedEndTime!),
      if (allowedDays != null) 'allowedDays': allowedDays,
      if (totalScreenTimeMinutes != null) 'totalScreenTimeMinutes': totalScreenTimeMinutes,
      if (bedtimeStart != null) 'bedtimeStart': _timeOfDayToString(bedtimeStart!),
      if (bedtimeEnd != null) 'bedtimeEnd': _timeOfDayToString(bedtimeEnd!),
      if (bedtimeEnabled != null) 'bedtimeEnabled': bedtimeEnabled,
      if (requireApproval != null) 'requireApproval': requireApproval,
      if (sendNotifications != null) 'sendNotifications': sendNotifications,
      if (warningMinutes != null) 'warningMinutes': warningMinutes,
      if (customSettings != null) 'customSettings': customSettings,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags,
    };
  }

  /// Helper methods for TimeOfDay conversion
  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String _timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Copy with updated fields
  RuleModel copyWith({
    String? id,
    String? familyId,
    String? childId,
    String? ruleName,
    RuleType? type,
    RuleStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? activatedAt,
    DateTime? expiresAt,
    String? appPackageName,
    String? appName,
    AppCategory? appCategory,
    int? dailyLimitMinutes,
    int? weeklyLimitMinutes,
    TimePeriod? timePeriod,
    TimeOfDay? allowedStartTime,
    TimeOfDay? allowedEndTime,
    List<int>? allowedDays,
    int? totalScreenTimeMinutes,
    TimeOfDay? bedtimeStart,
    TimeOfDay? bedtimeEnd,
    bool? bedtimeEnabled,
    bool? requireApproval,
    bool? sendNotifications,
    int? warningMinutes,
    Map<String, dynamic>? customSettings,
    String? description,
    List<String>? tags,
  }) {
    return RuleModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      childId: childId ?? this.childId,
      ruleName: ruleName ?? this.ruleName,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      appPackageName: appPackageName ?? this.appPackageName,
      appName: appName ?? this.appName,
      appCategory: appCategory ?? this.appCategory,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      weeklyLimitMinutes: weeklyLimitMinutes ?? this.weeklyLimitMinutes,
      timePeriod: timePeriod ?? this.timePeriod,
      allowedStartTime: allowedStartTime ?? this.allowedStartTime,
      allowedEndTime: allowedEndTime ?? this.allowedEndTime,
      allowedDays: allowedDays ?? this.allowedDays,
      totalScreenTimeMinutes: totalScreenTimeMinutes ?? this.totalScreenTimeMinutes,
      bedtimeStart: bedtimeStart ?? this.bedtimeStart,
      bedtimeEnd: bedtimeEnd ?? this.bedtimeEnd,
      bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
      requireApproval: requireApproval ?? this.requireApproval,
      sendNotifications: sendNotifications ?? this.sendNotifications,
      warningMinutes: warningMinutes ?? this.warningMinutes,
      customSettings: customSettings ?? this.customSettings,
      description: description ?? this.description,
      tags: tags ?? this.tags,
    );
  }

  /// Check if rule is currently active
  bool get isActive {
    final now = DateTime.now();
    return status == RuleStatus.active &&
           (expiresAt == null || now.isBefore(expiresAt!));
  }

  /// Check if rule applies to current time
  bool get isCurrentlyApplicable {
    if (!isActive) return false;
    
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentDay = now.weekday; // 1=Monday, 7=Sunday

    // Check day restrictions
    if (allowedDays != null && !allowedDays!.contains(currentDay)) {
      return false;
    }

    // Check time window restrictions
    if (allowedStartTime != null && allowedEndTime != null) {
      return _isTimeInRange(currentTime, allowedStartTime!, allowedEndTime!);
    }

    return true;
  }

  /// Helper method to check if time is in range
  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Same day range
      return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
    } else {
      // Overnight range
      return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
    }
  }

  /// Get user-friendly description
  String get displayDescription {
    switch (type) {
      case RuleType.appLimit:
        return 'Limit ${appName ?? appPackageName ?? "app"} to ${dailyLimitMinutes ?? 0} minutes per day';
      case RuleType.appBlock:
        return 'Block ${appName ?? appPackageName ?? "app"} completely';
      case RuleType.appSchedule:
        final start = allowedStartTime != null ? '${allowedStartTime!.hour.toString().padLeft(2, '0')}:${allowedStartTime!.minute.toString().padLeft(2, '0')}' : '';
        final end = allowedEndTime != null ? '${allowedEndTime!.hour.toString().padLeft(2, '0')}:${allowedEndTime!.minute.toString().padLeft(2, '0')}' : '';
        return 'Allow ${appName ?? appPackageName ?? "app"} from $start to $end';
      case RuleType.screenTime:
        return 'Limit total screen time to ${totalScreenTimeMinutes ?? 0} minutes per day';
      case RuleType.bedtime:
        final start = bedtimeStart != null ? '${bedtimeStart!.hour.toString().padLeft(2, '0')}:${bedtimeStart!.minute.toString().padLeft(2, '0')}' : '';
        final end = bedtimeEnd != null ? '${bedtimeEnd!.hour.toString().padLeft(2, '0')}:${bedtimeEnd!.minute.toString().padLeft(2, '0')}' : '';
        return 'Bedtime from $start to $end';
      case RuleType.appRequest:
        return 'Require approval for new app installations';
      case RuleType.category:
        return 'Rules for ${appCategory?.name ?? "category"} apps';
    }
  }

  @override
  String toString() {
    return 'RuleModel(id: $id, type: $type, status: $status, ruleName: $ruleName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuleModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Rule enforcement log model
class RuleEnforcementLog {
  final String id;
  final String ruleId;
  final String childId;
  final String action; // 'blocked', 'limited', 'warned', 'approved'
  final DateTime timestamp;
  final Map<String, dynamic> details;

  const RuleEnforcementLog({
    required this.id,
    required this.ruleId,
    required this.childId,
    required this.action,
    required this.timestamp,
    this.details = const {},
  });

  factory RuleEnforcementLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RuleEnforcementLog(
      id: doc.id,
      ruleId: data['ruleId'] ?? '',
      childId: data['childId'] ?? '',
      action: data['action'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details: Map<String, dynamic>.from(data['details'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ruleId': ruleId,
      'childId': childId,
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
    };
  }
}