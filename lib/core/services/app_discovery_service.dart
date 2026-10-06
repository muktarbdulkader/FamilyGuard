import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_info.dart';

/// Service for discovering and managing installed applications on child devices
/// Handles app scanning, change detection, and Firestore synchronization
class AppDiscoveryService {
  static const MethodChannel _channel = MethodChannel('family_guard/app_scanner');
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _periodicScanTimer;
  StreamController<AppDiscoveryEventInfo>? _eventController;
  
  // Cache for previously known apps
  Map<String, AppInfo> _knownApps = {};
  bool _isInitialized = false;
  
  /// Stream of app discovery events (install/uninstall/update)
  Stream<AppDiscoveryEventInfo> get eventStream {
    _eventController ??= StreamController<AppDiscoveryEventInfo>.broadcast();
    return _eventController!.stream;
  }

  /// Initialize the app discovery service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Set up method channel for receiving real-time events from Android
      _channel.setMethodCallHandler(_handleNativeEvent);
      
      // Load known apps from cache/Firestore
      await _loadKnownApps();
      
      // Start periodic scanning
      _startPeriodicScanning();
      
      _isInitialized = true;
      debugPrint('AppDiscoveryService initialized');
    } catch (e) {
      debugPrint('Failed to initialize AppDiscoveryService: $e');
      rethrow;
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    _periodicScanTimer?.cancel();
    _periodicScanTimer = null;
    _eventController?.close();
    _eventController = null;
    _isInitialized = false;
  }

  /// Perform a full scan of installed applications
  Future<List<AppInfo>> scanInstalledApps() async {
    try {
      debugPrint('Starting app scan...');
      
      // Get installed apps from native Android code
      final List<dynamic> rawApps = await _channel.invokeMethod('scanInstalledApps');
      
      final List<AppInfo> discoveredApps = [];
      final DateTime scanTime = DateTime.now();
      
      for (final dynamic rawApp in rawApps) {
        try {
          final Map<String, dynamic> appData = Map<String, dynamic>.from(rawApp);
          
          // Convert timestamps
          final firstInstallTime = DateTime.fromMillisecondsSinceEpoch(
            (appData['firstInstallTime'] as int) * 1000
          );
          final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(
            (appData['lastUpdateTime'] as int) * 1000
          );
          
          // Create AppInfo with discovery metadata
          final appInfo = AppInfo.newDetection(
            packageName: appData['packageName'],
            name: appData['name'] ?? appData['packageName'],
            version: appData['version'],
            isSystemApp: appData['isSystemApp'] ?? false,
          ).copyWith(
            detectedAt: firstInstallTime,
            updatedAt: lastUpdateTime.isAfter(scanTime) ? scanTime : lastUpdateTime,
          );
          
          discoveredApps.add(appInfo);
        } catch (e) {
          debugPrint('Error processing app data: $rawApp, error: $e');
        }
      }
      
      debugPrint('App scan completed. Found ${discoveredApps.length} apps');
      return discoveredApps;
    } catch (e) {
      debugPrint('Error scanning installed apps: $e');
      throw AppDiscoveryException('Failed to scan installed apps: $e');
    }
  }

  /// Detect changes in installed applications
  Future<List<AppDiscoveryEventInfo>> detectAppChanges() async {
    try {
      final currentApps = await scanInstalledApps();
      final events = <AppDiscoveryEventInfo>[];
      final currentTime = DateTime.now();
      
      // Convert current apps to map for efficient lookup
      final currentAppsMap = <String, AppInfo>{};
      for (final app in currentApps) {
        currentAppsMap[app.packageName] = app;
      }
      
      // Detect new apps (installed)
      for (final app in currentApps) {
        final knownApp = _knownApps[app.packageName];
        
        if (knownApp == null) {
          // New app detected
          events.add(AppDiscoveryEventInfo(
            event: AppDiscoveryEvent.appInstalled,
            appInfo: app,
            timestamp: currentTime,
          ));
          debugPrint('New app detected: ${app.displayName}');
        } else if (knownApp.version != app.version && app.version != null) {
          // App updated
          events.add(AppDiscoveryEventInfo(
            event: AppDiscoveryEvent.appUpdated,
            appInfo: app.updateMetadata(
              name: app.name,
              version: app.version,
            ),
            timestamp: currentTime,
            previousVersion: knownApp.version,
          ));
          debugPrint('App updated: ${app.displayName} (${knownApp.version} → ${app.version})');
        } else if (!knownApp.isAvailable) {
          // App reinstalled
          events.add(AppDiscoveryEventInfo(
            event: AppDiscoveryEvent.appReinstalled,
            appInfo: app.copyWith(isAvailable: true),
            timestamp: currentTime,
          ));
          debugPrint('App reinstalled: ${app.displayName}');
        }
      }
      
      // Detect removed apps (uninstalled)
      for (final knownPackage in _knownApps.keys) {
        if (!currentAppsMap.containsKey(knownPackage) && _knownApps[knownPackage]!.isAvailable) {
          final removedApp = _knownApps[knownPackage]!;
          events.add(AppDiscoveryEventInfo(
            event: AppDiscoveryEvent.appUninstalled,
            appInfo: removedApp.markUnavailable(),
            timestamp: currentTime,
          ));
          debugPrint('App uninstalled: ${removedApp.displayName}');
        }
      }
      
      // Update known apps cache
      _updateKnownAppsCache(currentAppsMap, events);
      
      return events;
    } catch (e) {
      debugPrint('Error detecting app changes: $e');
      return [];
    }
  }

  /// Get app icon as base64 string
  Future<String?> getAppIcon(String packageName) async {
    try {
      final String? iconBase64 = await _channel.invokeMethod('getAppIcon', packageName);
      return iconBase64;
    } catch (e) {
      debugPrint('Error getting app icon for $packageName: $e');
      return null;
    }
  }

  /// Check if specific app is installed
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final bool isInstalled = await _channel.invokeMethod('isAppInstalled', packageName);
      return isInstalled;
    } catch (e) {
      debugPrint('Error checking if app $packageName is installed: $e');
      return false;
    }
  }

  /// Synchronize apps with Firestore for specific child
  Future<void> synchronizeWithFirestore(String familyId, String childId) async {
    try {
      debugPrint('Synchronizing apps with Firestore for child $childId');
      
      // Get current apps
      final currentApps = await scanInstalledApps();
      
      // Get existing apps from Firestore
      final existingAppsSnapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(childId)
          .collection('apps')
          .get();
      
      final existingApps = <String, AppInfo>{};
      for (final doc in existingAppsSnapshot.docs) {
        try {
          final appInfo = AppInfo.fromFirestore(doc);
          existingApps[appInfo.packageName] = appInfo;
        } catch (e) {
          debugPrint('Error parsing existing app ${doc.id}: $e');
        }
      }
      
      // Synchronize each current app
      final batch = _firestore.batch();
      int batchOperations = 0;
      
      for (final app in currentApps) {
        final existingApp = existingApps[app.packageName];
        final docRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('children')
            .doc(childId)
            .collection('apps')
            .doc(app.packageName);
        
        if (existingApp == null) {
          // New app - add with default rule
          final newApp = app.copyWith(rule: AppControlRule.ask);
          batch.set(docRef, newApp.toFirestore());
          batchOperations++;
        } else {
          // Existing app - update metadata but preserve parent settings
          final updatedApp = existingApp.updateMetadata(
            name: app.name,
            version: app.version,
          ).copyWith(
            isAvailable: true, // Mark as available since it's currently installed
          );
          
          if (updatedApp != existingApp) {
            batch.update(docRef, updatedApp.toFirestore());
            batchOperations++;
          }
        }
        
        // Commit batch if getting large
        if (batchOperations >= 450) { // Stay under Firestore's 500 operation limit
          await batch.commit();
          batchOperations = 0;
        }
      }
      
      // Mark uninstalled apps as unavailable (don't delete for historical data)
      final currentPackages = currentApps.map((app) => app.packageName).toSet();
      for (final existingPackage in existingApps.keys) {
        if (!currentPackages.contains(existingPackage) && existingApps[existingPackage]!.isAvailable) {
          final docRef = _firestore
              .collection('families')
              .doc(familyId)
              .collection('children')
              .doc(childId)
              .collection('apps')
              .doc(existingPackage);
          
          final unavailableApp = existingApps[existingPackage]!.markUnavailable();
          batch.update(docRef, unavailableApp.toFirestore());
          batchOperations++;
          
          if (batchOperations >= 450) {
            await batch.commit();
            batchOperations = 0;
          }
        }
      }
      
      // Commit any remaining operations
      if (batchOperations > 0) {
        await batch.commit();
      }
      
      debugPrint('App synchronization completed');
    } catch (e) {
      debugPrint('Error synchronizing with Firestore: $e');
      throw AppDiscoveryException('Failed to synchronize apps: $e');
    }
  }

  /// Start periodic app scanning
  void _startPeriodicScanning() {
    // Scan every 30 minutes for app changes
    _periodicScanTimer?.cancel();
    _periodicScanTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      try {
        final events = await detectAppChanges();
        for (final event in events) {
          _eventController?.add(event);
        }
      } catch (e) {
        debugPrint('Error in periodic app scan: $e');
      }
    });
  }

  /// Load known apps from cache
  Future<void> _loadKnownApps() async {
    try {
      // Initial scan to populate known apps
      final apps = await scanInstalledApps();
      _knownApps = {for (final app in apps) app.packageName: app};
      debugPrint('Loaded ${_knownApps.length} known apps');
    } catch (e) {
      debugPrint('Error loading known apps: $e');
      _knownApps = {};
    }
  }

  /// Update known apps cache with changes
  void _updateKnownAppsCache(Map<String, AppInfo> currentApps, List<AppDiscoveryEventInfo> events) {
    // Update cache with current apps
    for (final app in currentApps.values) {
      _knownApps[app.packageName] = app;
    }
    
    // Mark uninstalled apps as unavailable in cache
    for (final event in events) {
      if (event.event == AppDiscoveryEvent.appUninstalled) {
        _knownApps[event.appInfo.packageName] = event.appInfo;
      }
    }
  }

  /// Handle real-time events from native Android code
  Future<void> _handleNativeEvent(MethodCall call) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
      final String packageName = data['packageName'];
      final int timestamp = data['timestamp'];
      final DateTime eventTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      AppDiscoveryEventInfo? event;
      
      switch (call.method) {
        case 'onAppInstalled':
          final Map<String, dynamic> appDetails = Map<String, dynamic>.from(data['appDetails']);
          final appInfo = _createAppInfoFromNativeData(appDetails);
          if (appInfo != null) {
            event = AppDiscoveryEventInfo(
              event: AppDiscoveryEvent.appInstalled,
              appInfo: appInfo,
              timestamp: eventTime,
            );
            _knownApps[packageName] = appInfo;
          }
          break;
          
        case 'onAppUninstalled':
          final knownApp = _knownApps[packageName];
          if (knownApp != null) {
            event = AppDiscoveryEventInfo(
              event: AppDiscoveryEvent.appUninstalled,
              appInfo: knownApp.markUnavailable(),
              timestamp: eventTime,
            );
            _knownApps[packageName] = knownApp.markUnavailable();
          }
          break;
          
        case 'onAppUpdated':
          final Map<String, dynamic> appDetails = Map<String, dynamic>.from(data['appDetails']);
          final appInfo = _createAppInfoFromNativeData(appDetails);
          final knownApp = _knownApps[packageName];
          if (appInfo != null && knownApp != null) {
            event = AppDiscoveryEventInfo(
              event: AppDiscoveryEvent.appUpdated,
              appInfo: appInfo,
              timestamp: eventTime,
              previousVersion: knownApp.version,
            );
            _knownApps[packageName] = appInfo;
          }
          break;
      }
      
      // Notify listeners of real-time event
      if (event != null) {
        _eventController?.add(event);
        debugPrint('Real-time app event: ${event.description}');
      }
    } catch (e) {
      debugPrint('Error handling native app event: $e');
    }
  }

  /// Create AppInfo from native Android data
  AppInfo? _createAppInfoFromNativeData(Map<String, dynamic> data) {
    try {
      final firstInstallTime = DateTime.fromMillisecondsSinceEpoch(
        (data['firstInstallTime'] as int) * 1000
      );
      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(
        (data['lastUpdateTime'] as int) * 1000
      );
      
      return AppInfo.newDetection(
        packageName: data['packageName'],
        name: data['name'] ?? data['packageName'],
        version: data['version'],
        isSystemApp: data['isSystemApp'] ?? false,
      ).copyWith(
        detectedAt: firstInstallTime,
        updatedAt: lastUpdateTime,
      );
    } catch (e) {
      debugPrint('Error creating AppInfo from native data: $e');
      return null;
    }
  }
}

/// Exception thrown by app discovery service
class AppDiscoveryException implements Exception {
  final String message;
  
  AppDiscoveryException(this.message);
  
  @override
  String toString() => 'AppDiscoveryException: $message';
}