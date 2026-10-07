/// Application route constants
/// Centralized route definitions for consistent navigation
class AppRoutes {
  // Onboarding and startup routes
  static const String splash = '/';
  static const String welcome = '/welcome';
  
  // Authentication routes
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role-selection';
  static const String authChoice = '/auth-choice';
  
  // Parent routes
  static const String parentHome = '/parent-home';
  static const String parentApps = '/parent-apps';
  static const String parentLocation = '/parent-location';
  static const String parentRequests = '/parent-requests';
  
  // Child routes  
  static const String childHome = '/child-home';
  static const String childPermissions = '/child-permissions';
  static const String childStatus = '/child-status';
  static const String childApps = '/child-apps';
  static const String joinFamily = '/join-family';
  static const String permissionOnboarding = '/permission-onboarding';
  static const String monitoringStatus = '/monitoring-status';
  
  // Family routes
  static const String familyPairing = '/family-pairing';
  static const String familyQrCode = '/family-qr-code';
  static const String familyJoin = '/family-join';
  static const String familySetup = '/family-setup';
  
  // Settings and other routes
  static const String settings = '/settings';
  static const String privacy = '/privacy';
  static const String help = '/help';
}