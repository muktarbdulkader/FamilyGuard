/// Application route constants
/// Centralized route definitions for consistent navigation
class AppRoutes {
  // Authentication routes
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role-selection';
  
  // Parent routes
  static const String parentHome = '/parent-home';
  static const String parentApps = '/parent-apps';
  static const String parentLocation = '/parent-location';
  static const String parentRequests = '/parent-requests';
  
  // Child routes  
  static const String childHome = '/child-home';
  static const String childPermissions = '/child-permissions';
  static const String childStatus = '/child-status';
  
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