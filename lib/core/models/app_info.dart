import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing an installed application on a child device
/// Used for parental control app management and monitoring
class AppInfo {
  final String packageName;
  final String name;
  final AppControlRule rule;
  final int? dailyLimitMinutes;
  final int usageAlertThresholdPercent;
  final int dailyLimitBonusMinutes;
  final String? dailyLimitBonusDate;
  final String? allowedFrom; // HH:mm format
  final String? allowedUntil; // HH:mm format
  final DateTime detectedAt;
  final DateTime updatedAt;
  final bool isAvailable; // false if app was uninstalled
  final String? iconBase64; // Base64 encoded icon data
  final String? version;
  final bool isSystemApp;

  AppInfo({
    required this.packageName,
    required this.name,
    required this.rule,
    this.dailyLimitMinutes,
    this.usageAlertThresholdPercent = 50,
    this.dailyLimitBonusMinutes = 0,
    this.dailyLimitBonusDate,
    this.allowedFrom,
    this.allowedUntil,
    required this.detectedAt,
    required this.updatedAt,
    this.isAvailable = true,
    this.iconBase64,
    this.version,
    this.isSystemApp = false,
  });

  /// Create AppInfo from Firestore document
  factory AppInfo.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final pkg = (data['packageName'] ?? doc.id).toString();
    final appName = (data['name'] ?? data['appName'] ?? pkg).toString();

    return AppInfo(
      packageName: pkg,
      name: appName.isNotEmpty ? appName : pkg,
      rule: _parseRule(data['rule'] ?? data['type']),
      dailyLimitMinutes: (data['dailyLimitMinutes'] as num?)?.toInt(),
      usageAlertThresholdPercent:
          ((data['usageAlertThresholdPercent'] as num?)?.toInt() ?? 50).clamp(
            1,
            99,
          ),
      dailyLimitBonusMinutes:
          (data['dailyLimitBonusMinutes'] as num?)?.toInt() ?? 0,
      dailyLimitBonusDate: data['dailyLimitBonusDate'] as String?,
      allowedFrom:
          data['allowedFrom'] as String? ??
          (data['allowedStartTime'] as String?),
      allowedUntil:
          data['allowedUntil'] as String? ??
          (data['allowedEndTime'] as String?),
      detectedAt: _parseTimestamp(data['detectedAt'] ?? data['installedDate']),
      updatedAt: _parseTimestamp(data['updatedAt'] ?? data['lastUpdated']),
      isAvailable: data['isAvailable'] as bool? ?? true,
      iconBase64: data['iconBase64'] as String?,
      version: data['version'] as String?,
      isSystemApp: data['isSystemApp'] as bool? ?? false,
    );
  }

  static AppControlRule _parseRule(dynamic ruleRaw) {
    if (ruleRaw == null) return AppControlRule.ask;
    final str = ruleRaw.toString().toLowerCase().trim();
    switch (str) {
      case 'block':
      case 'blocked':
        return AppControlRule.block;
      case 'allow':
      case 'allowed':
        return AppControlRule.allow;
      case 'ask':
      case 'ask_parent':
      case 'notify':
      case 'request':
        return AppControlRule.ask;
      case 'timelimited':
      case 'time_limit':
      case 'timelimit':
        return AppControlRule.timeLimited;
      case 'timerestricted':
      case 'time_window':
      case 'timewindow':
        return AppControlRule.timeRestricted;
      default:
        return AppControlRule.ask;
    }
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Convert AppInfo to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'packageName': packageName,
      'name': name,
      'appName': name,
      'rule': rule.name,
      'type': rule.name.toUpperCase(),
      'dailyLimitMinutes': dailyLimitMinutes,
      'usageAlertThresholdPercent': usageAlertThresholdPercent,
      'dailyLimitBonusMinutes': dailyLimitBonusMinutes,
      'dailyLimitBonusDate': dailyLimitBonusDate,
      'allowedFrom': allowedFrom,
      'allowedUntil': allowedUntil,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'installedDate': Timestamp.fromDate(detectedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastUpdated': Timestamp.fromDate(updatedAt),
      'isAvailable': isAvailable,
      'iconBase64': iconBase64,
      'version': version,
      'isSystemApp': isSystemApp,
    };
  }

  /// Create new AppInfo for newly detected app
  factory AppInfo.newDetection({
    required String packageName,
    required String name,
    String? iconBase64,
    String? version,
    bool isSystemApp = false,
  }) {
    final now = DateTime.now();
    return AppInfo(
      packageName: packageName,
      name: name,
      rule: AppControlRule.ask, // Default rule for new apps
      detectedAt: now,
      updatedAt: now,
      iconBase64: iconBase64,
      version: version,
      isSystemApp: isSystemApp,
    );
  }

  /// Create copy with updated fields
  AppInfo copyWith({
    String? packageName,
    String? name,
    AppControlRule? rule,
    int? dailyLimitMinutes,
    int? usageAlertThresholdPercent,
    int? dailyLimitBonusMinutes,
    String? dailyLimitBonusDate,
    String? allowedFrom,
    String? allowedUntil,
    DateTime? detectedAt,
    DateTime? updatedAt,
    bool? isAvailable,
    String? iconBase64,
    String? version,
    bool? isSystemApp,
  }) {
    return AppInfo(
      packageName: packageName ?? this.packageName,
      name: name ?? this.name,
      rule: rule ?? this.rule,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      usageAlertThresholdPercent:
          usageAlertThresholdPercent ?? this.usageAlertThresholdPercent,
      dailyLimitBonusMinutes:
          dailyLimitBonusMinutes ?? this.dailyLimitBonusMinutes,
      dailyLimitBonusDate: dailyLimitBonusDate ?? this.dailyLimitBonusDate,
      allowedFrom: allowedFrom ?? this.allowedFrom,
      allowedUntil: allowedUntil ?? this.allowedUntil,
      detectedAt: detectedAt ?? this.detectedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAvailable: isAvailable ?? this.isAvailable,
      iconBase64: iconBase64 ?? this.iconBase64,
      version: version ?? this.version,
      isSystemApp: isSystemApp ?? this.isSystemApp,
    );
  }

  /// Mark app as unavailable (uninstalled)
  AppInfo markUnavailable() {
    return copyWith(isAvailable: false, updatedAt: DateTime.now());
  }

  /// Mark app as available again (reinstalled)
  AppInfo markAvailable() {
    return copyWith(isAvailable: true, updatedAt: DateTime.now());
  }

  /// Update app metadata (name, icon, version)
  AppInfo updateMetadata({String? name, String? iconBase64, String? version}) {
    return copyWith(
      name: name ?? this.name,
      iconBase64: iconBase64 ?? this.iconBase64,
      version: version ?? this.version,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if app has time restrictions
  bool get hasTimeRestrictions => allowedFrom != null && allowedUntil != null;

  /// Check if app has daily limit
  bool get hasDailyLimit => dailyLimitMinutes != null && dailyLimitMinutes! > 0;

  int effectiveDailyLimit(DateTime localTime) {
    final baseLimit = dailyLimitMinutes ?? 0;
    final bonusApplies =
        dailyLimitBonusDate == _localDateString(localTime) &&
        dailyLimitBonusMinutes > 0;
    return baseLimit + (bonusApplies ? dailyLimitBonusMinutes : 0);
  }

  static String _localDateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  /// Check if app is currently allowed based on time restrictions
  bool isAllowedAtTime(DateTime time) {
    if (!hasTimeRestrictions) return true;

    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    // Simple time comparison (doesn't handle overnight restrictions)
    return timeStr.compareTo(allowedFrom!) >= 0 &&
        timeStr.compareTo(allowedUntil!) <= 0;
  }

  /// Get display name for UI
  String get displayName => name.isNotEmpty ? name : packageName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInfo &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;

  @override
  String toString() {
    return 'AppInfo{packageName: $packageName, name: $name, rule: $rule, isAvailable: $isAvailable}';
  }
}

/// Enum for app control rules
enum AppControlRule {
  /// Always allow the app
  allow,

  /// Always block the app
  block,

  /// Ask parent for permission each time
  ask,

  /// Allow with time restrictions
  timeRestricted,

  /// Allow with daily time limit
  timeLimited,
}

/// Extension for AppControlRule to provide user-friendly descriptions
extension AppControlRuleExtension on AppControlRule {
  String get displayName {
    switch (this) {
      case AppControlRule.allow:
        return 'Always Allow';
      case AppControlRule.block:
        return 'Always Block';
      case AppControlRule.ask:
        return 'Ask Parent';
      case AppControlRule.timeRestricted:
        return 'Time Restricted';
      case AppControlRule.timeLimited:
        return 'Daily Time Limit';
    }
  }

  String get description {
    switch (this) {
      case AppControlRule.allow:
        return 'App can be used without restrictions';
      case AppControlRule.block:
        return 'App is blocked and cannot be used';
      case AppControlRule.ask:
        return 'Parent approval required each time';
      case AppControlRule.timeRestricted:
        return 'App can only be used during specified hours';
      case AppControlRule.timeLimited:
        return 'App usage limited to daily time allowance';
    }
  }

  /// Check if rule requires parent interaction
  bool get requiresParentApproval => this == AppControlRule.ask;

  /// Check if rule allows app usage
  bool get allowsUsage => this != AppControlRule.block;
}

/// Event types for app discovery changes
enum AppDiscoveryEvent {
  appInstalled,
  appUninstalled,
  appUpdated,
  appReinstalled,
}

/// Model for app discovery events
class AppDiscoveryEventInfo {
  final AppDiscoveryEvent event;
  final AppInfo appInfo;
  final DateTime timestamp;
  final String? previousVersion;

  AppDiscoveryEventInfo({
    required this.event,
    required this.appInfo,
    required this.timestamp,
    this.previousVersion,
  });

  /// Convert to Firestore document for event logging
  Map<String, dynamic> toFirestore() {
    return {
      'event': event.name,
      'packageName': appInfo.packageName,
      'appName': appInfo.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'previousVersion': previousVersion,
      'currentVersion': appInfo.version,
    };
  }

  /// Get user-friendly event description
  String get description {
    switch (event) {
      case AppDiscoveryEvent.appInstalled:
        return '${appInfo.displayName} was installed';
      case AppDiscoveryEvent.appUninstalled:
        return '${appInfo.displayName} was uninstalled';
      case AppDiscoveryEvent.appUpdated:
        return '${appInfo.displayName} was updated';
      case AppDiscoveryEvent.appReinstalled:
        return '${appInfo.displayName} was reinstalled';
    }
  }
}
