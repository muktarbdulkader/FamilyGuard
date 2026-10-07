import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_model.dart';
import '../models/user_model.dart';
import '../models/family_invite_model.dart';
import '../constants/app_constants.dart';

/// Family service handling family operations
/// Manages family creation, invite codes, and member joining
class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new family with the given parent
  Future<FamilyModel> createFamily({
    required String parentId,
    required String familyName,
  }) async {
    try {
      // Create family document
      final familyRef = _firestore.collection(AppConstants.familiesCollection).doc();
      
      final family = FamilyModel(
        id: familyRef.id,
        name: familyName,
        createdBy: parentId,
        parentIds: [parentId],
        childIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await familyRef.set(family.toFirestore());

      // Update parent's familyId
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(parentId)
          .update({'familyId': familyRef.id});

      return family;
    } catch (e) {
      throw FamilyException('Failed to create family: ${e.toString()}');
    }
  }

  /// Generate a new invite code for family pairing
  Future<FamilyInviteModel> generateInviteCode({
    required String familyId,
    required String parentId,
  }) async {
    try {
      // Generate 6-digit code
      final code = _generateSixDigitCode();
      
      // Calculate expiration time
      final expiresAt = DateTime.now().add(
        const Duration(minutes: AppConstants.familyCodeExpirationMinutes),
      );

      final invite = FamilyInviteModel(
        id: code,
        familyId: familyId,
        parentId: parentId,
        inviteCode: code,
        parentName: 'Parent',
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        isActive: true,
      );

      // Store invite code
      await _firestore
          .collection('family_invites')
          .doc(code)
          .set(invite.toFirestore());

      return invite;
    } catch (e) {
      throw FamilyException('Failed to generate invite code: ${e.toString()}');
    }
  }

  /// Join family using invite code
  Future<void> joinFamily({
    required String inviteCode,
    required String childId,
  }) async {
    try {
      // Get invite document
      final inviteDoc = await _firestore
          .collection('family_invites')
          .doc(inviteCode)
          .get();

      if (!inviteDoc.exists) {
        throw FamilyException('Invalid invite code');
      }

      final invite = FamilyInviteModel.fromFirestore(inviteDoc);

      // Check if invite is valid
      if (!invite.isValid) {
        throw FamilyException(
          invite.isExpired ? 'Invite code has expired' : 'Invite code has already been used'
        );
      }

      // Get family document
      final familyDoc = await _firestore
          .collection(AppConstants.familiesCollection)
          .doc(invite.familyId)
          .get();

      if (!familyDoc.exists) {
        throw FamilyException('Family not found');
      }

      final family = FamilyModel.fromFirestore(familyDoc);

      // Check if child is already in a family
      final childDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        throw FamilyException('User not found');
      }

      final childUser = UserModel.fromFirestore(childDoc);
      if (childUser.hasFamily) {
        throw FamilyException('You are already part of a family');
      }

      // Use batch to update multiple documents atomically
      final batch = _firestore.batch();

      // Add child to family
      final currentChildIds = family.childIds;
      final updatedChildIds = currentChildIds.contains(childId)
          ? currentChildIds
          : [...currentChildIds, childId];

      batch.update(
        _firestore.collection(AppConstants.familiesCollection).doc(invite.familyId),
        {
          'childIds': updatedChildIds,
          'childrenIds': updatedChildIds,
          'updatedAt': Timestamp.now(),
        },
      );

      // Update child's familyId
      batch.update(
        _firestore.collection(AppConstants.usersCollection).doc(childId),
        {'familyId': invite.familyId},
      );

      // Mark invite as used
      batch.update(
        _firestore.collection('family_invites').doc(inviteCode),
        {
          'isUsed': true,
          'usedBy': childId,
        },
      );

      // Commit all changes
      await batch.commit();

    } catch (e) {
      if (e is FamilyException) {
        rethrow;
      }
      throw FamilyException('Failed to join family: ${e.toString()}');
    }
  }

  /// Get family data
  Future<FamilyModel?> getFamilyData(String familyId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.familiesCollection)
          .doc(familyId)
          .get();

      if (doc.exists) {
        return FamilyModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw FamilyException('Failed to get family data: ${e.toString()}');
    }
  }

  /// Get family data stream
  Stream<FamilyModel?> getFamilyDataStream(String familyId) {
    return _firestore
        .collection(AppConstants.familiesCollection)
        .doc(familyId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return FamilyModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Get family members (parent and children)
  Future<List<UserModel>> getFamilyMembers(String familyId) async {
    try {
      final family = await getFamilyData(familyId);
      if (family == null) {
        throw FamilyException('Family not found');
      }

      final members = <UserModel>[];

      // Get parent
      final parentDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(family.parentId)
          .get();
      
      if (parentDoc.exists) {
        members.add(UserModel.fromFirestore(parentDoc));
      }

      // Get children
      for (final childId in family.childrenIds) {
        final childDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(childId)
            .get();
        
        if (childDoc.exists) {
          members.add(UserModel.fromFirestore(childDoc));
        }
      }

      return members;
    } catch (e) {
      throw FamilyException('Failed to get family members: ${e.toString()}');
    }
  }

  /// Remove child from family
  Future<void> removeChildFromFamily({
    required String familyId,
    required String childId,
  }) async {
    try {
      final family = await getFamilyData(familyId);
      if (family == null) {
        throw FamilyException('Family not found');
      }

      // Use batch to update multiple documents atomically
      final batch = _firestore.batch();

      // Remove child from family
      final updatedChildrenIds = family.childrenIds.where((id) => id != childId).toList();
      batch.update(
        _firestore.collection(AppConstants.familiesCollection).doc(familyId),
        {
          'childrenIds': updatedChildrenIds,
          'updatedAt': Timestamp.now(),
        },
      );

      // Remove familyId from child
      batch.update(
        _firestore.collection(AppConstants.usersCollection).doc(childId),
        {'familyId': FieldValue.delete()},
      );

      // Commit changes
      await batch.commit();

    } catch (e) {
      throw FamilyException('Failed to remove child from family: ${e.toString()}');
    }
  }

  /// Delete family (parent only)
  Future<void> deleteFamily(String familyId) async {
    try {
      final family = await getFamilyData(familyId);
      if (family == null) {
        throw FamilyException('Family not found');
      }

      // Use batch to update multiple documents atomically
      final batch = _firestore.batch();

      // Remove familyId from all members
      final allMemberIds = [family.parentId, ...family.childrenIds];
      for (final memberId in allMemberIds) {
        batch.update(
          _firestore.collection(AppConstants.usersCollection).doc(memberId),
          {'familyId': FieldValue.delete()},
        );
      }

      // Delete family document
      batch.delete(
        _firestore.collection(AppConstants.familiesCollection).doc(familyId),
      );

      // Commit changes
      await batch.commit();

    } catch (e) {
      throw FamilyException('Failed to delete family: ${e.toString()}');
    }
  }

  /// Clean up expired invite codes
  Future<void> cleanupExpiredInvites() async {
    try {
      final expiredInvites = await _firestore
          .collection('family_invites')
          .where('expiresAt', isLessThan: Timestamp.now())
          .get();

      final batch = _firestore.batch();
      for (final doc in expiredInvites.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      // Don't throw error for cleanup failure
      // ignore: avoid_print
      print('Failed to cleanup expired invites: $e');
    }
  }

  /// Generate a 6-digit numeric code
  String _generateSixDigitCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Validate invite code format
  static bool isValidCodeFormat(String code) {
    return RegExp(r'^\d{6}$').hasMatch(code);
  }
}

/// Custom family exception class
class FamilyException implements Exception {
  final String message;

  FamilyException(this.message);

  @override
  String toString() => message;
}