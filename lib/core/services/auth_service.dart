import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';

/// Authentication service handling Firebase Auth operations
/// Manages user registration, login, logout, and role assignment
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register new user with email and password
  Future<User?> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Update display name if provided
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }

        // Create user document in Firestore (no role assigned yet)
        await _createUserDocument(user, displayName);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException._fromFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last seen timestamp
      if (credential.user != null) {
        await _updateLastSeen(credential.user!.uid);
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException._fromFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(User user, String? displayName) async {
    final userDoc = _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid);

    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      role: '', // Role will be set later
      displayName: displayName,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );

    await userDoc.set(userModel.toFirestore());
  }

  /// Update user's last seen timestamp
  Future<void> _updateLastSeen(String uid) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'lastSeen': Timestamp.now(),
      });
    } catch (e) {
      // Don't throw error for last seen update failure
      // ignore: avoid_print
      print('Failed to update last seen: $e');
    }
  }

  /// Set user role (parent or child)
  Future<void> setUserRole(String uid, String role) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'role': role,
      });
    } catch (e) {
      throw AuthException('Failed to set user role: ${e.toString()}');
    }
  }

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw AuthException('Failed to get user data: ${e.toString()}');
    }
  }

  /// Get user data stream
  Stream<UserModel?> getUserDataStream(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException._fromFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('Failed to send reset email: ${e.toString()}');
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user document from Firestore
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .delete();

        // Delete Firebase Auth account
        await user.delete();
      }
    } catch (e) {
      throw AuthException('Failed to delete account: ${e.toString()}');
    }
  }
}

/// Custom authentication exception class
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, [this.code]);

  factory AuthException._fromFirebaseAuthException(FirebaseAuthException e) {
    String message;
    
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found with this email address.';
        break;
      case 'wrong-password':
        message = 'Incorrect password.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email.';
        break;
      case 'weak-password':
        message = 'Password is too weak. Please choose a stronger password.';
        break;
      case 'invalid-email':
        message = 'Please enter a valid email address.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection.';
        break;
      default:
        message = e.message ?? 'Authentication failed.';
    }

    return AuthException(message, e.code);
  }

  @override
  String toString() => message;
}