import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_sos_model.dart';
import '../models/notification_model.dart';
import '../models/activity_log_model.dart';
import 'audit_service.dart';
import 'geocoding_service.dart';

final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService.instance;
});

final activeEmergencyAlertsProvider = StreamProvider.family<List<EmergencyAlert>, String>((ref, familyId) {
  final service = ref.watch(emergencyServiceProvider);
  return service.getActiveAlertsStream(familyId);
});

enum EmergencySubmissionStatus {
  recorded,
  notificationPending,
  queuedOffline,
}

class EmergencySubmissionResult {
  final String? alertId;
  final EmergencySubmissionStatus status;

  const EmergencySubmissionResult({
    required this.alertId,
    required this.status,
  });
}

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
  Future<EmergencySubmissionResult> triggerEmergencySos({
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

    return _submitAlert(
      familyId: familyId,
      childId: childId,
      childName: childName,
      alertData: alertData,
      alertType: AlertType.sos,
      location: address,
      latitude: lat,
      longitude: lng,
      message: customMessage ?? 'EMERGENCY: $childName triggered SOS!',
      activityType: ActivityType.emergencySos,
      activityTitle: 'Emergency SOS sent',
      activityDescription: '$childName sent an emergency SOS.',
    );
  }

  /// Send a quick safety check-in ping ("I'm safe", "Please call me", "Pick me up")
  Future<EmergencySubmissionResult> sendSafetyPing({
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

    return _submitAlert(
      familyId: familyId,
      childId: childId,
      childName: childName,
      alertData: alertData,
      alertType: pingType,
      location: address,
      latitude: lat,
      longitude: lng,
      message: note ?? pingType.displayName,
      activityType: ActivityType.safetyCheckIn,
      activityTitle: 'Safety check-in sent',
      activityDescription: '$childName sent: ${note ?? pingType.displayName}.',
    );
  }

  Future<EmergencySubmissionResult> _submitAlert({
    required String familyId,
    required String childId,
    required String childName,
    required Map<String, dynamic> alertData,
    required AlertType alertType,
    required String location,
    required double? latitude,
    required double? longitude,
    required String message,
    required ActivityType activityType,
    required String activityTitle,
    required String activityDescription,
  }) async {
    final alertRef = _alertsCollection(familyId).doc();
    try {
      await alertRef.set(alertData);
    } catch (e) {
      debugPrint('Could not submit emergency alert; saving for retry: $e');
      await _cacheOfflineAlert(
        familyId: familyId,
        alertId: alertRef.id,
        alertData: alertData,
      );
      return const EmergencySubmissionResult(
        alertId: null,
        status: EmergencySubmissionStatus.queuedOffline,
      );
    }

    await AuditService.instance.logEvent(
      familyId: familyId,
      childId: childId,
      childName: childName,
      actorId: childId,
      actorName: childName,
      actorRole: 'child',
      type: activityType,
      title: activityTitle,
      description: activityDescription,
      metadata: {'alertId': alertRef.id},
      eventId: 'emergency_${alertRef.id}',
    );

    final notificationWritten = await _sendEmergencyParentNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      alertId: alertRef.id,
      type: alertType == AlertType.sos
          ? NotificationType.emergencySos
          : NotificationType.safetyPing,
      location: location,
      lat: latitude,
      lng: longitude,
      message: message,
    );

    if (!notificationWritten) {
      await _cacheOfflineAlert(
        familyId: familyId,
        alertId: alertRef.id,
        alertData: alertData,
      );
    }
    unawaited(processPendingOfflineAlerts(familyId));

    return EmergencySubmissionResult(
      alertId: alertRef.id,
      status: notificationWritten
          ? EmergencySubmissionStatus.recorded
          : EmergencySubmissionStatus.notificationPending,
    );
  }

  /// Parent acknowledges an active alert
  Future<void> acknowledgeAlert({
    required String familyId,
    required String alertId,
    required String parentId,
    required String parentName,
  }) async {
    final now = DateTime.now();
    final alertRef = _alertsCollection(familyId).doc(alertId);
    final alertDoc = await alertRef.get();
    await alertRef.update({
      'status': AlertStatus.acknowledged.name,
      'acknowledgedBy': parentName,
      'acknowledgedAt': Timestamp.fromDate(now),
    });
    final alert = EmergencyAlert.fromFirestore(alertDoc);
    await AuditService.instance.logEvent(
      familyId: familyId,
      childId: alert.childId,
      childName: alert.childName,
      actorId: parentId,
      actorName: parentName,
      type: alert.isSos ? ActivityType.emergencySos : ActivityType.safetyCheckIn,
      title: alert.isSos ? 'Emergency SOS acknowledged' : 'Safety check-in acknowledged',
      description: '$parentName acknowledged an alert from ${alert.childName}.',
      metadata: {'alertId': alertId},
    );
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
    final alertRef = _alertsCollection(familyId).doc(alertId);
    final alertDoc = await alertRef.get();
    await alertRef.update({
      'status': AlertStatus.resolved.name,
      'resolvedBy': parentName,
      'resolvedAt': Timestamp.fromDate(now),
      'resolutionNotes': ?resolutionNotes,
    });
    final alert = EmergencyAlert.fromFirestore(alertDoc);
    await AuditService.instance.logEvent(
      familyId: familyId,
      childId: alert.childId,
      childName: alert.childName,
      actorId: parentId,
      actorName: parentName,
      type: alert.isSos ? ActivityType.emergencySos : ActivityType.safetyCheckIn,
      title: alert.isSos ? 'Emergency SOS resolved' : 'Safety check-in resolved',
      description: '$parentName resolved an alert from ${alert.childName}.',
      metadata: {
        'alertId': alertId,
        'resolutionNotes': ?resolutionNotes,
      },
    );
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
  Future<bool> _sendEmergencyParentNotification({
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
      final notificationId = 'emergency_$alertId';
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notifData);
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('notifications')
          .doc(notificationId)
          .set(notifData);
      return true;
    } catch (e) {
      debugPrint('Error pushing emergency notification to Firestore: $e');
      return false;
    }
  }

  /// Cache alert locally for offline retry
  Future<void> _cacheOfflineAlert({
    required String familyId,
    required String alertId,
    required Map<String, dynamic> alertData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingSosCacheKey) ?? [];
    final envelope = {
      'familyId': familyId,
      'alertId': alertId,
      'alertData': _encodeOfflineValue(alertData),
    };
    if (list.any((item) {
      try {
        return jsonDecode(item)['alertId'] == alertId;
      } catch (_) {
        return false;
      }
    })) {
      return;
    }
    list.add(jsonEncode(envelope));
    await prefs.setStringList(_pendingSosCacheKey, list);
  }

  /// Flush cached offline alerts when connection returns
  Future<void> processPendingOfflineAlerts(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingSosCacheKey) ?? [];
    if (pending.isEmpty) return;

    final remaining = <String>[];
    for (final jsonString in pending) {
      try {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        final entryFamilyId = decoded['familyId'] as String? ?? familyId;
        if (entryFamilyId != familyId) {
          remaining.add(jsonString);
          continue;
        }

        final alertData = decoded.containsKey('alertData')
            ? Map<String, dynamic>.from(
                _decodeOfflineValue(decoded['alertData']) as Map,
              )
            : decoded;
        final alertId = decoded['alertId'] as String? ??
            _alertsCollection(familyId).doc().id;
        await _alertsCollection(familyId).doc(alertId).set(alertData);
        final isSos = AlertType.fromString(alertData['type'] as String?) ==
            AlertType.sos;
        final childId = alertData['childId'] as String? ?? '';
        final childName = alertData['childName'] as String? ?? 'Child';
        final message = alertData['message'] as String? ?? '';
        final location = alertData['address'] as String? ?? '';

        await AuditService.instance.logEvent(
          familyId: familyId,
          childId: childId,
          childName: childName,
          actorId: childId,
          actorName: childName,
          actorRole: 'child',
          type: isSos ? ActivityType.emergencySos : ActivityType.safetyCheckIn,
          title: isSos ? 'Emergency SOS sent' : 'Safety check-in sent',
          description: isSos
              ? '$childName sent an emergency SOS.'
              : '$childName sent a safety check-in.',
          metadata: {'alertId': alertId},
          eventId: 'emergency_$alertId',
        );

        final notificationWritten = await _sendEmergencyParentNotification(
          familyId: familyId,
          childId: childId,
          childName: childName,
          alertId: alertId,
          type: isSos
              ? NotificationType.emergencySos
              : NotificationType.safetyPing,
          location: location,
          lat: (alertData['latitude'] as num?)?.toDouble(),
          lng: (alertData['longitude'] as num?)?.toDouble(),
          message: message,
        );
        if (!notificationWritten) remaining.add(jsonString);
      } catch (e) {
        debugPrint('Could not retry a cached emergency alert: $e');
        remaining.add(jsonString);
      }
    }

    if (remaining.isEmpty) {
      await prefs.remove(_pendingSosCacheKey);
    } else {
      await prefs.setStringList(_pendingSosCacheKey, remaining);
    }
  }

  dynamic _encodeOfflineValue(dynamic value) {
    if (value is Timestamp) {
      return {'__timestampMillis': value.millisecondsSinceEpoch};
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _encodeOfflineValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_encodeOfflineValue).toList();
    }
    return value;
  }

  dynamic _decodeOfflineValue(dynamic value) {
    if (value is Map) {
      if (value.length == 1 && value['__timestampMillis'] is num) {
        return Timestamp.fromMillisecondsSinceEpoch(
          (value['__timestampMillis'] as num).toInt(),
        );
      }
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _decodeOfflineValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_decodeOfflineValue).toList();
    }
    return value;
  }
}
