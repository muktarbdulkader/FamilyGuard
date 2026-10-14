import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationUpdateTimer;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  
  bool _isInitialized = false;
  bool _isSharing = false;
  String? _currentFamilyId;
  String? _currentChildId;
  String? _currentChildName;
  LocationSharingSettings? _currentSettings;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Load saved settings
    await _loadSavedSettings();
    
    _isInitialized = true;
  }

  Future<LocationPermissionInfo> checkLocationPermission() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationPermissionInfo(
          status: LocationPermissionStatus.denied,
          denialReason: 'Location services are disabled',
        );
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        return const LocationPermissionInfo(
          status: LocationPermissionStatus.denied,
          denialReason: 'Location permission denied',
        );
      }
      
      if (permission == LocationPermission.deniedForever) {
        return const LocationPermissionInfo(
          status: LocationPermissionStatus.denied,
          denialReason: 'Location permission permanently denied',
        );
      }

      // Check if we have background permission (Android 10+)
      bool hasBackground = true;
      if (Platform.isAndroid) {
        // Note: geolocator doesn't directly check background permission
        // In a real implementation, you'd use platform channels to check
        // For now, we'll assume foreground permission means background is possible
        hasBackground = permission == LocationPermission.always;
      }

      final status = hasBackground 
          ? LocationPermissionStatus.backgroundAllowed
          : LocationPermissionStatus.foregroundOnly;

      // Check battery optimization (simplified)
      final batteryOptimized = await _isBatteryOptimizationDisabled();

      return LocationPermissionInfo(
        status: status,
        isPrecise: true,
        batteryOptimizationDisabled: batteryOptimized,
      );

    } catch (e) {
      if (kDebugMode) {
        print('Error checking location permission: $e');
      }
      return const LocationPermissionInfo(
        status: LocationPermissionStatus.denied,
        denialReason: 'Error checking permissions',
      );
    }
  }

  Future<LocationPermissionInfo> requestLocationPermission() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationPermissionInfo(
          status: LocationPermissionStatus.denied,
          denialReason: 'Location permission denied by user',
        );
      }

      return await checkLocationPermission();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting location permission: $e');
      }
      return const LocationPermissionInfo(
        status: LocationPermissionStatus.denied,
        denialReason: 'Error requesting permission',
      );
    }
  }

  Future<bool> _isBatteryOptimizationDisabled() async {
    // In a real implementation, you'd use platform channels to check
    // battery optimization status. For now, return true.
    return true;
  }

  Future<LocationSharingSettings?> getFamilyLocationSettings(String familyId) async {
    try {
      final doc = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('settings')
          .doc('location_sharing')
          .get();

      if (!doc.exists) {
        return LocationSharingSettings(familyId: familyId);
      }

      return LocationSharingSettings.fromFirestore(doc);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error loading location settings: $e');
      }
      return null;
    }
  }

  Future<bool> enableLocationSharing({
    required String familyId,
    required List<String> childIds,
    Duration updateInterval = const Duration(minutes: 5),
    double minimumDistance = 50.0,
    bool shareOnlyWhenAppOpen = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final settings = LocationSharingSettings(
        familyId: familyId,
        isEnabled: true,
        updateInterval: updateInterval,
        minimumDistance: minimumDistance,
        shareOnlyWhenAppOpen: shareOnlyWhenAppOpen,
        enabledAt: DateTime.now(),
        enabledBy: user.uid,
        enabledForChildren: childIds,
      );

      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('settings')
          .doc('location_sharing')
          .set(settings.toFirestore());

      // Save locally
      await _saveSettings(settings);
      _currentSettings = settings;
      _currentFamilyId = familyId;

      return true;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling location sharing: $e');
      }
      return false;
    }
  }

  Future<bool> disableLocationSharing(String familyId) async {
    try {
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('settings')
          .doc('location_sharing')
          .update({
        'isEnabled': false,
        'disabledAt': FieldValue.serverTimestamp(),
      });

      // Stop sharing
      await stopLocationSharing();

      // Clear local settings
      await _clearSavedSettings();
      
      return true;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling location sharing: $e');
      }
      return false;
    }
  }

  /// Starts direct location sharing for a child device without requiring explicit parent toggling
  Future<bool> startChildSharing({
    required String familyId,
    required String childId,
    String? childName,
  }) async {
    try {
      _currentFamilyId = familyId;
      _currentChildId = childId;
      if (childName != null && childName.isNotEmpty) {
        _currentChildName = childName;
      }

      // Check or request location permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('Location permission denied for child: $childId');
        }
        return false;
      }

      _currentSettings ??= LocationSharingSettings(
        familyId: familyId,
        isEnabled: true,
        updateInterval: const Duration(minutes: 3),
        minimumDistance: 15.0,
        enabledForChildren: [childId],
      );

      _isSharing = true;

      // 1. Immediately attempt to get current GPS position and upload to Firestore
      try {
        final initialPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        await _handleLocationUpdate(initialPosition);
      } catch (e) {
        if (kDebugMode) {
          print('Could not get initial position fix: $e');
        }
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            await _handleLocationUpdate(lastKnown);
          }
        } catch (_) {}
      }

      // 2. Start continuous GPS stream and periodic updates
      await _startBackgroundLocationUpdates();

      if (kDebugMode) {
        print('Location sharing successfully started for child $childId in family $familyId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting child sharing: $e');
      }
      return false;
    }
  }

  Future<void> startLocationSharing(String familyId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await startChildSharing(
      familyId: familyId,
      childId: user.uid,
      childName: user.displayName,
    );
  }

  Future<void> stopLocationSharing() async {
    if (!_isSharing) return;

    try {
      // Cancel location updates
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;

      _isSharing = false;
      _lastPosition = null;
      _lastUpdateTime = null;

      if (kDebugMode) {
        print('Location sharing stopped');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping location sharing: $e');
      }
    }
  }

  Future<void> startForegroundLocationUpdates() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Update when moved 15 meters
    );

    await _locationSubscription?.cancel();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handleLocationUpdate,
      onError: (error) {
        if (kDebugMode) {
          print('Location stream error: $error');
        }
      },
    );
  }

  Future<void> _startBackgroundLocationUpdates() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Update when moved 15 meters
    );

    await _locationSubscription?.cancel();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handleLocationUpdate,
      onError: (error) {
        if (kDebugMode) {
          print('Location stream error: $error');
        }
      },
    );

    // Also set up periodic updates every 3 minutes so timestamps remain fresh
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _updateLocationPeriodically(),
    );
  }

  Future<void> _updateLocationPeriodically() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      
      await _handleLocationUpdate(position);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error in periodic location update: $e');
      }
    }
  }

  Future<void> _handleLocationUpdate(Position position) async {
    final familyId = _currentFamilyId;
    final childId = _currentChildId ?? _auth.currentUser?.uid;
    
    if (familyId == null || childId == null) return;

    final now = DateTime.now();

    // Throttle: don't write more frequently than once every 15 seconds
    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate = now.difference(_lastUpdateTime!);
      if (timeSinceLastUpdate < const Duration(seconds: 15)) {
        return;
      }
    }

    // Distance check: If moved < 15 meters AND updated in the last 3 minutes, skip
    if (_lastPosition != null && _lastUpdateTime != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final timeSinceLast = now.difference(_lastUpdateTime!);
      if (distance < 15 && timeSinceLast < const Duration(minutes: 3)) {
        return;
      }
    }

    try {
      final location = FamilyLocation(
        id: now.millisecondsSinceEpoch.toString(),
        familyId: familyId,
        childId: childId,
        childName: _currentChildName,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        timestamp: now,
      );

      final locationMap = location.toFirestore();

      // 1. Update latest location on the child document (using set with merge: true)
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(childId)
          .set({
        'lastLocation': locationMap,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        if (_currentChildName != null && _currentChildName!.isNotEmpty)
          'displayName': _currentChildName,
      }, SetOptions(merge: true));

      // 2. Also record in historical locations subcollection
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(childId)
          .collection('locations')
          .doc(location.id)
          .set(locationMap);

      _lastPosition = position;
      _lastUpdateTime = now;

      if (kDebugMode) {
        print('Location updated: ${position.latitude}, ${position.longitude} for child $childId');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading location: $e');
      }
    }
  }

  Stream<List<FamilyLocation>> getFamilyLocations(String familyId) {
    if (familyId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('children')
        .snapshots()
        .map((snapshot) {
      final locations = <FamilyLocation>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lastLocation = data['lastLocation'] as Map<String, dynamic>?;
        
        if (lastLocation != null) {
          try {
            final childName = (data['displayName'] ?? data['name'] ?? lastLocation['childName']) as String?;
            final location = FamilyLocation.fromMap(
              {
                ...lastLocation,
                'childId': doc.id,
                'childName': ?childName,
              },
              id: doc.id,
            );
            locations.add(location);
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing location for child ${doc.id}: $e');
            }
          }
        }
      }
      
      return locations;
    });
  }

  Future<FamilyLocation?> getChildLatestLocation(String familyId, String childId) async {
    try {
      final doc = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('children')
          .doc(childId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      final lastLocation = data?['lastLocation'] as Map<String, dynamic>?;
      
      if (lastLocation == null) return null;

      return FamilyLocation.fromMap(
        lastLocation,
        id: childId,
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('Error getting child location: $e');
      }
      return null;
    }
  }

  Future<void> _saveSettings(LocationSharingSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_enabled', settings.isEnabled);
      await prefs.setString('location_family_id', settings.familyId);
      await prefs.setInt('location_update_interval', settings.updateInterval.inMinutes);
      await prefs.setDouble('location_min_distance', settings.minimumDistance);
      await prefs.setBool('location_foreground_only', settings.shareOnlyWhenAppOpen);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving location settings: $e');
      }
    }
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('location_sharing_enabled') ?? false;
      final familyId = prefs.getString('location_family_id');
      
      if (isEnabled && familyId != null) {
        _currentSettings = LocationSharingSettings(
          familyId: familyId,
          isEnabled: isEnabled,
          updateInterval: Duration(minutes: prefs.getInt('location_update_interval') ?? 5),
          minimumDistance: prefs.getDouble('location_min_distance') ?? 50.0,
          shareOnlyWhenAppOpen: prefs.getBool('location_foreground_only') ?? false,
        );
        _currentFamilyId = familyId;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading location settings: $e');
      }
    }
  }

  Future<void> _clearSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('location_sharing_enabled');
      await prefs.remove('location_family_id');
      await prefs.remove('location_update_interval');
      await prefs.remove('location_min_distance');
      await prefs.remove('location_foreground_only');
      
      _currentSettings = null;
      _currentFamilyId = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing location settings: $e');
      }
    }
  }

  bool get isLocationSharingActive => _isSharing;
  LocationSharingSettings? get currentSettings => _currentSettings;

  Future<void> dispose() async {
    await stopLocationSharing();
  }
}