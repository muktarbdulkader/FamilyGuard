import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing an installed application on a child device
class AppModel {
  final String packageName;
  final String appName;
  final String? iconBase64; // Base64 encoded app icon
  final String version;
  final DateTime installedDate;
  final DateTime lastUsed;
  final bool isSystemApp;
  final AppRule rule;
  final int dailyLimitMinutes;
  final TimeWindow? allowedTimeWindow;
  final int usedTodayMinutes;
  final DateTime lastUpdated;

  const AppModel({
    required this.packageName,
    required this.appName,
    this.iconBase64,
    required this.version,
    required this.installedDate,
    required this.lastUsed,
    required this.isSystemApp,
    required this.rule,
    this.dailyLimitMinutes = 0,
    this.allowedTimeWindow,
    this.usedTodayMinutes = 0,
    required this.lastUpdated,
  });

  /// Create AppModel from Firestore document
  factory AppModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppModel(
      packageName: doc.id,
      appName: data['appName'] ?? '',
      iconBase64: data['iconBase64'],
      version: data['version'] ?? '',
      installedDate: (data['installedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUsed: (data['lastUsed'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSystemApp: data['isSystemApp'] ?? false,
      rule: AppRule.fromString(data['rule'] ?? 'ask_parent'),
      dailyLimitMinutes: data['dailyLimitMinutes'] ?? 0,
      allowedTimeWindow: data['allowedTimeWindow'] != null 
          ? TimeWindow.fromMap(data['allowedTimeWindow']) 
          : null,
      usedTodayMinutes: data['usedTodayMinutes'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create AppModel from JSON (for local caching)
  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      packageName: json['packageName'] ?? '',
      appName: json['appName'] ?? '',
      iconBase64: json['iconBase64'],
      version: json['version'] ?? '',
      installedDate: DateTime.parse(json['installedDate']),
      lastUsed: DateTime.parse(json['lastUsed']),
      isSystemApp: json['isSystemApp'] ?? false,
      rule: AppRule.fromString(json['rule'] ?? 'ask_parent'),
      dailyLimitMinutes: json['dailyLimitMinutes'] ?? 0,
      allowedTimeWindow: json['allowedTimeWindow'] != null 
          ? TimeWindow.fromMap(json['allowedTimeWindow']) 
          : null,
      usedTodayMinutes: json['usedTodayMinutes'] ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'appName': appName,
      'iconBase64': iconBase64,
      'version': version,
      'installedDate': Timestamp.fromDate(installedDate),
      'lastUsed': Timestamp.fromDate(lastUsed),
      'isSystemApp': isSystemApp,
      'rule': rule.toString(),
      'dailyLimitMinutes': dailyLimitMinutes,
      'allowedTimeWindow': allowedTimeWindow?.toMap(),
      'usedTodayMinutes': usedTodayMinutes,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Convert to JSON (for local caching)
  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'appName': appName,
      'iconBase64': iconBase64,
      'version': version,
      'installedDate': installedDate.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
      'isSystemApp': isSystemApp,
      'rule': rule.toString(),
      'dailyLimitMinutes': dailyLimitMinutes,
      'allowedTimeWindow': allowedTimeWindow?.toMap(),
      'usedTodayMinutes': usedTodayMinutes,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Copy with updated fields
  AppModel copyWith({
    String? packageName,
    String? appName,
    String? iconBase64,
    String? version,
    DateTime? installedDate,
    DateTime? lastUsed,
    bool? isSystemApp,
    AppRule? rule,
    int? dailyLimitMinutes,
    TimeWindow? allowedTimeWindow,
    int? usedTodayMinutes,
    DateTime? lastUpdated,
  }) {
    return AppModel(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconBase64: iconBase64 ?? this.iconBase64,
      version: version ?? this.version,
      installedDate: installedDate ?? this.installedDate,
      lastUsed: lastUsed ?? this.lastUsed,
      isSystemApp: isSystemApp ?? this.isSystemApp,
      rule: rule ?? this.rule,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      allowedTimeWindow: allowedTimeWindow ?? this.allowedTimeWindow,
      usedTodayMinutes: usedTodayMinutes ?? this.usedTodayMinutes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if app is currently allowed based on rules and time
  bool get isCurrentlyAllowed {
    final now = DateTime.now();
    
    switch (rule) {
      case AppRule.allowed:
        return true;
      case AppRule.blocked:
        return false;
      case AppRule.timeLimit:
        if (usedTodayMinutes >= dailyLimitMinutes) {
          return false; // Daily limit exceeded
        }
        if (allowedTimeWindow != null) {
          return allowedTimeWindow!.isCurrentlyInWindow(now);
        }
        return true;
      case AppRule.askParent:
        return false; // Always requires approval
      case AppRule.timeWindow:
        return allowedTimeWindow?.isCurrentlyInWindow(now) ?? false;
    }
  }

  /// Get remaining minutes for time-limited apps
  int get remainingMinutes {
    if (rule == AppRule.timeLimit && dailyLimitMinutes > 0) {
      return (dailyLimitMinutes - usedTodayMinutes).clamp(0, dailyLimitMinutes);
    }
    return 0;
  }

  @override
  String toString() {
    return 'AppModel(packageName: $packageName, appName: $appName, rule: $rule)';
  }
}

/// App rule enumeration
enum AppRule {
  allowed,
  blocked,
  timeLimit,
  askParent,
  timeWindow;

  static AppRule fromString(String value) {
    switch (value.toLowerCase()) {
      case 'allowed':
        return AppRule.allowed;
      case 'blocked':
        return AppRule.blocked;
      case 'time_limit':
        return AppRule.timeLimit;
      case 'ask_parent':
        return AppRule.askParent;
      case 'time_window':
        return AppRule.timeWindow;
      default:
        return AppRule.askParent; // Safe default
    }
  }

  @override
  String toString() {
    switch (this) {
      case AppRule.allowed:
        return 'allowed';
      case AppRule.blocked:
        return 'blocked';
      case AppRule.timeLimit:
        return 'time_limit';
      case AppRule.askParent:
        return 'ask_parent';
      case AppRule.timeWindow:
        return 'time_window';
    }
  }

  String get displayName {
    switch (this) {
      case AppRule.allowed:
        return 'Allowed';
      case AppRule.blocked:
        return 'Blocked';
      case AppRule.timeLimit:
        return 'Time Limit';
      case AppRule.askParent:
        return 'Ask Parent';
      case AppRule.timeWindow:
        return 'Time Window';
    }
  }
}

/// Time window for app usage restrictions
class TimeWindow {
  final int startHour; // 0-23
  final int startMinute; // 0-59
  final int endHour; // 0-23
  final int endMinute; // 0-59

  const TimeWindow({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  /// Create from map
  factory TimeWindow.fromMap(Map<String, dynamic> map) {
    return TimeWindow(
      startHour: map['startHour'] ?? 0,
      startMinute: map['startMinute'] ?? 0,
      endHour: map['endHour'] ?? 23,
      endMinute: map['endMinute'] ?? 59,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  /// Check if current time is within the allowed window
  bool isCurrentlyInWindow(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    if (startMinutes <= endMinutes) {
      // Same day window (e.g., 9:00 AM to 5:00 PM)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight window (e.g., 8:00 PM to 6:00 AM next day)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  /// Format as readable string
  String get displayString {
    final startTime = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final endTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    return '$startTime - $endTime';
  }

  @override
  String toString() => displayString;
}