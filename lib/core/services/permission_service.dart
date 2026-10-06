import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

/// Permission service for managing Android permissions
/// Handles checking, requesting, and guiding users to permission settings
class PermissionService {
  static const MethodChannel _channel = MethodChannel('family_guardian/permissions');

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

  /// Check if Accessibility Service is enabled
  Future<bool> hasAccessibilityPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('hasAccessibilityPermission');
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  /// Open Accessibility Service settings page
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      throw PermissionException('Failed to open accessibility settings');
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

  /// Check if device admin permission is granted
  Future<bool> hasDeviceAdminPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('hasDeviceAdminPermission');
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  /// Request device admin permission
  Future<void> requestDeviceAdminPermission() async {
    try {
      await _channel.invokeMethod('requestDeviceAdminPermission');
    } catch (e) {
      throw PermissionException('Failed to request device admin permission');
    }
  }

  /// Create persistent notification for monitoring status
  Future<void> createMonitoringNotification() async {
    try {
      await _channel.invokeMethod('createMonitoringNotification');
    } catch (e) {
      throw PermissionException('Failed to create monitoring notification');
    }
  }

  /// Remove monitoring notification
  Future<void> removeMonitoringNotification() async {
    try {
      await _channel.invokeMethod('removeMonitoringNotification');
    } catch (e) {
      // Don't throw error for removal failure
    }
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