import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Service for managing user data and operations
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user data stream by user ID
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Get user data by user ID (one-time fetch)
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user: $e');
      }
      return null;
    }
  }

  /// Get current user data stream
  Stream<UserModel?> getCurrentUserStream() {
    return _auth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser != null) {
        return getUserStream(firebaseUser.uid);
      } else {
        return Stream.value(null);
      }
    });
  }

  /// Create or update user profile
  Future<void> createOrUpdateUser({
    required String uid,
    required String email,
    required String displayName,
    UserRole? role,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);
      final existingUser = await userDoc.get();
      
      if (existingUser.exists) {
        // Update existing user
        await userDoc.update({
          'email': email,
          'displayName': displayName,
          if (role != null) 'role': role.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new user
        final newUser = UserModel(
          uid: uid,
          email: email,
          displayName: displayName,
          role: role ?? UserRole.none,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await userDoc.set(newUser.toFirestore());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating/updating user: $e');
      }
      rethrow;
    }
  }

  /// Update user role
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'role': role.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user role: $e');
      }
      rethrow;
    }
  }

  /// Delete user account and data
  Future<void> deleteUser(String userId) async {
    try {
      // Delete user document
      await _firestore
          .collection('users')
          .doc(userId)
          .delete();
      
      // Delete Firebase Auth user
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        await currentUser.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting user: $e');
      }
      rethrow;
    }
  }

  /// Check if user exists
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking user existence: $e');
      }
      return false;
    }
  }

  /// Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role.value)
          .get();
      
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting users by role: $e');
      }
      return [];
    }
  }

  /// Search users by display name or email
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      // Firestore doesn't support full-text search, so we do simple prefix matching
      final querySnapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: '${query}z')
          .limit(10)
          .get();
      
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching users: $e');
      }
      return [];
    }
  }

  /// Update user profile information
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? email,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) {
        updates['displayName'] = displayName;
      }
      
      if (email != null) {
        updates['email'] = email;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .update(updates);
      
      // Also update Firebase Auth profile if display name changed
      if (displayName != null) {
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.uid == userId) {
          await currentUser.updateDisplayName(displayName);
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile: $e');
      }
      rethrow;
    }
  }
}

extension _StreamExtensions<T> on Stream<T> {
  Stream<S> switchMap<S>(Stream<S> Function(T) mapper) {
    return map(mapper).switchLatest();
  }
}

extension _StreamUtils<T> on Stream<Stream<T>> {
  Stream<T> switchLatest() {
    return transform(StreamTransformer<Stream<T>, T>.fromHandlers(
      handleData: (Stream<T> innerStream, EventSink<T> sink) {
        StreamSubscription<T>? subscription;
        subscription = innerStream.listen(
          sink.add,
          onError: sink.addError,
          onDone: () {
            subscription?.cancel();
          },
        );
      },
    ));
  }
}