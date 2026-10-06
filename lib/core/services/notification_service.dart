import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/request_model.dart';
import '../services/request_service.dart';

/// Service for handling FCM notifications and local notifications
class NotificationService {
  static const String _channelId = 'app_requests';
  static const String _channelName = 'App Requests';
  static const String _channelDescription = 'Notifications for app permission requests';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  StreamController<RemoteMessage>? _messageController;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _backgroundMessageSubscription;
  
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  /// Stream of notification messages
  Stream<RemoteMessage> get messageStream {
    _messageController ??= StreamController<RemoteMessage>.broadcast();
    return _messageController!.stream;
  }

  /// Initialize notification service
  Future<void> initialize() async {
    // Request notification permissions
    await _requestPermissions();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Set up FCM
    await _setupFCM();
    
    // Listen for messages
    _setupMessageListeners();
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Request FCM permissions
    final messagingSettings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('FCM permission status: ${messagingSettings.authorizationStatus}');

    // Request local notification permissions on Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Setup FCM configuration
  Future<void> _setupFCM() async {
    // Configure FCM for foreground notifications
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and store FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      // TODO: Store token in user profile
      await _updateFCMToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_updateFCMToken);
  }

  /// Setup message listeners
  void _setupMessageListeners() {
    // Foreground messages
    _messageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Background message tap
    _backgroundMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    
    // Handle initial message if app was opened from notification
    _handleInitialMessage();
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.messageId}');
    
    // Add to stream
    _messageController?.add(message);
    
    // Show local notification
    _showLocalNotification(message);
    
    // Handle specific message types
    _processMessage(message);
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('Background message tap: ${message.messageId}');
    
    // Add to stream
    _messageController?.add(message);
    
    // Navigate to appropriate screen
    _handleMessageNavigation(message);
  }

  /// Handle initial message (app opened from notification)
  void _handleInitialMessage() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('Initial message: ${message.messageId}');
        _messageController?.add(message);
        _handleMessageNavigation(message);
      }
    });
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF2196F3),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: _createNotificationPayload(message),
    );
  }

  /// Process message based on type
  void _processMessage(RemoteMessage message) {
    final messageType = message.data['type'];
    
    switch (messageType) {
      case 'app_request':
        _handleAppRequestMessage(message);
        break;
      case 'request_approved':
        _handleRequestApprovedMessage(message);
        break;
      case 'request_denied':
        _handleRequestDeniedMessage(message);
        break;
      default:
        print('Unknown message type: $messageType');
    }
  }

  /// Handle app request notification (parent receives)
  void _handleAppRequestMessage(RemoteMessage message) {
    final data = message.data;
    print('New app request: ${data['appName']} from child ${data['childId']}');
    
    // Could trigger local actions like updating request list
    // The UI will automatically update through Firestore listeners
  }

  /// Handle request approved notification (child receives)
  void _handleRequestApprovedMessage(RemoteMessage message) {
    final data = message.data;
    final requestId = data['requestId'];
    final grantedMinutes = int.tryParse(data['grantedMinutes'] ?? '0') ?? 0;
    final authToken = data['authToken'];
    
    print('Request approved: $requestId for $grantedMinutes minutes');
    
    // Create temporary permission locally
    _createLocalPermission(data, grantedMinutes, authToken);
  }

  /// Handle request denied notification (child receives)
  void _handleRequestDeniedMessage(RemoteMessage message) {
    final data = message.data;
    final requestId = data['requestId'];
    
    print('Request denied: $requestId');
    
    // Could trigger UI update or show denial message
  }

  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Parse payload and navigate to appropriate screen
      print('Notification tapped with payload: $payload');
      _handleNotificationNavigation(payload);
    }
  }

  /// Handle message navigation
  void _handleMessageNavigation(RemoteMessage message) {
    final messageType = message.data['type'];
    
    switch (messageType) {
      case 'app_request':
        // Navigate to parent approval screen
        _navigateToApprovalScreen(message.data);
        break;
      case 'request_approved':
        // Navigate to child app or show success
        _navigateToChildApp(message.data);
        break;
      case 'request_denied':
        // Show denial message
        _showDenialMessage(message.data);
        break;
    }
  }

  /// Handle notification navigation from payload
  void _handleNotificationNavigation(String payload) {
    // Parse JSON payload and navigate accordingly
    try {
      // Implement navigation based on payload
      print('Navigating from payload: $payload');
    } catch (e) {
      print('Error parsing notification payload: $e');
    }
  }

  /// Create local permission from approved request
  Future<void> _createLocalPermission(
    Map<String, dynamic> data,
    int grantedMinutes,
    String authToken,
  ) async {
    try {
      final permission = TemporaryPermission(
        packageName: data['packageName'] ?? '',
        grantedAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(minutes: grantedMinutes)),
        grantedBy: data['parentId'] ?? '',
        requestId: data['requestId'] ?? '',
        authToken: authToken,
      );

      // Store permission locally for enforcement
      // This would integrate with the native monitoring service
      print('Created local permission: ${permission.toMap()}');
      
    } catch (e) {
      print('Error creating local permission: $e');
    }
  }

  /// Navigate to approval screen
  void _navigateToApprovalScreen(Map<String, dynamic> data) {
    // This would be implemented by the app's navigation system
    print('Navigate to approval for request: ${data['requestId']}');
  }

  /// Navigate to child app
  void _navigateToChildApp(Map<String, dynamic> data) {
    // This would launch the approved app or show success message
    print('Navigate to approved app: ${data['packageName']}');
  }

  /// Show denial message
  void _showDenialMessage(Map<String, dynamic> data) {
    // This would show a denial dialog or message
    print('Show denial for request: ${data['requestId']}');
  }

  /// Create notification payload
  String _createNotificationPayload(RemoteMessage message) {
    // Create JSON string with message data for handling taps
    return message.data.toString();
  }

  /// Update FCM token in user profile
  Future<void> _updateFCMToken(String token) async {
    try {
      // TODO: Update user document with FCM token
      print('Updated FCM token: $token');
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  /// Send test notification (for development)
  Future<void> sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Test Notification',
      'This is a test notification from Family Guardian',
      details,
    );
  }

  /// Clean up resources
  void dispose() {
    _messageSubscription?.cancel();
    _backgroundMessageSubscription?.cancel();
    _messageController?.close();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
  
  // Handle background message processing
  // Note: Limited functionality available in background
  
  final messageType = message.data['type'];
  
  switch (messageType) {
    case 'app_request':
      // Could increment badge count or store for later
      break;
    case 'request_approved':
      // Could create local permission for immediate enforcement
      break;
    case 'request_denied':
      // Could update local state
      break;
  }
}