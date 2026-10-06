import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

/// Permission service for managing Android permissions
/// Handles checking, requesting, and guiding users to permission settings
class PermissionService {
  static const MethodChannel _channel = MethodChannel('family_guardian/permissions');

  /// Start the monitoring foreground service
  /// This creates a persistent notification showing monitoring is active
  Future<bool> startMonitoringService() async {
    try {
      final bool started = await _channel.invokeMethod('startMonitoringService');
      return started;
    } catch (e) {
      throw PermissionException('Failed to start monitoring service: $e');
    }
  }

  /// Stop the monitoring foreground service
  Future<bool> stopMonitoringService() async {
    try {
      final bool stopped = await _channel.invokeMethod('stopMonitoringService');
      return stopped;
    } catch (e) {
      // Don't throw error for stopping service
      return false;
    }
  }

  /// Check if monitoring service is running
  Future<bool> isMonitoringServiceRunning() async {
    try {
      final bool isRunning = await _channel.invokeMethod('isMonitoringServiceRunning');
      return isRunning;
    } catch (e) {
      return false;
    }
  }

  /// Check if Usage Access permission is granted
  Future<bool> hasUsageStatsPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('hasUsageStatsPermission');
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  /// Open Usage Access settings page
  Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (e) {
      throw PermissionException('Failed to open Usage Access settings');
    }
  }

  /// Check if Display Over Other Apps permission is granted
  Future<bool> hasOverlayPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('hasOverlayPermission');
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  /// Open Display Over Other Apps settings page
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (e) {
      throw PermissionException('Failed to open overlay settings');
    }
  }

  /// Check notification permissions
  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Open notification settings page
  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  /// Check location permissions
  Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    final permission = await Geolocator.checkPermission();
    
    switch (permission) {
      case LocationPermission.always:
        return LocationPermissionStatus.always;
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  /// Request location permissions
  Future<LocationPermissionStatus> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    switch (permission) {
      case LocationPermission.always:
        return LocationPermissionStatus.always;
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  /// Open location settings page
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Check if battery optimization is disabled (important for background services)
  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool isDisabled = await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return isDisabled;
    } catch (e) {
      return false;
    }
  }

  /// Open battery optimization settings
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      throw PermissionException('Failed to open battery optimization settings');
    }
  }

  /// Create persistent notification for monitoring status
  /// DEPRECATED: Use startMonitoringService() instead
  @Deprecated('Use startMonitoringService() for foreground service notification')
  Future<void> createMonitoringNotification() async {
    await startMonitoringService();
  }

  /// Remove monitoring notification
  /// DEPRECATED: Use stopMonitoringService() instead
  @Deprecated('Use stopMonitoringService() to stop foreground service')
  Future<void> removeMonitoringNotification() async {
    await stopMonitoringService();
  }

  /// Get all permission statuses
  Future<PermissionStatus> getAllPermissionStatus() async {
    final hasUsageStats = await hasUsageStatsPermission();
    final hasOverlay = await hasOverlayPermission();
    final hasNotification = await hasNotificationPermission();
    final locationStatus = await getLocationPermissionStatus();

    final requiredPermissions = [
      hasUsageStats,
      hasOverlay,
      hasNotification,
      locationStatus == LocationPermissionStatus.always || 
      locationStatus == LocationPermissionStatus.whileInUse,
    ];

    if (requiredPermissions.every((granted) => granted)) {
      return PermissionStatus.allGranted;
    } else if (requiredPermissions.any((granted) => granted)) {
      return PermissionStatus.partial;
    } else {
      return PermissionStatus.none;
    }
  }

  /// Get comprehensive permission report for debugging
  Future<Map<String, dynamic>> getPermissionReport() async {
    final hasUsageStats = await hasUsageStatsPermission();
    final hasOverlay = await hasOverlayPermission();
    final hasNotification = await hasNotificationPermission();
    final locationStatus = await getLocationPermissionStatus();
    final batteryOptDisabled = await isBatteryOptimizationDisabled();
    final monitoringServiceRunning = await isMonitoringServiceRunning();

    return {
      'usageStats': {
        'granted': hasUsageStats,
        'description': 'Required for app usage monitoring and time limits',
        'settingsRequired': true,
      },
      'overlay': {
        'granted': hasOverlay,
        'description': 'Required for app blocking and time limit warnings',
        'settingsRequired': true,
      },
      'notifications': {
        'granted': hasNotification,
        'description': 'Required for monitoring status and safety alerts',
        'settingsRequired': false,
      },
      'location': {
        'status': locationStatus.name,
        'granted': locationStatus == LocationPermissionStatus.always || 
                  locationStatus == LocationPermissionStatus.whileInUse,
        'description': 'Required for family safety and location sharing',
        'settingsRequired': false,
      },
      'batteryOptimization': {
        'disabled': batteryOptDisabled,
        'description': 'Recommended for reliable background monitoring',
        'settingsRequired': true,
        'required': false,
      },
      'monitoringService': {
        'running': monitoringServiceRunning,
        'description': 'Persistent notification showing monitoring is active',
        'required': true,
      }
    };
  }
}

/// Location permission status enum
enum LocationPermissionStatus {
  always,
  whileInUse,
  denied,
  deniedForever,
  unknown,
}

/// Overall permission status
enum PermissionStatus {
  allGranted,
  partial,
  none,
}

/// Permission exception class
class PermissionException implements Exception {
  final String message;
  
  PermissionException(this.message);
  
  @override
  String toString() => message;
}