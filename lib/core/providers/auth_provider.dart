import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Firebase Auth instance provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Auth state stream provider
/// Listens to Firebase Auth state changes (login/logout)
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// Current user provider  
/// Returns the currently authenticated user or null
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

/// Current user data provider
/// Returns UserModel from Firestore for the current user
final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(null);
  }
  
  final authService = ref.watch(authServiceProvider);
  return authService.getUserDataStream(user.uid);
});

/// User role provider
/// Returns the role of the current user ('parent', 'child', or null)
final userRoleProvider = Provider<String?>((ref) {
  final userData = ref.watch(currentUserDataProvider);
  return userData.when(
    data: (userModel) => userModel?.role.isEmpty == true ? null : userModel?.role,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

/// User role future provider for async access
final userRoleFutureProvider = FutureProvider<String?>((ref) async {
  final userData = await ref.watch(currentUserDataProvider.future);
  return userData?.role.isEmpty == true ? null : userData?.role;
});