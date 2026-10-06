import 'package:cloud_firestore/cloud_firestore.dart';

/// User model representing a user in the family control system
class UserModel {
  final String uid;
  final String email;
  final String role; // 'parent' or 'child'
  final String? familyId;
  final String? displayName;
  final DateTime createdAt;
  final DateTime? lastSeen;

  const UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.familyId,
    this.displayName,
    required this.createdAt,
    this.lastSeen,
  });

  /// Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      familyId: data['familyId'],
      displayName: data['displayName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
    );
  }

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      familyId: json['familyId'],
      displayName: json['displayName'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role,
      'familyId': familyId,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'familyId': familyId,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  /// Copy UserModel with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? familyId,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      familyId: familyId ?? this.familyId,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Check if user is a parent
  bool get isParent => role == 'parent';

  /// Check if user is a child
  bool get isChild => role == 'child';

  /// Check if user is part of a family
  bool get hasFamily => familyId != null && familyId!.isNotEmpty;

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, role: $role, familyId: $familyId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.role == role &&
        other.familyId == familyId;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        role.hashCode ^
        familyId.hashCode;
  }
}