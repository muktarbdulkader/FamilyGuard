import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'local_cache_service.dart';
import '../models/app_model.dart';

/// Flutter service to manage native Android monitoring
/// Controls the native monitoring service and provides offline rule caching
class MonitoringService {
  static const MethodChannel _channel = MethodChannel('family_guard/monitoring');
  final LocalCacheService _cacheService = LocalCacheService();

  /// Start monitoring service with cached rules
  Future<void> startMonitoring({
    required String familyId,
    required String childId,
    required List<AppModel> appRules,
  }) async {
    try {
      // Cache rules locally for offline enforcement
      await _cacheService.cacheAppRules(
        childId: childId,
        apps: appRules,
      );

      // Start native Android monitoring service
      await _channel.invokeMethod('startMonitoring', {
        'familyId': familyId,
        'childId': childId,
      });

      // Mark as child device for boot receiver
      await _setChildDeviceFlag(true);
      await _setPermissionsFlag(true);

    } catch (e) {
      throw MonitoringException('Failed to start monitoring: ${e.toString()}');
    }
  }

  /// Stop monitoring service
  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
      await _setChildDeviceFlag(false);
      await _cacheService.clearCache();
    } catch (e) {
      // Don't throw error for stop operation
      if (kDebugMode) print('Failed to stop monitoring: $e');
    }
  }

  /// Update app rules in monitoring service
  Future<void> updateAppRules(List<AppModel> appRules) async {
    try {
      final childId = await _cacheService.getCachedChildId();
      if (childId != null) {
        // Update local cache
        await _cacheService.cacheAppRules(
          childId: childId,
          apps: appRules,
        );

        // Notify native service of rule changes
        await _channel.invokeMethod('updateRules', {
          'rules': appRules.map((app) => {
            'packageName': app.packageName,
            'rule': app.rule.toString(),
            'dailyLimitMinutes': app.dailyLimitMinutes,
            'allowedTimeWindow': app.allowedTimeWindow?.toMap(),
          }).toList(),
        });
      }
    } catch (e) {
      throw MonitoringException('Failed to update app rules: ${e.toString()}');
    }
  }

  /// Check if monitoring service is running
  Future<bool> isMonitoringActive() async {
    try {
      final result = await _channel.invokeMethod('isMonitoringActive');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  /// Get monitoring service status
  Future<Map<String, dynamic>> getMonitoringStatus() async {
    try {
      final result = await _channel.invokeMethod('getMonitoringStatus');
      final cacheStatus = await _cacheService.getCacheStatus();
      
      return {
        'isActive': result['isActive'] ?? false,
        'lastCheck': result['lastCheck'],
        'blockedCount': result['blockedCount'] ?? 0,
        'cache': cacheStatus,
      };
    } catch (e) {
      final cacheStatus = await _cacheService.getCacheStatus();
      return {
        'isActive': false,
        'error': e.toString(),
        'cache': cacheStatus,
      };
    }
  }

  /// Sync usage data from native service to Firestore
  Future<void> syncUsageData() async {
    try {
      // Get pending usage from cache
      final pendingUsage = await _cacheService.getPendingUsage();
      
      if (pendingUsage.isNotEmpty) {
        await _channel.invokeMethod('getUsageStats');

        // TODO: Upload to Firestore (will be implemented with parent app management)
        
        // Clear pending usage after successful sync
        await _cacheService.clearPendingUsage();
      }
    } catch (e) {
      print('Failed to sync usage data: $e');
    }
  }

  /// Handle app access requests from native service
  Future<void> handleAccessRequest(String packageName, String appName) async {
    try {
      // TODO: Send request to parent via Firebase/FCM
      // For now, just log the request
      print('Access request for $appName ($packageName)');
    } catch (e) {
      print('Failed to handle access request: $e');
    }
  }

  /// Set child device flag for boot receiver
  Future<void> _setChildDeviceFlag(bool isChild) async {
    try {
      await _channel.invokeMethod('setChildDeviceFlag', {'isChild': isChild});
    } catch (e) {
      // Ignore errors setting flag
    }
  }

  /// Set permissions flag for boot receiver
  Future<void> _setPermissionsFlag(bool hasPermissions) async {
    try {
      await _channel.invokeMethod('setPermissionsFlag', {'hasPermissions': hasPermissions});
    } catch (e) {
      // Ignore errors setting flag
    }
  }

  /// Create monitoring notification
  Future<void> createMonitoringNotification() async {
    try {
      await _channel.invokeMethod('createMonitoringNotification');
    } catch (e) {
      // Don't fail if notification creation fails
      print('Failed to create monitoring notification: $e');
    }
  }

  /// Update monitoring notification
  Future<void> updateMonitoringNotification(String message) async {
    try {
      await _channel.invokeMethod('updateMonitoringNotification', {
        'message': message,
      });
    } catch (e) {
      print('Failed to update monitoring notification: $e');
    }
  }

  /// Check if app is currently blocked
  Future<bool> isAppBlocked(String packageName) async {
    try {
      // Check cached rules first (offline-first approach)
      final cachedRule = await _cacheService.getCachedAppRule(packageName);
      
      if (cachedRule != null) {
        return !cachedRule.isCurrentlyAllowed;
      }
      
      // Fallback to asking native service
      final result = await _channel.invokeMethod('isAppBlocked', {
        'packageName': packageName,
      });
      return result as bool;
    } catch (e) {
      // Default to allowing if check fails
      return false;
    }
  }

  /// Get current foreground app (for testing/debugging)
  Future<String?> getCurrentForegroundApp() async {
    try {
      final result = await _channel.invokeMethod('getCurrentForegroundApp');
      return result as String?;
    } catch (e) {
      return null;
    }
  }
}

/// Exception class for monitoring service operations
class MonitoringException implements Exception {
  final String message;

  MonitoringException(this.message);

  @override
  String toString() => message;
}