import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyLocation {
  final String id;
  final String familyId;
  final String childId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final String? address;
  final bool isStale;

  const FamilyLocation({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
    this.address,
    this.isStale = false,
  });

  factory FamilyLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    
    return FamilyLocation(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      childId: data['childId'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      accuracy: data['accuracy']?.toDouble(),
      altitude: data['altitude']?.toDouble(),
      speed: data['speed']?.toDouble(),
      heading: data['heading']?.toDouble(),
      timestamp: timestamp,
      address: data['address'],
      isStale: _isLocationStale(timestamp),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'childId': childId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'timestamp': Timestamp.fromDate(timestamp),
      'address': address,
    };
  }

  static bool _isLocationStale(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inMinutes > 30; // Consider stale after 30 minutes
  }

  double distanceTo(FamilyLocation other) {
    // Haversine formula for calculating distance between two points
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final lat1Rad = latitude * (3.14159265359 / 180);
    final lat2Rad = other.latitude * (3.14159265359 / 180);
    final deltaLatRad = (other.latitude - latitude) * (3.14159265359 / 180);
    final deltaLngRad = (other.longitude - longitude) * (3.14159265359 / 180);
    
    final a = (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLngRad / 2).sin() * (deltaLngRad / 2).sin();
    
    final c = 2 * (a.sqrt()).asin();
    
    return earthRadius * c;
  }

  FamilyLocation copyWith({
    String? id,
    String? familyId,
    String? childId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? address,
    bool? isStale,
  }) {
    return FamilyLocation(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      childId: childId ?? this.childId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      isStale: isStale ?? this.isStale,
    );
  }
}

class LocationSharingSettings {
  final String familyId;
  final bool isEnabled;
  final Duration updateInterval;
  final double minimumDistance;
  final bool shareOnlyWhenAppOpen;
  final DateTime? enabledAt;
  final String? enabledBy;
  final List<String> enabledForChildren;

  const LocationSharingSettings({
    required this.familyId,
    this.isEnabled = false,
    this.updateInterval = const Duration(minutes: 5),
    this.minimumDistance = 50.0, // meters
    this.shareOnlyWhenAppOpen = false,
    this.enabledAt,
    this.enabledBy,
    this.enabledForChildren = const [],
  });

  factory LocationSharingSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return LocationSharingSettings(
      familyId: doc.id,
      isEnabled: data['isEnabled'] ?? false,
      updateInterval: Duration(minutes: data['updateIntervalMinutes'] ?? 5),
      minimumDistance: (data['minimumDistance'] ?? 50.0).toDouble(),
      shareOnlyWhenAppOpen: data['shareOnlyWhenAppOpen'] ?? false,
      enabledAt: (data['enabledAt'] as Timestamp?)?.toDate(),
      enabledBy: data['enabledBy'],
      enabledForChildren: List<String>.from(data['enabledForChildren'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isEnabled': isEnabled,
      'updateIntervalMinutes': updateInterval.inMinutes,
      'minimumDistance': minimumDistance,
      'shareOnlyWhenAppOpen': shareOnlyWhenAppOpen,
      'enabledAt': enabledAt != null ? Timestamp.fromDate(enabledAt!) : null,
      'enabledBy': enabledBy,
      'enabledForChildren': enabledForChildren,
    };
  }

  LocationSharingSettings copyWith({
    String? familyId,
    bool? isEnabled,
    Duration? updateInterval,
    double? minimumDistance,
    bool? shareOnlyWhenAppOpen,
    DateTime? enabledAt,
    String? enabledBy,
    List<String>? enabledForChildren,
  }) {
    return LocationSharingSettings(
      familyId: familyId ?? this.familyId,
      isEnabled: isEnabled ?? this.isEnabled,
      updateInterval: updateInterval ?? this.updateInterval,
      minimumDistance: minimumDistance ?? this.minimumDistance,
      shareOnlyWhenAppOpen: shareOnlyWhenAppOpen ?? this.shareOnlyWhenAppOpen,
      enabledAt: enabledAt ?? this.enabledAt,
      enabledBy: enabledBy ?? this.enabledBy,
      enabledForChildren: enabledForChildren ?? this.enabledForChildren,
    );
  }
}

enum LocationPermissionStatus {
  notRequested,
  denied,
  foregroundOnly,
  backgroundAllowed,
}

class LocationPermissionInfo {
  final LocationPermissionStatus status;
  final bool isPrecise;
  final bool batteryOptimizationDisabled;
  final String? denialReason;

  const LocationPermissionInfo({
    required this.status,
    this.isPrecise = false,
    this.batteryOptimizationDisabled = false,
    this.denialReason,
  });

  bool get canShareLocation => 
      status != LocationPermissionStatus.denied && 
      status != LocationPermissionStatus.notRequested;

  bool get canShareInBackground => 
      status == LocationPermissionStatus.backgroundAllowed &&
      batteryOptimizationDisabled;

  LocationPermissionInfo copyWith({
    LocationPermissionStatus? status,
    bool? isPrecise,
    bool? batteryOptimizationDisabled,
    String? denialReason,
  }) {
    return LocationPermissionInfo(
      status: status ?? this.status,
      isPrecise: isPrecise ?? this.isPrecise,
      batteryOptimizationDisabled: batteryOptimizationDisabled ?? this.batteryOptimizationDisabled,
      denialReason: denialReason ?? this.denialReason,
    );
  }
}