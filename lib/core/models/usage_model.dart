import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for individual app usage session
class UsageSession {
  final String id;
  final String packageName;
  final String appName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String deviceId;
  final bool synced;
  final DateTime createdAt;

  const UsageSession({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.deviceId,
    this.synced = false,
    required this.createdAt,
  });

  factory UsageSession.fromMap(Map<String, dynamic> map) {
    return UsageSession(
      id: map['id'] ?? '',
      packageName: map['packageName'] ?? '',
      appName: map['appName'] ?? '',
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      durationSeconds: map['durationSeconds'] ?? 0,
      deviceId: map['deviceId'] ?? '',
      synced: map['synced'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'deviceId': deviceId,
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UsageSession copyWith({
    String? id,
    String? packageName,
    String? appName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? deviceId,
    bool? synced,
    DateTime? createdAt,
  }) {
    return UsageSession(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      deviceId: deviceId ?? this.deviceId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if session is valid (reasonable duration)
  bool get isValid {
    return durationSeconds > 0 && 
           durationSeconds < 86400 && // Max 24 hours
           startTime.isBefore(endTime) &&
           endTime.isBefore(DateTime.now().add(Duration(minutes: 5))); // Allow 5min future tolerance
  }
}

/// Aggregated usage statistics for an app
class AppUsageStats {
  final String packageName;
  final String appName;
  final int todaySeconds;
  final int yesterdaySeconds;
  final int last7DaysSeconds;
  final int last30DaysSeconds;
  final DateTime lastUsed;
  final int totalSessions;
  final String date; // Date in yyyy-MM-dd format
  final DateTime updatedAt;
  final bool synced;

  const AppUsageStats({
    required this.packageName,
    required this.appName,
    required this.todaySeconds,
    required this.yesterdaySeconds,
    required this.last7DaysSeconds,
    required this.last30DaysSeconds,
    required this.lastUsed,
    required this.totalSessions,
    required this.date,
    required this.updatedAt,
    this.synced = false,
  });

  factory AppUsageStats.fromMap(Map<String, dynamic> map) {
    return AppUsageStats(
      packageName: map['packageName'] ?? '',
      appName: map['appName'] ?? '',
      todaySeconds: map['todaySeconds'] ?? 0,
      yesterdaySeconds: map['yesterdaySeconds'] ?? 0,
      last7DaysSeconds: map['last7DaysSeconds'] ?? 0,
      last30DaysSeconds: map['last30DaysSeconds'] ?? 0,
      lastUsed: DateTime.parse(map['lastUsed']),
      totalSessions: map['totalSessions'] ?? 0,
      date: map['date'] ?? '',
      updatedAt: DateTime.parse(map['updatedAt']),
      synced: map['synced'] ?? false,
    );
  }

  factory AppUsageStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUsageStats(
      packageName: data['packageName'] ?? '',
      appName: data['appName'] ?? '',
      todaySeconds: data['todaySeconds'] ?? 0,
      yesterdaySeconds: data['yesterdaySeconds'] ?? 0,
      last7DaysSeconds: data['last7DaysSeconds'] ?? 0,
      last30DaysSeconds: data['last30DaysSeconds'] ?? 0,
      lastUsed: (data['lastUsed'] as Timestamp).toDate(),
      totalSessions: data['totalSessions'] ?? 0,
      date: data['date'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      synced: true, // From Firestore, so it's synced
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'todaySeconds': todaySeconds,
      'yesterdaySeconds': yesterdaySeconds,
      'last7DaysSeconds': last7DaysSeconds,
      'last30DaysSeconds': last30DaysSeconds,
      'lastUsed': lastUsed.toIso8601String(),
      'totalSessions': totalSessions,
      'date': date,
      'updatedAt': updatedAt.toIso8601String(),
      'synced': synced,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'packageName': packageName,
      'appName': appName,
      'todaySeconds': todaySeconds,
      'yesterdaySeconds': yesterdaySeconds,
      'last7DaysSeconds': last7DaysSeconds,
      'last30DaysSeconds': last30DaysSeconds,
      'lastUsed': Timestamp.fromDate(lastUsed),
      'totalSessions': totalSessions,
      'date': date,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppUsageStats copyWith({
    String? packageName,
    String? appName,
    int? todaySeconds,
    int? yesterdaySeconds,
    int? last7DaysSeconds,
    int? last30DaysSeconds,
    DateTime? lastUsed,
    int? totalSessions,
    String? date,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return AppUsageStats(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      todaySeconds: todaySeconds ?? this.todaySeconds,
      yesterdaySeconds: yesterdaySeconds ?? this.yesterdaySeconds,
      last7DaysSeconds: last7DaysSeconds ?? this.last7DaysSeconds,
      last30DaysSeconds: last30DaysSeconds ?? this.last30DaysSeconds,
      lastUsed: lastUsed ?? this.lastUsed,
      totalSessions: totalSessions ?? this.totalSessions,
      date: date ?? this.date,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  // Convenience getters for formatted times
  
  int get todayMinutes => (todaySeconds / 60).ceil();
  int get yesterdayMinutes => (yesterdaySeconds / 60).ceil();
  int get last7DaysMinutes => (last7DaysSeconds / 60).ceil();
  int get last30DaysMinutes => (last30DaysSeconds / 60).ceil();

  String get todayFormatted => _formatDuration(todaySeconds);
  String get yesterdayFormatted => _formatDuration(yesterdaySeconds);
  String get last7DaysFormatted => _formatDuration(last7DaysSeconds);
  String get last30DaysFormatted => _formatDuration(last30DaysSeconds);

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0m';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Calculate usage percentage for daily limit
  double getUsagePercentage(int? dailyLimitMinutes) {
    if (dailyLimitMinutes == null || dailyLimitMinutes <= 0) {
      return 0.0;
    }
    return (todayMinutes / dailyLimitMinutes).clamp(0.0, 1.0);
  }

  /// Get remaining minutes for daily limit
  int getRemainingMinutes(int? dailyLimitMinutes) {
    if (dailyLimitMinutes == null || dailyLimitMinutes <= 0) {
      return 0;
    }
    return (dailyLimitMinutes - todayMinutes).clamp(0, dailyLimitMinutes);
  }

  /// Check if daily limit is exceeded
  bool isLimitExceeded(int? dailyLimitMinutes) {
    if (dailyLimitMinutes == null || dailyLimitMinutes <= 0) {
      return false;
    }
    return todayMinutes >= dailyLimitMinutes;
  }
}

/// Daily usage summary for all apps
class DailyUsageSummary {
  final String date; // yyyy-MM-dd format
  final int totalScreenTimeSeconds;
  final int totalAppsUsed;
  final int totalSessions;
  final Map<String, int> appUsageSeconds; // packageName -> seconds
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  const DailyUsageSummary({
    required this.date,
    required this.totalScreenTimeSeconds,
    required this.totalAppsUsed,
    required this.totalSessions,
    required this.appUsageSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
  });

  factory DailyUsageSummary.fromMap(Map<String, dynamic> map) {
    return DailyUsageSummary(
      date: map['date'] ?? '',
      totalScreenTimeSeconds: map['totalScreenTimeSeconds'] ?? 0,
      totalAppsUsed: map['totalAppsUsed'] ?? 0,
      totalSessions: map['totalSessions'] ?? 0,
      appUsageSeconds: Map<String, int>.from(map['appUsageSeconds'] ?? {}),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      synced: map['synced'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'totalScreenTimeSeconds': totalScreenTimeSeconds,
      'totalAppsUsed': totalAppsUsed,
      'totalSessions': totalSessions,
      'appUsageSeconds': appUsageSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'synced': synced,
    };
  }

  DailyUsageSummary copyWith({
    String? date,
    int? totalScreenTimeSeconds,
    int? totalAppsUsed,
    int? totalSessions,
    Map<String, int>? appUsageSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return DailyUsageSummary(
      date: date ?? this.date,
      totalScreenTimeSeconds: totalScreenTimeSeconds ?? this.totalScreenTimeSeconds,
      totalAppsUsed: totalAppsUsed ?? this.totalAppsUsed,
      totalSessions: totalSessions ?? this.totalSessions,
      appUsageSeconds: appUsageSeconds ?? this.appUsageSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  // Convenience getters
  
  int get totalScreenTimeMinutes => (totalScreenTimeSeconds / 60).ceil();
  String get totalScreenTimeFormatted => _formatDuration(totalScreenTimeSeconds);

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0m';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get top used apps sorted by usage time
  List<MapEntry<String, int>> get topApps {
    final entries = appUsageSeconds.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

/// Usage report for parent dashboard
class UsageReport {
  final String childId;
  final String childName;
  final String familyId;
  final DateTime reportDate;
  final DailyUsageSummary todaySummary;
  final List<AppUsageStats> appStats;
  final List<DailyUsageSummary> weeklyData;
  final Map<String, int> categoryUsage; // Category -> seconds
  final DateTime generatedAt;

  const UsageReport({
    required this.childId,
    required this.childName,
    required this.familyId,
    required this.reportDate,
    required this.todaySummary,
    required this.appStats,
    required this.weeklyData,
    required this.categoryUsage,
    required this.generatedAt,
  });

  /// Get total screen time for today
  String get todayScreenTime => todaySummary.totalScreenTimeFormatted;

  /// Get most used app today
  AppUsageStats? get mostUsedAppToday {
    if (appStats.isEmpty) return null;
    
    final sortedApps = List<AppUsageStats>.from(appStats);
    sortedApps.sort((a, b) => b.todaySeconds.compareTo(a.todaySeconds));
    
    return sortedApps.first.todaySeconds > 0 ? sortedApps.first : null;
  }

  /// Get average daily usage for the week
  String get averageWeeklyScreenTime {
    if (weeklyData.isEmpty) return '0m';
    
    final totalSeconds = weeklyData.fold<int>(
      0, 
      (acc, day) => acc + day.totalScreenTimeSeconds,
    );
    final averageSeconds = totalSeconds / weeklyData.length;
    
    return _formatDuration(averageSeconds.round());
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0m';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}