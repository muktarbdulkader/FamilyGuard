import 'package:cloud_firestore/cloud_firestore.dart';

/// User model representing authenticated users in the system
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? familyId;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.familyId,
  });

  /// Get user ID (alias for uid for compatibility)
  String get id => uid;

  /// Check if user belongs to a family
  bool get hasFamily => familyId != null;

  /// Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRole.fromString(data['role'] ?? ''),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      familyId: data['familyId'],
    );
  }

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      role: UserRole.fromString(json['role'] ?? ''),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      familyId: json['familyId'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (familyId != null) 'familyId': familyId,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (familyId != null) 'familyId': familyId,
    };
  }

  /// Copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? familyId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      familyId: familyId ?? this.familyId,
    );
  }

  /// Check if user has a valid role assigned
  bool get hasRole => role != UserRole.none;

  /// Check if user is a parent
  bool get isParent => role == UserRole.parent;

  /// Check if user is a child
  bool get isChild => role == UserRole.child;

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.role == role;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        role.hashCode;
  }
}

/// User role enumeration
enum UserRole {
  none(''),
  parent('parent'),
  child('child');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'parent':
        return UserRole.parent;
      case 'child':
        return UserRole.child;
      default:
        return UserRole.none;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.parent:
        return 'Parent';
      case UserRole.child:
        return 'Child';
      case UserRole.none:
        return 'No Role';
    }
  }

  @override
  String toString() => value;
}