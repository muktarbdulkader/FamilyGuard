import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _isInitialized = false;

  // Notification channels
  static const String _urgentChannelId = 'urgent_notifications';
  static const String _highChannelId = 'high_notifications';
  static const String _normalChannelId = 'normal_notifications';
  static const String _lowChannelId = 'low_notifications';

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initializeLocalNotifications();
    await _requestPermissions();
    await _setupMessageHandlers();
    await _registerFCMToken();
    
    _isInitialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    const androidInitialization = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitialization = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidInitialization,
      iOS: iosInitialization,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    const urgentChannel = AndroidNotificationChannel(
      _urgentChannelId,
      'Urgent Notifications',
      description: 'Critical security and monitoring alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const highChannel = AndroidNotificationChannel(
      _highChannelId,
      'High Priority Notifications',
      description: 'App requests and important alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const normalChannel = AndroidNotificationChannel(
      _normalChannelId,
      'Normal Notifications',
      description: 'General notifications and updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
    );

    const lowChannel = AndroidNotificationChannel(
      _lowChannelId,
      'Low Priority Notifications',
      description: 'Status updates and informational notices',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
    );

    final plugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (plugin != null) {
      await plugin.createNotificationChannel(urgentChannel);
      await plugin.createNotificationChannel(highChannel);
      await plugin.createNotificationChannel(normalChannel);
      await plugin.createNotificationChannel(lowChannel);
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('FCM Permission status: ${settings.authorizationStatus}');
    }

    // Request local notification permissions for iOS
    if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> _setupMessageHandlers() async {
    // Handle messages when app is in foreground
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Handle messages when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Handle token refresh
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> _registerFCMToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMToken(user.uid, token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error registering FCM token: $e');
      }
    }
  }

  Future<void> _saveFCMToken(String userId, String token) async {
    try {
      final tokenDoc = _firestore.collection('fcm_tokens').doc(token);
      
      await tokenDoc.set(FCMToken(
        userId: userId,
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        deviceId: await _getDeviceId(),
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      ).toFirestore());

      // Clean up old tokens for this user/device
      await _cleanupOldTokens(userId, token);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    }
  }

  Future<String?> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        deviceId = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('device_id', deviceId);
      }
      
      return deviceId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _cleanupOldTokens(String userId, String currentToken) async {
    try {
      final oldTokens = await _firestore
          .collection('fcm_tokens')
          .where('userId', isEqualTo: userId)
          .where('token', isNotEqualTo: currentToken)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldTokens.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldTokens.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old tokens: $e');
      }
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _saveFCMToken(user.uid, token);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      final priority = _getPriorityFromData(message.data);
      final channelId = _getChannelForPriority(priority);
      
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _getChannelName(channelId),
            channelDescription: _getChannelDescription(channelId),
            importance: _getImportanceForPriority(priority),
            priority: _getPriorityForPriority(priority),
            icon: android?.smallIcon,
            playSound: priority != NotificationPriority.low,
            enableVibration: priority == NotificationPriority.urgent || 
                           priority == NotificationPriority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    final data = message.data;
    _navigateFromNotification(data);
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromNotification(data);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final familyId = data['familyId'];
    final childId = data['childId'];
    final requestId = data['requestId'];

    // Navigation logic based on notification type
    switch (type) {
      case 'app_request':
        if (requestId != null && familyId != null && childId != null) {
          // Navigate to request approval screen
          // GoRouter.of(context).go('/parent/requests/$requestId');
        }
        break;
      case 'new_app_detected':
        if (familyId != null && childId != null) {
          // Navigate to app management screen
          // GoRouter.of(context).go('/parent/apps?childId=$childId');
        }
        break;
      case 'daily_limit_reached':
        if (familyId != null && childId != null) {
          // Navigate to usage screen
          // GoRouter.of(context).go('/parent/usage?childId=$childId');
        }
        break;
      default:
        // Navigate to general parent dashboard
        // GoRouter.of(context).go('/parent');
        break;
    }
  }

  // Notification creation methods for different event types
  Future<void> sendAppRequestNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String appName,
    required String packageName,
    required int requestedMinutes,
    required String requestId,
  }) async {
    await _createAndSendNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      type: NotificationType.appRequest,
      data: {
        'appName': appName,
        'packageName': packageName,
        'requestedMinutes': requestedMinutes,
        'requestId': requestId,
      },
    );
  }

  Future<void> sendNewAppDetectedNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String appName,
    required String packageName,
  }) async {
    await _createAndSendNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      type: NotificationType.newAppDetected,
      data: {
        'appName': appName,
        'packageName': packageName,
      },
    );
  }

  Future<void> sendDailyLimitReachedNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String appName,
    required String packageName,
    required int dailyLimitMinutes,
  }) async {
    await _createAndSendNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      type: NotificationType.dailyLimitReached,
      data: {
        'appName': appName,
        'packageName': packageName,
        'dailyLimitMinutes': dailyLimitMinutes,
      },
    );
  }

  Future<void> sendDeviceStatusNotification({
    required String familyId,
    required String childId,
    required String childName,
    required bool isOnline,
  }) async {
    await _createAndSendNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      type: isOnline ? NotificationType.deviceOnline : NotificationType.deviceOffline,
      data: {
        'isOnline': isOnline,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> sendPermissionDisabledNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String permission,
  }) async {
    await _createAndSendNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      type: NotificationType.permissionDisabled,
      data: {
        'permission': permission,
      },
    );
  }

  Future<void> sendServiceUnavailableNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String service,
  }) async {
    await _createAndSendNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      type: NotificationType.serviceUnavailable,
      data: {
        'service': service,
      },
    );
  }

  Future<void> _createAndSendNotification({
    required String familyId,
    required String childId,
    required String childName,
    required NotificationType type,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Check for duplicate notifications within the last 5 minutes
      if (await _isDuplicateNotification(familyId, childId, type, data)) {
        if (kDebugMode) {
          print('Skipping duplicate notification: $type for $childName');
        }
        return;
      }

      final title = NotificationTemplate.getTitle(type, childName);
      final body = NotificationTemplate.getBody(type, childName, data);
      final priority = NotificationTemplate.getPriority(type);
      final expirationTime = NotificationTemplate.getExpirationTime(type);

      final notification = ParentNotification(
        id: _firestore.collection('notifications').doc().id,
        familyId: familyId,
        childId: childId,
        childName: childName,
        type: type,
        priority: priority,
        title: title,
        body: body,
        data: {
          ...data,
          'type': type.name,
          'familyId': familyId,
          'childId': childId,
        },
        createdAt: DateTime.now(),
        expiresAt: expirationTime != null ? DateTime.now().add(expirationTime) : null,
      );

      // Save notification to Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toFirestore());

      // This will trigger the Cloud Function to send FCM messages
      if (kDebugMode) {
        print('Created notification: $title - $body');
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error creating notification: $e');
      }
    }
  }

  Future<bool> _isDuplicateNotification(
    String familyId,
    String childId,
    NotificationType type,
    Map<String, dynamic> data,
  ) async {
    try {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      
      final query = _firestore
          .collection('notifications')
          .where('familyId', isEqualTo: familyId)
          .where('childId', isEqualTo: childId)
          .where('type', isEqualTo: type.name)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
          .limit(1);

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) return false;

      // For app requests, also check if it's the same app
      if (type == NotificationType.appRequest) {
        final existingData = snapshot.docs.first.data();
        return existingData['data']['packageName'] == data['packageName'];
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for duplicate notification: $e');
      }
      return false;
    }
  }

  // Helper methods for notification channels
  NotificationPriority _getPriorityFromData(Map<String, dynamic> data) {
    final priority = data['priority'];
    return NotificationPriority.values.firstWhere(
      (e) => e.name == priority,
      orElse: () => NotificationPriority.normal,
    );
  }

  String _getChannelForPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return _urgentChannelId;
      case NotificationPriority.high:
        return _highChannelId;
      case NotificationPriority.normal:
        return _normalChannelId;
      case NotificationPriority.low:
        return _lowChannelId;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case _urgentChannelId:
        return 'Urgent Notifications';
      case _highChannelId:
        return 'High Priority Notifications';
      case _normalChannelId:
        return 'Normal Notifications';
      case _lowChannelId:
        return 'Low Priority Notifications';
      default:
        return 'Notifications';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _urgentChannelId:
        return 'Critical security and monitoring alerts';
      case _highChannelId:
        return 'App requests and important alerts';
      case _normalChannelId:
        return 'General notifications and updates';
      case _lowChannelId:
        return 'Status updates and informational notices';
      default:
        return 'Family Guardian notifications';
    }
  }

  Importance _getImportanceForPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return Importance.max;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.low:
        return Importance.low;
    }
  }

  Priority _getPriorityForPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return Priority.max;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.low:
        return Priority.low;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  Stream<List<ParentNotification>> getNotificationsForParent(String familyId) {
    return _firestore
        .collection('notifications')
        .where('familyId', isEqualTo: familyId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParentNotification.fromFirestore(doc))
            .toList());
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _isInitialized = false;
  }
}

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}