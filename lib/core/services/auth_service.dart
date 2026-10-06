import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Production Firebase Authentication service
/// Handles all authentication operations with proper error handling
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current Firebase user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  /// Register new user with email and password
  Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Validate input
      if (email.trim().isEmpty) {
        return AuthResult.failure('Email cannot be empty');
      }
      if (password.length < 6) {
        return AuthResult.failure('Password must be at least 6 characters');
      }
      if (displayName.trim().isEmpty) {
        return AuthResult.failure('Display name cannot be empty');
      }

      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Registration failed - no user created');
      }

      // Update Firebase Auth display name
      await user.updateDisplayName(displayName.trim());
      await user.reload();

      // Create user document in Firestore (without role)
      final now = DateTime.now();
      final userData = UserModel(
        uid: user.uid,
        email: email.trim().toLowerCase(),
        displayName: displayName.trim(),
        role: UserRole.none, // Role will be set later in role selection
        createdAt: now,
        updatedAt: now,
      );

      await _createUserDocument(userData);

      return AuthResult.success(userData);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Validate input
      if (email.trim().isEmpty) {
        return AuthResult.failure('Email cannot be empty');
      }
      if (password.isEmpty) {
        return AuthResult.failure('Password cannot be empty');
      }

      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Sign in failed - no user found');
      }

      // Get user data from Firestore
      final userData = await getUserData(user.uid);
      if (userData == null) {
        return AuthResult.failure('User profile not found');
      }

      return AuthResult.success(userData);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // Log error but don't throw - sign out should always succeed locally
      print('Sign out error: $e');
    }
  }

  /// Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (!doc.exists) {
        return null;
      }

      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Update user role (used during role selection)
  Future<AuthResult> updateUserRole({
    required String uid,
    required UserRole role,
  }) async {
    try {
      if (role == UserRole.none) {
        return AuthResult.failure('Please select a valid role');
      }

      // Update user document with role
      await _firestore.collection('users').doc(uid).update({
        'role': role.value,
        'updatedAt': Timestamp.now(),
      });

      // Get updated user data
      final userData = await getUserData(uid);
      if (userData == null) {
        return AuthResult.failure('Failed to retrieve updated user data');
      }

      return AuthResult.success(userData);
    } catch (e) {
      return AuthResult.failure('Failed to update role: ${e.toString()}');
    }
  }

  /// Update user profile
  Future<AuthResult> updateUserProfile({
    required String uid,
    String? displayName,
    String? email,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (displayName != null && displayName.trim().isNotEmpty) {
        updates['displayName'] = displayName.trim();
        
        // Also update Firebase Auth display name
        await _auth.currentUser?.updateDisplayName(displayName.trim());
      }

      if (email != null && email.trim().isNotEmpty) {
        updates['email'] = email.trim().toLowerCase();
        
        // Also update Firebase Auth email
        await _auth.currentUser?.verifyBeforeUpdateEmail(email.trim());
      }

      // Update Firestore document
      await _firestore.collection('users').doc(uid).update(updates);

      // Get updated user data
      final userData = await getUserData(uid);
      if (userData == null) {
        return AuthResult.failure('Failed to retrieve updated user data');
      }

      return AuthResult.success(userData);
    } catch (e) {
      return AuthResult.failure('Failed to update profile: ${e.toString()}');
    }
  }

  /// Reset password
  Future<AuthResult<void>> resetPassword(String email) async {
    try {
      if (email.trim().isEmpty) {
        return AuthResult.failure('Email cannot be empty');
      }

      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to send reset email: ${e.toString()}');
    }
  }

  /// Delete user account
  Future<AuthResult<void>> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user signed in');
      }

      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete Firebase Auth user
      await user.delete();

      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to delete account: ${e.toString()}');
    }
  }

  /// Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
      return methods.isNotEmpty;
    } catch (e) {
      // If we can't check, assume it's not registered to allow registration attempt
      return false;
    }
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(UserModel userData) async {
    await _firestore.collection('users').doc(userData.uid).set(userData.toFirestore());
  }

  /// Convert FirebaseAuthException to user-friendly error message
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not allowed.';
      case 'invalid-credential':
        return 'The credentials provided are invalid.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to perform this action.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}

/// Result wrapper for authentication operations
class AuthResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;

  const AuthResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
  });

  factory AuthResult.success(T data) {
    return AuthResult._(isSuccess: true, data: data);
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(isSuccess: false, errorMessage: message);
  }

  bool get isFailure => !isSuccess;
}