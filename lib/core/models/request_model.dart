import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for app access requests from child to parent
class AppRequest {
  final String id;
  final String familyId;
  final String childId;
  final String packageName;
  final String appName;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int? grantedMinutes;
  final String? decidedBy; // Parent user ID
  final DateTime? decidedAt;
  final String? deviceInfo;
  final String requestNonce; // Prevent replay attacks

  const AppRequest({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.packageName,
    required this.appName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.grantedMinutes,
    this.decidedBy,
    this.decidedAt,
    this.deviceInfo,
    required this.requestNonce,
  });

  /// Create from Firestore document
  factory AppRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AppRequest(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      childId: data['childId'] ?? '',
      packageName: data['packageName'] ?? '',
      appName: data['appName'] ?? '',
      status: RequestStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => RequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      grantedMinutes: data['grantedMinutes'] as int?,
      decidedBy: data['decidedBy'] as String?,
      decidedAt: data['decidedAt'] != null 
          ? (data['decidedAt'] as Timestamp).toDate()
          : null,
      deviceInfo: data['deviceInfo'] as String?,
      requestNonce: data['requestNonce'] ?? '',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'childId': childId,
      'packageName': packageName,
      'appName': appName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'grantedMinutes': grantedMinutes,
      'decidedBy': decidedBy,
      'decidedAt': decidedAt != null ? Timestamp.fromDate(decidedAt!) : null,
      'deviceInfo': deviceInfo,
      'requestNonce': requestNonce,
    };
  }

  /// Create copy with updated fields
  AppRequest copyWith({
    String? id,
    String? familyId,
    String? childId,
    String? packageName,
    String? appName,
    RequestStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? grantedMinutes,
    String? decidedBy,
    DateTime? decidedAt,
    String? deviceInfo,
    String? requestNonce,
  }) {
    return AppRequest(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      childId: childId ?? this.childId,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      grantedMinutes: grantedMinutes ?? this.grantedMinutes,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedAt: decidedAt ?? this.decidedAt,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      requestNonce: requestNonce ?? this.requestNonce,
    );
  }

  /// Check if request is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if request is still pending
  bool get isPending => status == RequestStatus.pending && !isExpired;

  /// Check if request was approved
  bool get isApproved => status == RequestStatus.approved;

  /// Check if request was denied
  bool get isDenied => status == RequestStatus.denied;

  /// Get expiry date for granted access (if approved)
  DateTime? get accessExpiresAt {
    if (!isApproved || grantedMinutes == null || decidedAt == null) {
      return null;
    }
    return decidedAt!.add(Duration(minutes: grantedMinutes!));
  }

  /// Check if granted access is still valid
  bool get isAccessValid {
    final expiryDate = accessExpiresAt;
    return expiryDate != null && DateTime.now().isBefore(expiryDate);
  }

  /// Get formatted time remaining for access
  String get timeRemainingText {
    final expiryDate = accessExpiresAt;
    if (expiryDate == null) return 'No access granted';
    
    final remaining = expiryDate.difference(DateTime.now());
    if (remaining.isNegative) return 'Access expired';
    
    if (remaining.inHours > 0) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      return '${hours}h ${minutes}m remaining';
    } else {
      return '${remaining.inMinutes}m remaining';
    }
  }
}

/// Request status enum
enum RequestStatus {
  pending,
  approved,
  denied,
  expired,
}

/// Model for temporary app permission created after approval
class TemporaryPermission {
  final String packageName;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final String grantedBy; // Parent user ID
  final String requestId; // Link to original request
  final String authToken; // Verification token from server

  const TemporaryPermission({
    required this.packageName,
    required this.grantedAt,
    required this.expiresAt,
    required this.grantedBy,
    required this.requestId,
    required this.authToken,
  });

  factory TemporaryPermission.fromMap(Map<String, dynamic> map) {
    return TemporaryPermission(
      packageName: map['packageName'] ?? '',
      grantedAt: DateTime.parse(map['grantedAt']),
      expiresAt: DateTime.parse(map['expiresAt']),
      grantedBy: map['grantedBy'] ?? '',
      requestId: map['requestId'] ?? '',
      authToken: map['authToken'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'grantedBy': grantedBy,
      'requestId': requestId,
      'authToken': authToken,
    };
  }

  /// Check if permission is still valid
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Check if permission is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get minutes remaining
  int get minutesRemaining {
    if (isExpired) return 0;
    return expiresAt.difference(DateTime.now()).inMinutes;
  }
}

/// Predefined approval options for parents
enum ApprovalDuration {
  fifteenMinutes(15, '15 minutes'),
  thirtyMinutes(30, '30 minutes'),
  oneHour(60, '1 hour'),
  twoHours(120, '2 hours'),
  restOfDay(480, 'Rest of day'); // 8 hours as max

  const ApprovalDuration(this.minutes, this.displayText);
  
  final int minutes;
  final String displayText;
}