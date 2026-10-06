/// Application-wide constants
class AppConstants {
  // App Information
  static const String appName = 'Family Guardian';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String familiesCollection = 'families';
  static const String childrenSubcollection = 'children';
  static const String appsSubcollection = 'apps';
  static const String requestsSubcollection = 'requests';
  static const String locationsSubcollection = 'locations';
  
  // User Roles
  static const String parentRole = 'parent';
  static const String childRole = 'child';
  
  // App Rules
  static const String allowedRule = 'allowed';
  static const String blockedRule = 'blocked';
  static const String limitedRule = 'limited';
  static const String askRule = 'ask';
  
  // Request Status
  static const String pendingStatus = 'pending';
  static const String approvedStatus = 'approved';
  static const String deniedStatus = 'denied';
  
  // Time Constants
  static const int familyCodeExpirationMinutes = 10;
  static const int locationUpdateIntervalMinutes = 5;
  
  // Notification Constants
  static const String monitoringNotificationId = 'monitoring_active';
  static const String requestNotificationChannel = 'request_notifications';
  static const String locationNotificationChannel = 'location_notifications';
}