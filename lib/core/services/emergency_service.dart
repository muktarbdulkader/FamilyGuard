import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_sos_model.dart';
import '../models/notification_model.dart';
import 'geocoding_service.dart';

final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService.instance;
});

final activeEmergencyAlertsProvider = StreamProvider.family<List<EmergencyAlert>, String>((ref, familyId) {
  final service = ref.watch(emergencyServiceProvider);
  return service.getActiveAlertsStream(familyId);
});

class EmergencyService {
  static final EmergencyService instance = EmergencyService._internal();
  factory EmergencyService() => instance;
  EmergencyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _pendingSosCacheKey = 'cached_pending_emergency_sos';

  CollectionReference<Map<String, dynamic>> _alertsCollection(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('emergency_alerts');
  }

  /// Trigger high-priority Emergency SOS from child device
  Future<String> triggerEmergencySos({
    required String familyId,
    required String childId,
    required String childName,
    String? customMessage,
  }) async {
    final now = DateTime.now();
    double? lat;
    double? lng;
    String address = 'Location unavailable';

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      lat = pos.latitude;
      lng = pos.longitude;
      address =
          (await GeocodingService.instance.getPlaceName(pos.latitude, pos.longitude)) ??
          address;
    } catch (e) {
      debugPrint('Could not retrieve current GPS position for SOS: $e');
    }

    final alertData = {
      'familyId': familyId,
      'childId': childId,
      'childName': childName,
      'timestamp': Timestamp.fromDate(now),
      'createdAt': Timestamp.fromDate(now),
      'latitude': ?lat,
      'longitude': ?lng,
      'address': address,
      'status': AlertStatus.pending.name,
      'type': AlertType.sos.toDbString(),
      'message': customMessage ?? 'Emergency SOS Alert triggered!',
    };

    String alertId = '';

    try {
      final docRef = await _alertsCollection(familyId).add(alertData);
      alertId = docRef.id;

      // Send urgent FCM / Firestore notification to parents
      await _sendEmergencyParentNotification(
        familyId: familyId,
        childId: childId,
        childName: childName,
        alertId: alertId,
        type: NotificationType.emergencySos,
        location: address,
        lat: lat,
        lng: lng,
        message: customMessage ?? 'EMERGENCY: $childName triggered SOS!',
      );

      // Also process any cached offline alerts
      unawaited(processPendingOfflineAlerts(familyId));
    } catch (e) {
      debugPrint('Network error sending SOS, caching locally: $e');
      await _cacheOfflineAlert(alertData);
    }

    return alertId;
  }

  /// Send a quick safety check-in ping ("I'm safe", "Please call me", "Pick me up")
  Future<void> sendSafetyPing({
    required String familyId,
    required String childId,
    required String childName,
    required AlertType pingType,
    String? note,
  }) async {
    final now = DateTime.now();
    double? lat;
    double? lng;
    String address = 'Current location';

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      lat = pos.latitude;
      lng = pos.longitude;
      address =
          (await GeocodingService.instance.getPlaceName(pos.latitude, pos.longitude)) ??
          address;
    } catch (_) {}

    final alertData = {
      'familyId': familyId,
      'childId': childId,
      'childName': childName,
      'timestamp': Timestamp.fromDate(now),
      'createdAt': Timestamp.fromDate(now),
      'latitude': ?lat,
      'longitude': ?lng,
      'address': address,
      'status': AlertStatus.acknowledged.name, // check-in doesn't block
      'type': pingType.toDbString(),
      'message': note ?? pingType.displayName,
    };

    try {
      final docRef = await _alertsCollection(familyId).add(alertData);

      await _sendEmergencyParentNotification(
        familyId: familyId,
        childId: childId,
        childName: childName,
        alertId: docRef.id,
        type: NotificationType.safetyPing,
        location: address,
        lat: lat,
        lng: lng,
        message: note ?? pingType.displayName,
      );
    } catch (e) {
      debugPrint('Error sending safety ping: $e');
    }
  }

  /// Parent acknowledges an active alert
  Future<void> acknowledgeAlert({
    required String familyId,
    required String alertId,
    required String parentId,
    required String parentName,
  }) async {
    final now = DateTime.now();
    await _alertsCollection(familyId).doc(alertId).update({
      'status': AlertStatus.acknowledged.name,
      'acknowledgedBy': parentName,
      'acknowledgedAt': Timestamp.fromDate(now),
    });
  }

  /// Parent marks an active alert as resolved
  Future<void> resolveAlert({
    required String familyId,
    required String alertId,
    required String parentId,
    required String parentName,
    String? resolutionNotes,
  }) async {
    final now = DateTime.now();
    await _alertsCollection(familyId).doc(alertId).update({
      'status': AlertStatus.resolved.name,
      'resolvedBy': parentName,
      'resolvedAt': Timestamp.fromDate(now),
      'resolutionNotes': ?resolutionNotes,
    });
  }

  /// Stream active (unresolved) emergency alerts for parent dashboard
  Stream<List<EmergencyAlert>> getActiveAlertsStream(String familyId) {
    if (familyId.isEmpty) return Stream.value([]);

    return _alertsCollection(familyId)
        .where('status', whereIn: [AlertStatus.pending.name, AlertStatus.acknowledged.name])
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => EmergencyAlert.fromFirestore(doc)).toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  /// Send parent notification through Firestore notifications collection
  Future<void> _sendEmergencyParentNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String alertId,
    required NotificationType type,
    required String location,
    double? lat,
    double? lng,
    required String message,
  }) async {
    final now = DateTime.now();
    final notifData = {
      'familyId': familyId,
      'childId': childId,
      'childName': childName,
      'type': type.name,
      'priority': NotificationPriority.urgent.name,
      'title': NotificationTemplate.getTitle(type, childName),
      'body': NotificationTemplate.getBody(type, childName, {
        'address': location,
        'location': location,
        'message': message,
      }),
      'data': {
        'type': type.name,
        'alertId': alertId,
        'childId': childId,
        'childName': childName,
        'address': location,
        'latitude': lat,
        'longitude': lng,
        'message': message,
      },
      'createdAt': Timestamp.fromDate(now),
      'isRead': false,
    };

    try {
      await _firestore.collection('notifications').add(notifData);
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('notifications')
          .add(notifData);
    } catch (e) {
      debugPrint('Error pushing emergency notification to Firestore: $e');
    }
  }

  /// Cache alert locally for offline retry
  Future<void> _cacheOfflineAlert(Map<String, dynamic> alertData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingSosCacheKey) ?? [];
      list.add(jsonEncode(alertData));
      await prefs.setStringList(_pendingSosCacheKey, list);
    } catch (_) {}
  }

  /// Flush cached offline alerts when connection returns
  Future<void> processPendingOfflineAlerts(String familyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingSosCacheKey);
      if (list == null || list.isEmpty) return;

      final pending = List<String>.from(list);
      await prefs.remove(_pendingSosCacheKey);

      for (final jsonStr in pending) {
        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          await _alertsCollection(familyId).add(data);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
