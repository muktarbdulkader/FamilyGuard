import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/family/presentation/screens/parent_home_screen.dart';
import '../../features/family/presentation/screens/child_home_screen.dart';
import '../../features/family/presentation/screens/pairing/family_setup_screen.dart';
import '../../features/family/presentation/screens/pairing/join_family_screen.dart';
import '../../features/permissions/presentation/screens/permission_onboarding_screen.dart';
import '../../features/permissions/presentation/screens/monitoring_status_screen.dart';
import '../../features/apps/presentation/screens/child_apps_screen.dart';
import '../../features/apps/presentation/screens/parent_app_management_screen.dart';
import '../../features/location/presentation/screens/family_map_screen.dart';
import '../../features/parent/presentation/screens/parent_dashboard_screen.dart';
import '../../features/notifications/presentation/screens/parent_notifications_screen.dart';
import '../../features/family/presentation/screens/pairing/qr_code_screen.dart';
import '../constants/app_routes.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

/// Listenable that notifies GoRouter when auth state changes
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Router provider using GoRouter for navigation
/// Handles authentication-based routing and role-based navigation
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: true,
    
    // Route configuration
    routes: [
      // Splash and onboarding routes
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      
      // Authentication routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final selectedRole = extra?['role'] as UserRole?;
          return LoginScreen(
            initialTabIsSignUp: false,
            selectedRole: selectedRole,
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final selectedRole = extra?['role'] as UserRole?;
          return LoginScreen(
            initialTabIsSignUp: true,
            selectedRole: selectedRole,
          );
        },
      ),
      
      // Role selection route (after initial login/registration)
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
      
      // Child app management route
      GoRoute(
        path: AppRoutes.childApps,
        name: 'child-apps',
        builder: (context, state) => const ChildAppsScreen(),
      ),
      
      // Parent app management route
      GoRoute(
        path: '/parent-apps/:childId/:childName',
        name: 'parent-app-management',
        builder: (context, state) => ParentAppManagementScreen(
          familyId: state.pathParameters['familyId'] ?? '',
          childId: state.pathParameters['childId']!,
        ),
      ),

      // Parent location / live map route
      GoRoute(
        path: AppRoutes.parentLocation,
        name: 'parent-location',
        builder: (context, state) => const FamilyMapScreen(),
      ),

      // Parent requests & dashboard route
      GoRoute(
        path: AppRoutes.parentRequests,
        name: 'parent-requests',
        builder: (context, state) => const ParentDashboardScreen(),
      ),

      // Parent apps overview route
      GoRoute(
        path: AppRoutes.parentApps,
        name: 'parent-apps',
        builder: (context, state) => const ParentDashboardScreen(),
      ),

      // Family QR Code route
      GoRoute(
        path: AppRoutes.familyQrCode,
        name: 'family-qr-code',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return QRCodeScreen(
            familyId: extra?['familyId'] ?? '',
            familyName: extra?['familyName'] ?? 'My Family',
          );
        },
      ),

      // Family Pairing / Setup route
      GoRoute(
        path: AppRoutes.familyPairing,
        name: 'family-pairing',
        builder: (context, state) => const FamilySetupScreen(),
      ),

      // Join Family alias
      GoRoute(
        path: AppRoutes.joinFamily,
        name: 'join-family',
        builder: (context, state) => const JoinFamilyScreen(),
      ),

      // Notifications route
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const ParentNotificationsScreen(),
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
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;
      
      // If still loading auth state, don't redirect
      if (authState.isLoading) {
        return null;
      }
      
      // Allow splash and welcome screens for unauthenticated users
      final isOnboardingRoute = location == AppRoutes.splash || location == AppRoutes.welcome;
      final isAuthRoute = location == AppRoutes.login || location == AppRoutes.register;
      
      // Check if user is authenticated
      final isAuthenticated = authState.user != null;
      
      // If user is not authenticated, allow onboarding and auth routes
      if (!isAuthenticated) {
        return isOnboardingRoute || isAuthRoute ? null : AppRoutes.splash;
      }
      
      // User is authenticated, check their role
      final user = authState.user!;
      final userRole = user.role;
      
      // If user has no role and not on role selection, redirect there
      if (userRole == UserRole.none) {
        return location == AppRoutes.roleSelection ? null : AppRoutes.roleSelection;
      }
      
      // If user has role but on onboarding/login/register/role selection, redirect to appropriate home
      if (isOnboardingRoute || isAuthRoute || location == AppRoutes.roleSelection) {
        if (userRole == UserRole.parent) {
          return AppRoutes.parentHome;
        } else if (userRole == UserRole.child) {
          return AppRoutes.childHome;
        }
      }
      
      // Role-based access control
      if (userRole == UserRole.parent && _isChildRoute(location)) {
        return AppRoutes.parentHome;
      } else if (userRole == UserRole.child && _isParentRoute(location)) {
        return AppRoutes.childHome;
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

/// Check if a route is for child users
bool _isChildRoute(String location) {
  const childRoutes = [
    AppRoutes.childHome,
    AppRoutes.childPermissions,
    AppRoutes.childStatus,
    AppRoutes.childApps,
    AppRoutes.joinFamily,
    AppRoutes.permissionOnboarding,
    AppRoutes.monitoringStatus,
  ];
  
  return childRoutes.any((route) => location.startsWith(route));
}

/// Check if a route is for parent users
bool _isParentRoute(String location) {
  const parentRoutes = [
    AppRoutes.parentHome,
    AppRoutes.parentApps,
    AppRoutes.parentLocation,
    AppRoutes.parentRequests,
    AppRoutes.familySetup,
  ];
  
  return parentRoutes.any((route) => location.startsWith(route)) ||
         location.startsWith('/parent-apps/');
}