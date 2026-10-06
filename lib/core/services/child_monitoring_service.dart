import 'dart:async';
import 'package:flutter/services.dart';

/// Flutter service that interfaces with native Android monitoring functionality
/// 
/// This service provides a clean Dart API for interacting with the native
/// Android monitoring engine, rule enforcement, and usage tracking.
class ChildMonitoringService {
  static const MethodChannel _methodChannel = MethodChannel('child_monitoring');
  static const EventChannel _eventChannel = EventChannel('child_monitoring_events');
  
  static ChildMonitoringService? _instance;
  static ChildMonitoringService get instance => _instance ??= ChildMonitoringService._();
  
  ChildMonitoringService._();
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<MonitoringEvent> _eventController = StreamController<MonitoringEvent>.broadcast();
  
  /// Stream of monitoring events from native layer
  Stream<MonitoringEvent> get events => _eventController.stream;
  
  /// Start monitoring with family and child context
  Future<bool> startMonitoring({
    required String familyId,
    required String childId,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('startMonitoring', {
        'familyId': familyId,
        'childId': childId,
      });
      
      // Start listening to events
      _startEventStream();
      
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Failed to start monitoring: ${e.message}');
      return false;
    }
  }
  
  /// Stop monitoring service
  Future<bool> stopMonitoring() async {
    try {
      final result = await _methodChannel.invokeMethod('stopMonitoring');
      
      // Stop listening to events
      _stopEventStream();
      
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Failed to stop monitoring: ${e.message}');
      return false;
    }
  }
  
  /// Check if monitoring is currently active
  Future<bool> isMonitoringActive() async {
    try {
      final result = await _methodChannel.invokeMethod('isMonitoringActive');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Failed to check monitoring status: ${e.message}');
      return false;
    }
  }
  
  /// Check required permissions
  Future<PermissionStatus> checkPermissions() async {
    try {
      final result = await _methodChannel.invokeMethod('checkPermissions');
      final permissions = Map<String, bool>.from(result);
      
      return PermissionStatus(
        usageStats: permissions['usageStats'] ?? false,
        overlay: permissions['overlay'] ?? false,
      );
    } on PlatformException catch (e) {
      print('Failed to check permissions: ${e.message}');
      return PermissionStatus(usageStats: false, overlay: false);
    }
  }
  
  /// Request Usage Stats permission (opens settings)
  Future<void> requestUsageStatsPermission() async {
    try {
      await _methodChannel.invokeMethod('requestUsageStatsPermission');
    } on PlatformException catch (e) {
      print('Failed to request usage stats permission: ${e.message}');
    }
  }
  
  /// Request Overlay permission (opens settings)
  Future<void> requestOverlayPermission() async {
    try {
      await _methodChannel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      print('Failed to request overlay permission: ${e.message}');
    }
  }
  
  /// Manually trigger rule synchronization
  Future<bool> syncRules(String familyId) async {
    try {
      final result = await _methodChannel.invokeMethod('syncRules', {
        'familyId': familyId,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Failed to sync rules: ${e.message}');
      return false;
    }
  }
  
  /// Get all cached rules
  Future<List<AppRuleData>> getRules() async {
    try {
      final result = await _methodChannel.invokeMethod('getRules');
      final rulesList = List<Map<dynamic, dynamic>>.from(result);
      
      return rulesList.map((ruleData) => AppRuleData.fromMap(Map<String, dynamic>.from(ruleData))).toList();
    } on PlatformException catch (e) {
      print('Failed to get rules: ${e.message}');
      return [];
    }
  }
  
  /// Evaluate an app against current rules
  Future<AppEvaluation?> evaluateApp(String packageName) async {
    try {
      final result = await _methodChannel.invokeMethod('evaluateApp', {
        'packageName': packageName,
      });
      
      return AppEvaluation.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      print('Failed to evaluate app: ${e.message}');
      return null;
    }
  }
  
  /// Get usage data for all apps
  Future<List<AppUsageData>> getUsageData() async {
    try {
      final result = await _methodChannel.invokeMethod('getUsageData');
      final usageList = List<Map<dynamic, dynamic>>.from(result);
      
      return usageList.map((usageData) => AppUsageData.fromMap(Map<String, dynamic>.from(usageData))).toList();
    } on PlatformException catch (e) {
      print('Failed to get usage data: ${e.message}');
      return [];
    }
  }
  
  /// Reset usage data for a specific app
  Future<bool> resetUsageData(String packageName) async {
    try {
      final result = await _methodChannel.invokeMethod('resetUsageData', {
        'packageName': packageName,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Failed to reset usage data: ${e.message}');
      return false;
    }
  }
  
  /// Add temporary approval for an app
  Future<bool> addTemporaryApproval({
    required String packageName,
    required int durationMinutes,
    required String approvedBy,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('addTemporaryApproval', {
        'packageName': packageName,
        'durationMinutes': durationMinutes,
        'approvedBy': approvedBy,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Failed to add temporary approval: ${e.message}');
      return false;
    }
  }
  
  void _startEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final eventMap = Map<String, dynamic>.from(event);
          final monitoringEvent = MonitoringEvent.fromMap(eventMap);
          _eventController.add(monitoringEvent);
        }
      },
      onError: (error) {
        print('Monitoring event stream error: $error');
      },
    );
  }
  
  void _stopEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }
  
  void dispose() {
    _stopEventStream();
    _eventController.close();
  }
}

/// Permission status for monitoring functionality
class PermissionStatus {
  final bool usageStats;
  final bool overlay;
  
  const PermissionStatus({
    required this.usageStats,
    required this.overlay,
  });
  
  bool get allGranted => usageStats && overlay;
  
  List<String> get missingPermissions {
    final missing = <String>[];
    if (!usageStats) missing.add('Usage Stats');
    if (!overlay) missing.add('Overlay');
    return missing;
  }
}

/// App rule data from native layer
class AppRuleData {
  final String packageName;
  final String type;
  final int? dailyLimitMinutes;
  final String? allowedStartTime;
  final String? allowedEndTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const AppRuleData({
    required this.packageName,
    required this.type,
    this.dailyLimitMinutes,
    this.allowedStartTime,
    this.allowedEndTime,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory AppRuleData.fromMap(Map<String, dynamic> map) {
    return AppRuleData(
      packageName: map['packageName'] as String,
      type: map['type'] as String,
      dailyLimitMinutes: map['dailyLimitMinutes'] as int?,
      allowedStartTime: map['allowedStartTime'] as String?,
      allowedEndTime: map['allowedEndTime'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

/// App evaluation result from rule engine
class AppEvaluation {
  final String packageName;
  final String result;
  final int? remainingMinutes;
  final int? minutesUntilAllowed;
  
  const AppEvaluation({
    required this.packageName,
    required this.result,
    this.remainingMinutes,
    this.minutesUntilAllowed,
  });
  
  factory AppEvaluation.fromMap(Map<String, dynamic> map) {
    return AppEvaluation(
      packageName: map['packageName'] as String,
      result: map['result'] as String,
      remainingMinutes: map['remainingMinutes'] as int?,
      minutesUntilAllowed: map['minutesUntilAllowed'] as int?,
    );
  }
  
  bool get isAllowed => result == 'ALLOW' || result == 'TEMPORARY_APPROVAL';
  bool get isBlocked => result == 'BLOCK';
  bool get needsPermission => result == 'REQUEST';
  bool get timeExpired => result == 'TIME_EXPIRED';
  bool get outsideWindow => result == 'OUTSIDE_ALLOWED_WINDOW';
}

/// App usage data from native layer
class AppUsageData {
  final String packageName;
  final int todayMinutes;
  final DateTime lastUsed;
  final String dailyResetDate;
  
  const AppUsageData({
    required this.packageName,
    required this.todayMinutes,
    required this.lastUsed,
    required this.dailyResetDate,
  });
  
  factory AppUsageData.fromMap(Map<String, dynamic> map) {
    return AppUsageData(
      packageName: map['packageName'] as String,
      todayMinutes: map['todayMinutes'] as int,
      lastUsed: DateTime.parse(map['lastUsed'] as String),
      dailyResetDate: map['dailyResetDate'] as String,
    );
  }
  
  String get usageText {
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
}

/// Monitoring events from native layer
class MonitoringEvent {
  final String type;
  final Map<String, dynamic> data;
  
  const MonitoringEvent({
    required this.type,
    required this.data,
  });
  
  factory MonitoringEvent.fromMap(Map<String, dynamic> map) {
    return MonitoringEvent(
      type: map['type'] as String,
      data: Map<String, dynamic>.from(map)..remove('type'),
    );
  }
  
  // Event type helpers
  bool get isMonitoringStarted => type == 'monitoring_started';
  bool get isMonitoringStopped => type == 'monitoring_stopped';
  bool get isRulesSyncing => type == 'rules_syncing';
  bool get isRulesSynced => type == 'rules_synced';
  bool get isPermissionResult => type == 'permission_result';
  bool get isUsageReset => type == 'usage_reset';
  bool get isTemporaryApprovalAdded => type == 'temporary_approval_added';
  
  // Data accessors
  String? get packageName => data['packageName'] as String?;
  String? get familyId => data['familyId'] as String?;
  String? get childId => data['childId'] as String?;
  String? get permission => data['permission'] as String?;
  bool? get granted => data['granted'] as bool?;
  int? get durationMinutes => data['durationMinutes'] as int?;
  String? get approvedBy => data['approvedBy'] as String?;
}

/// Usage example:
/// 
/// ```dart
/// // Initialize monitoring
/// final monitoringService = ChildMonitoringService.instance;
/// 
/// // Check permissions
/// final permissions = await monitoringService.checkPermissions();
/// if (!permissions.allGranted) {
///   // Request missing permissions
///   if (!permissions.usageStats) {
///     await monitoringService.requestUsageStatsPermission();
///   }
///   if (!permissions.overlay) {
///     await monitoringService.requestOverlayPermission();
///   }
/// }
/// 
/// // Start monitoring
/// final success = await monitoringService.startMonitoring(
///   familyId: 'family123',
///   childId: 'child456',
/// );
/// 
/// // Listen to events
/// monitoringService.events.listen((event) {
///   if (event.isRulesSynced) {
///     print('Rules synchronized successfully');
///   } else if (event.isUsageReset) {
///     print('Usage reset for ${event.packageName}');
///   }
/// });
/// 
/// // Get current usage data
/// final usageData = await monitoringService.getUsageData();
/// for (final usage in usageData) {
///   print('${usage.packageName}: ${usage.usageText}');
/// }
/// 
/// // Evaluate specific app
/// final evaluation = await monitoringService.evaluateApp('com.instagram.android');
/// if (evaluation?.isBlocked == true) {
///   print('Instagram is currently blocked');
/// }
/// ```