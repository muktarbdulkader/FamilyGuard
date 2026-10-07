/// Application constants for branding and configuration
class AppConstants {
  // App Branding
  static const String appName = 'FamilyGuard';
  static const String appTagline = 'Safe. Connected. Together.';
  static const String appDescription = 'A safer and smarter way for parents and children to stay connected.';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String familiesCollection = 'families';
  static const String rulesCollection = 'rules';
  static const String notificationsCollection = 'notifications';
  static const String childrenSubcollection = 'children';
  static const String appsSubcollection = 'apps';
  
  // Family Management
  static const int familyCodeExpirationMinutes = 15;
  static const int maxChildrenPerFamily = 10;
  
  // Role-based constants
  static const String parentRole = 'parent';
  static const String childRole = 'child';
  
  // App Settings
  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double buttonHeight = 56.0;
  
  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
}