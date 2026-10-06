import 'package:cloud_firestore/cloud_firestore.dart';

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