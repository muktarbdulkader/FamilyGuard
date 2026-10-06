import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/family/presentation/screens/parent_home_screen.dart';
import '../../features/family/presentation/screens/child_home_screen.dart';
import '../../features/family/presentation/screens/pairing/family_setup_screen.dart';
import '../../features/family/presentation/screens/pairing/join_family_screen.dart';
import '../../features/permissions/presentation/screens/permission_onboarding_screen.dart';
import '../../features/permissions/presentation/screens/monitoring_status_screen.dart';
import '../constants/app_routes.dart';
import 'auth_provider.dart';

/// Router provider using GoRouter for navigation
/// Handles authentication-based routing and role-based navigation
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    
    // Route configuration
    routes: [
      // Authentication routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Role selection route (after initial login)
      GoRoute(
        path: AppRoutes.roleSelection,
        name: 'role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      
      // Parent home route
      GoRoute(
        path: AppRoutes.parentHome,
        name: 'parent-home',
        builder: (context, state) => const ParentHomeScreen(),
      ),
      
      // Child home route
      GoRoute(
        path: AppRoutes.childHome,
        name: 'child-home', 
        builder: (context, state) => const ChildHomeScreen(),
      ),

      // Family pairing routes
      GoRoute(
        path: AppRoutes.familySetup,
        name: 'family-setup',
        builder: (context, state) => const FamilySetupScreen(),
      ),
      
      GoRoute(
        path: AppRoutes.familyJoin,
        name: 'family-join',
        builder: (context, state) => const JoinFamilyScreen(),
      ),

      // Permission setup routes
      GoRoute(
        path: AppRoutes.childPermissions,
        name: 'child-permissions',
        builder: (context, state) => const PermissionOnboardingScreen(),
      ),
      
      GoRoute(
        path: AppRoutes.childStatus,
        name: 'child-status',
        builder: (context, state) => const MonitoringStatusScreen(),
      ),
      
      // Error route for undefined routes
      GoRoute(
        path: '/error',
        name: 'error',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Page not found',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Error: ${state.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
    
    // Redirect logic based on authentication state
    redirect: (context, state) async {
      // Get auth state synchronously first
      final authState = ref.read(authStateProvider);
      final location = state.matchedLocation;
      
      // If still loading auth state, don't redirect
      if (authState.isLoading) {
        return null;
      }
      
      final isAuthenticated = authState.hasValue && authState.value != null;
      
      // If user is not authenticated, redirect to login
      if (!isAuthenticated) {
        return location == AppRoutes.login ? null : AppRoutes.login;
      }
      
      // User is authenticated, check their role
      try {
        final userRole = await ref.read(userRoleFutureProvider.future);
        
        // If user has no role and not on role selection, redirect there
        if (userRole == null || userRole.isEmpty) {
          return location == AppRoutes.roleSelection ? null : AppRoutes.roleSelection;
        }
        
        // If user has role but on login/role selection, redirect to home
        if (location == AppRoutes.login || location == AppRoutes.roleSelection) {
          if (userRole == 'parent') {
            return AppRoutes.parentHome;
          } else if (userRole == 'child') {
            return AppRoutes.childHome;
          }
        }
        
        // Check if user is trying to access wrong role's pages
        if (userRole == 'parent' && location.startsWith('/child')) {
          return AppRoutes.parentHome;
        } else if (userRole == 'child' && location.startsWith('/parent')) {
          return AppRoutes.childHome;
        }
        
      } catch (e) {
        // If error getting role, redirect to role selection
        return AppRoutes.roleSelection;
      }
      
      return null; // No redirect needed
    },
    
    // Error handler for route errors
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Route Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Route Error',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Error: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    ),
  );
});