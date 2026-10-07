import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Enum for app rule types
enum AppRuleType {
  allowed,
  blocked,
  askParent,
  timeLimit,
  timeWindow,
}

/// Model representing a family unit with parent and child members
class FamilyModel {
  final String id;
  final String name;
  final String createdBy; // Parent user ID
  final List<String> parentIds;
  final List<String> childIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? familyCode; // For child joining
  final Map<String, dynamic> settings;

  FamilyModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.parentIds,
    required this.childIds,
    required this.createdAt,
    required this.updatedAt,
    this.familyCode,
    this.settings = const {},
  });

  /// Create from Firestore document
  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FamilyModel(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      parentIds: List<String>.from(data['parentIds'] ?? []),
      childIds: List<String>.from(data['childIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      familyCode: data['familyCode'],
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdBy': createdBy,
      'parentIds': parentIds,
      'childIds': childIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'familyCode': familyCode,
      'settings': settings,
    };
  }

  /// Create copy with updated fields
  FamilyModel copyWith({
    String? id,
    String? name,
    String? createdBy,
    List<String>? parentIds,
    List<String>? childIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? familyCode,
    Map<String, dynamic>? settings,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      parentIds: parentIds ?? this.parentIds,
      childIds: childIds ?? this.childIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      familyCode: familyCode ?? this.familyCode,
      settings: settings ?? this.settings,
    );
  }

  /// Get all member IDs (parents + children)
  List<String> get allMemberIds => [...parentIds, ...childIds];

  /// Getter aliases for compatibility
  String get parentId => createdBy;
  List<String> get childrenIds => childIds;

  /// Check if user is parent in this family
  bool isParent(String userId) => parentIds.contains(userId);

  /// Check if user is child in this family
  bool isChild(String userId) => childIds.contains(userId);

  /// Check if user is member of this family
  bool isMember(String userId) => allMemberIds.contains(userId);
}

/// Model representing a child within a family
class ChildModel {
  final String id;
  final String displayName;
  final String email;
  final String familyId;
  final DateTime joinedAt;
  final DateTime lastActiveAt;
  final bool isOnline;
  final String? deviceInfo;
  final Map<String, dynamic> preferences;

  ChildModel({
    required this.id,
    required this.displayName,
    required this.email,
    required this.familyId,
    required this.joinedAt,
    required this.lastActiveAt,
    this.isOnline = false,
    this.deviceInfo,
    this.preferences = const {},
  });

  /// Create from Firestore document
  factory ChildModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ChildModel(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      familyId: data['familyId'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp).toDate(),
      isOnline: data['isOnline'] ?? false,
      deviceInfo: data['deviceInfo'],
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'familyId': familyId,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'isOnline': isOnline,
      'deviceInfo': deviceInfo,
      'preferences': preferences,
    };
  }

  /// Create copy with updated fields
  ChildModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? familyId,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool? isOnline,
    String? deviceInfo,
    Map<String, dynamic>? preferences,
  }) {
    return ChildModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      familyId: familyId ?? this.familyId,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isOnline: isOnline ?? this.isOnline,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      preferences: preferences ?? this.preferences,
    );
  }

  /// Get display status
  String get statusText {
    if (isOnline) {
      return 'Online';
    } else {
      final now = DateTime.now();
      final difference = now.difference(lastActiveAt);
      
      if (difference.inMinutes < 5) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    }
  }

  /// Get status color
  Color get statusColor {
    if (isOnline) {
      return const Color(0xFF4CAF50); // Green
    } else {
      final now = DateTime.now();
      final difference = now.difference(lastActiveAt);
      
      if (difference.inHours < 1) {
        return const Color(0xFFFF9800); // Orange
      } else {
        return const Color(0xFF9E9E9E); // Grey
      }
    }
  }
}

/// Model for app usage statistics
class AppUsageModel {
  final String packageName;
  final String appName;
  final int todayMinutes;
  final int weekMinutes;
  final int monthMinutes;
  final DateTime lastUsed;
  final int openCount;
  final Map<String, int> dailyUsage; // Date string -> minutes

  AppUsageModel({
    required this.packageName,
    required this.appName,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.monthMinutes,
    required this.lastUsed,
    required this.openCount,
    this.dailyUsage = const {},
  });

  /// Create from Firestore document
  factory AppUsageModel.fromFirestore(Map<String, dynamic> data) {
    return AppUsageModel(
      packageName: data['packageName'] ?? '',
      appName: data['appName'] ?? '',
      todayMinutes: data['todayMinutes'] ?? 0,
      weekMinutes: data['weekMinutes'] ?? 0,
      monthMinutes: data['monthMinutes'] ?? 0,
      lastUsed: (data['lastUsed'] as Timestamp?)?.toDate() ?? DateTime.now(),
      openCount: data['openCount'] ?? 0,
      dailyUsage: Map<String, int>.from(data['dailyUsage'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'packageName': packageName,
      'appName': appName,
      'todayMinutes': todayMinutes,
      'weekMinutes': weekMinutes,
      'monthMinutes': monthMinutes,
      'lastUsed': Timestamp.fromDate(lastUsed),
      'openCount': openCount,
      'dailyUsage': dailyUsage,
    };
  }

  /// Get usage status text
  String get usageStatusText {
    if (todayMinutes == 0) {
      return 'Not used today';
    } else if (todayMinutes < 60) {
      return '${todayMinutes}m today';
    } else {
      final hours = todayMinutes ~/ 60;
      final minutes = todayMinutes % 60;
      return '${hours}h ${minutes}m today';
    }
  }

  /// Get usage percentage for daily limit
  double getUsagePercentage(int? dailyLimitMinutes) {
    if (dailyLimitMinutes == null || dailyLimitMinutes <= 0) {
      return 0.0;
    }
    return (todayMinutes / dailyLimitMinutes).clamp(0.0, 1.0);
  }
}

/// Model for app control rules
class AppRule {
  final String appPackageName;
  final AppRuleType type;
  final int? dailyLimitMinutes; // For time limit rules
  final TimeOfDay? allowedStartTime; // For time window rules
  final TimeOfDay? allowedEndTime; // For time window rules
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppRule({
    required this.appPackageName,
    required this.type,
    this.dailyLimitMinutes,
    this.allowedStartTime,
    this.allowedEndTime,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'appPackageName': appPackageName,
      'type': type.toString().split('.').last,
      'dailyLimitMinutes': dailyLimitMinutes,
      'allowedStartTime': allowedStartTime != null
          ? '${allowedStartTime!.hour}:${allowedStartTime!.minute}'
          : null,
      'allowedEndTime': allowedEndTime != null
          ? '${allowedEndTime!.hour}:${allowedEndTime!.minute}'
          : null,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppRule.fromJson(Map<String, dynamic> json) {
    return AppRule(
      appPackageName: json['appPackageName'] as String,
      type: AppRuleType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AppRuleType.allowed,
      ),
      dailyLimitMinutes: json['dailyLimitMinutes'] as int?,
      allowedStartTime: json['allowedStartTime'] != null
          ? _parseTimeOfDay(json['allowedStartTime'] as String)
          : null,
      allowedEndTime: json['allowedEndTime'] != null
          ? _parseTimeOfDay(json['allowedEndTime'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  /// Create copy with updated fields
  AppRule copyWith({
    String? appPackageName,
    AppRuleType? type,
    int? dailyLimitMinutes,
    TimeOfDay? allowedStartTime,
    TimeOfDay? allowedEndTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppRule(
      appPackageName: appPackageName ?? this.appPackageName,
      type: type ?? this.type,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      allowedStartTime: allowedStartTime ?? this.allowedStartTime,
      allowedEndTime: allowedEndTime ?? this.allowedEndTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}