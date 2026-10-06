import 'package:cloud_firestore/cloud_firestore.dart';

/// Family model representing a family group in the system
class FamilyModel {
  final String id;
  final String name;
  final String parentId;
  final List<String> childrenIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FamilyModel({
    required this.id,
    required this.name,
    required this.parentId,
    required this.childrenIds,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create FamilyModel from Firestore document
  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyModel(
      id: doc.id,
      name: data['name'] ?? '',
      parentId: data['parentId'] ?? '',
      childrenIds: List<String>.from(data['childrenIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert FamilyModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'parentId': parentId,
      'childrenIds': childrenIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Copy FamilyModel with updated fields
  FamilyModel copyWith({
    String? id,
    String? name,
    String? parentId,
    List<String>? childrenIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      childrenIds: childrenIds ?? this.childrenIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'FamilyModel(id: $id, name: $name, parentId: $parentId, children: ${childrenIds.length})';
  }
}

/// Family invite code model for temporary pairing codes
class FamilyInviteModel {
  final String code;
  final String familyId;
  final String parentId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String? usedBy;

  const FamilyInviteModel({
    required this.code,
    required this.familyId,
    required this.parentId,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
    this.usedBy,
  });

  /// Create FamilyInviteModel from Firestore document
  factory FamilyInviteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyInviteModel(
      code: doc.id,
      familyId: data['familyId'] ?? '',
      parentId: data['parentId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isUsed: data['isUsed'] ?? false,
      usedBy: data['usedBy'],
    );
  }

  /// Convert FamilyInviteModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'parentId': parentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isUsed': isUsed,
      'usedBy': usedBy,
    };
  }

  /// Check if invite code is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if invite code is valid (not used and not expired)
  bool get isValid => !isUsed && !isExpired;

  @override
  String toString() {
    return 'FamilyInviteModel(code: $code, familyId: $familyId, valid: $isValid)';
  }
}