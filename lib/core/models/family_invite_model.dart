import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyInviteModel {
  final String id;
  final String familyId;
  final String inviteCode;
  final String parentName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedAt;

  FamilyInviteModel({
    required this.id,
    required this.familyId,
    required this.inviteCode,
    required this.parentName,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    this.isUsed = false,
    this.usedBy,
    this.usedAt,
  });

  /// Getter for 'code' (alias for inviteCode)
  String get code => inviteCode;

  /// Check if invite is valid (not used and not expired)
  bool get isValid => !isUsed && !isExpired && isActive;

  /// Check if invite is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory FamilyInviteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyInviteModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      parentName: data['parentName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? false,
      isUsed: data['isUsed'] ?? false,
      usedBy: data['usedBy'],
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'inviteCode': inviteCode,
      'parentName': parentName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
      'isUsed': isUsed,
      if (usedBy != null) 'usedBy': usedBy,
      if (usedAt != null) 'usedAt': Timestamp.fromDate(usedAt!),
    };
  }
}