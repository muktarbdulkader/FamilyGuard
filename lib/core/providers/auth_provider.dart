import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Authentication service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Firebase Auth state stream provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.authStateChanges;
});

/// Current Firebase user provider
final currentFirebaseUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Current user data provider (from Firestore)
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  
  if (firebaseUser == null) {
    return null;
  }

  final authService = ref.read(authServiceProvider);
  return await authService.getUserData(firebaseUser.uid);
});

/// Authentication state notifier for managing auth operations
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

/// Alias for authNotifierProvider
final authProvider = authNotifierProvider;

/// User role provider that gets role from Firestore (server-side truth)
final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  final userData = await ref.watch(currentUserProvider.future);
  return userData?.role;
});

/// Authentication state class
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserModel? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserModel? user,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState());

  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _authService.registerWithEmailAndPassword(
      email: email,
      password: password,
      displayName: displayName,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        user: result.data,
        clearError: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Sign in user
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        user: result.data,
        clearError: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    await _authService.signOut();
    
    state = state.copyWith(
      isLoading: false,
      clearUser: true,
      clearError: true,
    );
  }

  /// Update user role
  Future<bool> updateRole(UserRole role) async {
    if (state.user == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _authService.updateUserRole(
      uid: state.user!.uid,
      role: role,
    );

    if (result.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        user: result.data,
        clearError: true,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _authService.resetPassword(email);

    state = state.copyWith(isLoading: false);

    if (result.isSuccess) {
      state = state.copyWith(clearError: true);
      return true;
    } else {
      state = state.copyWith(errorMessage: result.errorMessage);
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Refresh user data
  Future<void> refreshUserData() async {
    if (state.user == null) return;

    final userData = await _authService.getUserData(state.user!.uid);
    if (userData != null) {
      state = state.copyWith(user: userData);
    }
  }
}