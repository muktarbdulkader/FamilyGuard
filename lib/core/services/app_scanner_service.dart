import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_model.dart';
import '../constants/app_constants.dart';

/// Service for scanning installed apps using real Android PackageManager API
/// This uses native Android APIs to get REAL app information, not fake data
class AppScannerService {
  static const MethodChannel _channel = MethodChannel('family_guard/app_scanner');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Scan all installed apps using native Android PackageManager
  /// Returns real app information from the device
  Future<List<InstalledAppInfo>> scanInstalledApps() async {
    try {
      final List<dynamic> appsData = await _channel.invokeMethod('scanInstalledApps');
      
      return appsData.map((appData) {
        final app = Map<String, dynamic>.from(appData);
        return InstalledAppInfo(
          packageName: app['packageName'] ?? '',
          appName: app['appName'] ?? '',
          iconBytes: app['iconBytes'] != null 
              ? Uint8List.fromList(List<int>.from(app['iconBytes']))
              : null,
          version: app['version'] ?? '',
          installTime: DateTime.fromMillisecondsSinceEpoch(app['installTime'] ?? 0),
          lastUpdateTime: DateTime.fromMillisecondsSinceEpoch(app['lastUpdateTime'] ?? 0),
          isSystemApp: app['isSystemApp'] ?? false,
        );
      }).toList();
    } catch (e) {
      throw AppScannerException('Failed to scan installed apps: ${e.toString()}');
    }
  }

  /// Upload scanned apps to Firestore for the child device
  Future<void> uploadAppsToFirestore({
    required String familyId,
    required String childId,
    required List<InstalledAppInfo> apps,
  }) async {
    try {
      final batch = _firestore.batch();
      final childAppsRef = _firestore
          .collection(AppConstants.familiesCollection)
          .doc(familyId)
          .collection(AppConstants.childrenSubcollection)
          .doc(childId)
          .collection(AppConstants.appsSubcollection);

      // Get existing apps to preserve rules set by parents
      final existingAppsSnapshot = await childAppsRef.get();
      final existingApps = Map<String, AppModel>.fromIterable(
        existingAppsSnapshot.docs,
        key: (doc) => doc.id,
        value: (doc) => AppModel.fromFirestore(doc),
      );

      final now = DateTime.now();
      final systemPackages = await _getSystemPackageNames();

      for (final app in apps) {
        // Skip system apps that shouldn't be managed
        if (systemPackages.contains(app.packageName)) {
          continue;
        }

        final existingApp = existingApps[app.packageName];
        
        // Create new app model or update existing one
        final appModel = AppModel(
          packageName: app.packageName,
          appName: app.appName,
          iconBase64: app.iconBytes != null ? base64Encode(app.iconBytes!) : null,
          version: app.version,
          installedDate: app.installTime,
          lastUsed: existingApp?.lastUsed ?? now,
          isSystemApp: app.isSystemApp,
          rule: existingApp?.rule ?? AppRule.askParent, // Default to ask parent for new apps
          dailyLimitMinutes: existingApp?.dailyLimitMinutes ?? 0,
          allowedTimeWindow: existingApp?.allowedTimeWindow,
          usedTodayMinutes: existingApp?.usedTodayMinutes ?? 0,
          lastUpdated: now,
        );

        batch.set(childAppsRef.doc(app.packageName), appModel.toFirestore());
      }

      // Remove apps that are no longer installed
      final currentPackageNames = apps.map((app) => app.packageName).toSet();
      for (final existingPackage in existingApps.keys) {
        if (!currentPackageNames.contains(existingPackage)) {
          batch.delete(childAppsRef.doc(existingPackage));
        }
      }

      await batch.commit();
    } catch (e) {
      throw AppScannerException('Failed to upload apps to Firestore: ${e.toString()}');
    }
  }

  /// Check for newly installed apps and notify parent
  Future<List<InstalledAppInfo>> checkForNewApps({
    required String familyId,
    required String childId,
  }) async {
    try {
      // Get current installed apps
      final currentApps = await scanInstalledApps();
      final currentPackageNames = currentApps.map((app) => app.packageName).toSet();

      // Get apps already in Firestore
      final childAppsRef = _firestore
          .collection(AppConstants.familiesCollection)
          .doc(familyId)
          .collection(AppConstants.childrenSubcollection)
          .doc(childId)
          .collection(AppConstants.appsSubcollection);
      
      final existingAppsSnapshot = await childAppsRef.get();
      final existingPackageNames = existingAppsSnapshot.docs.map((doc) => doc.id).toSet();

      // Find new apps
      final newPackageNames = currentPackageNames.difference(existingPackageNames);
      final newApps = currentApps.where((app) => newPackageNames.contains(app.packageName)).toList();

      if (newApps.isNotEmpty) {
        // Upload new apps with default "ask parent" rule
        await uploadAppsToFirestore(
          familyId: familyId,
          childId: childId,
          apps: newApps,
        );

        // Create notification for parent about new apps
        await _notifyParentOfNewApps(familyId, childId, newApps);
      }

      return newApps;
    } catch (e) {
      throw AppScannerException('Failed to check for new apps: ${e.toString()}');
    }
  }

  /// Get system package names that should not be managed
  Future<Set<String>> _getSystemPackageNames() async {
    try {
      final List<dynamic> systemPackages = await _channel.invokeMethod('getSystemPackages');
      return systemPackages.cast<String>().toSet();
    } catch (e) {
      // Fallback to common system packages
      return {
        'android',
        'com.android.systemui',
        'com.android.settings',
        'com.android.launcher',
        'com.android.phone',
        'com.android.contacts',
        'com.android.dialer',
        'com.android.messaging',
      };
    }
  }

  /// Notify parent about newly installed apps
  Future<void> _notifyParentOfNewApps(
    String familyId,
    String childId,
    List<InstalledAppInfo> newApps,
  ) async {
    try {
      // Create a notification document for the parent
      final notificationRef = _firestore
          .collection(AppConstants.familiesCollection)
          .doc(familyId)
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'type': 'new_apps_installed',
        'childId': childId,
        'apps': newApps.map((app) => {
          'packageName': app.packageName,
          'appName': app.appName,
        }).toList(),
        'createdAt': Timestamp.now(),
        'isRead': false,
      });

      // TODO: Send FCM notification to parent (will be implemented in request/approval system)
    } catch (e) {
      // Don't fail the main operation if notification fails
      debugPrint('Failed to notify parent of new apps: $e');
    }
  }

  /// Start monitoring for app installations/removals
  Future<void> startAppInstallationMonitoring({
    required String familyId,
    required String childId,
  }) async {
    try {
      await _channel.invokeMethod('startAppInstallationMonitoring', {
        'familyId': familyId,
        'childId': childId,
      });
    } catch (e) {
      throw AppScannerException('Failed to start app installation monitoring: ${e.toString()}');
    }
  }

  /// Stop monitoring for app installations/removals
  Future<void> stopAppInstallationMonitoring() async {
    try {
      await _channel.invokeMethod('stopAppInstallationMonitoring');
    } catch (e) {
      // Don't throw error for stop operation
      debugPrint('Failed to stop app installation monitoring: $e');
    }
  }

  /// Get app usage statistics using UsageStatsManager
  /// This provides REAL usage data from Android system
  Future<Map<String, int>> getAppUsageStats({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _channel.invokeMethod('getAppUsageStats', {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      });

      return Map<String, int>.from(result);
    } catch (e) {
      throw AppScannerException('Failed to get app usage stats: ${e.toString()}');
    }
  }

  /// Update app usage in Firestore
  Future<void> updateAppUsage({
    required String familyId,
    required String childId,
    required Map<String, int> usageStats,
  }) async {
    try {
      final batch = _firestore.batch();
      final childAppsRef = _firestore
          .collection(AppConstants.familiesCollection)
          .doc(familyId)
          .collection(AppConstants.childrenSubcollection)
          .doc(childId)
          .collection(AppConstants.appsSubcollection);

      for (final entry in usageStats.entries) {
        final packageName = entry.key;
        final usageMinutes = (entry.value / 60000).round(); // Convert ms to minutes

        final appDoc = childAppsRef.doc(packageName);
        batch.update(appDoc, {
          'usedTodayMinutes': usageMinutes,
          'lastUsed': Timestamp.now(),
          'lastUpdated': Timestamp.now(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw AppScannerException('Failed to update app usage: ${e.toString()}');
    }
  }
}

/// Model for installed app information from native Android
class InstalledAppInfo {
  final String packageName;
  final String appName;
  final Uint8List? iconBytes;
  final String version;
  final DateTime installTime;
  final DateTime lastUpdateTime;
  final bool isSystemApp;

  const InstalledAppInfo({
    required this.packageName,
    required this.appName,
    this.iconBytes,
    required this.version,
    required this.installTime,
    required this.lastUpdateTime,
    required this.isSystemApp,
  });

  @override
  String toString() {
    return 'InstalledAppInfo(packageName: $packageName, appName: $appName)';
  }
}

/// Exception class for app scanner operations
class AppScannerException implements Exception {
  final String message;

  AppScannerException(this.message);

  @override
  String toString() => message;
}