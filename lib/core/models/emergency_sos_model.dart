import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertStatus {
  pending,
  acknowledged,
  resolved;

  String get displayName => switch (this) {
        AlertStatus.pending => 'Pending',
        AlertStatus.acknowledged => 'Acknowledged',
        AlertStatus.resolved => 'Resolved',
      };
}

enum AlertType {
  sos,
  checkinSafe,
  checkinCall,
  checkinPickup;

  String get displayName => switch (this) {
        AlertType.sos => 'Emergency SOS',
        AlertType.checkinSafe => "I'm Safe",
        AlertType.checkinCall => 'Please Call Me',
        AlertType.checkinPickup => 'Pick Me Up',
      };

  static AlertType fromString(String? type) {
    return switch ((type ?? '').toLowerCase()) {
      'checkin_safe' || 'safe' => AlertType.checkinSafe,
      'checkin_call' || 'call' => AlertType.checkinCall,
      'checkin_pickup' || 'pickup' => AlertType.checkinPickup,
      _ => AlertType.sos,
    };
  }

  String toDbString() => switch (this) {
        AlertType.sos => 'sos',
        AlertType.checkinSafe => 'checkin_safe',
        AlertType.checkinCall => 'checkin_call',
        AlertType.checkinPickup => 'checkin_pickup',
      };
}

class EmergencyAlert {
  final String id;
  final String familyId;
  final String childId;
  final String childName;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? address;
  final AlertStatus status;
  final AlertType type;
  final String? message;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  const EmergencyAlert({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.childName,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.address,
    this.status = AlertStatus.pending,
    this.type = AlertType.sos,
    this.message,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
  });

  bool get isSos => type == AlertType.sos;
  bool get isPending => status == AlertStatus.pending;
  bool get isAcknowledged => status == AlertStatus.acknowledged;
  bool get isResolved => status == AlertStatus.resolved;

  factory EmergencyAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    AlertStatus parseStatus(String? s) {
      return switch ((s ?? '').toLowerCase()) {
        'acknowledged' => AlertStatus.acknowledged,
        'resolved' => AlertStatus.resolved,
        _ => AlertStatus.pending,
      };
    }

    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    DateTime? parseOptional(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return EmergencyAlert(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      childName: data['childName'] as String? ?? 'Child',
      timestamp: parseTimestamp(data['timestamp'] ?? data['createdAt']),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      status: parseStatus(data['status'] as String?),
      type: AlertType.fromString(data['type'] as String?),
      message: data['message'] as String?,
      acknowledgedBy: data['acknowledgedBy'] as String?,
      acknowledgedAt: parseOptional(data['acknowledgedAt']),
      resolvedBy: data['resolvedBy'] as String?,
      resolvedAt: parseOptional(data['resolvedAt']),
      resolutionNotes: data['resolutionNotes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'childId': childId,
      'childName': childName,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(timestamp),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
      'status': status.name,
      'type': type.toDbString(),
      if (message != null) 'message': message,
      if (acknowledgedBy != null) 'acknowledgedBy': acknowledgedBy,
      if (acknowledgedAt != null) 'acknowledgedAt': Timestamp.fromDate(acknowledgedAt!),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
    };
  }

  EmergencyAlert copyWith({
    AlertStatus? status,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
  }) {
    return EmergencyAlert(
      id: id,
      familyId: familyId,
      childId: childId,
      childName: childName,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      address: address,
      status: status ?? this.status,
      type: type,
      message: message,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }
}

