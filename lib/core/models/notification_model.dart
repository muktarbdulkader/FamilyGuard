import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  appRequest,
  newAppDetected,
  dailyLimitReached,
  deviceOffline,
  deviceOnline,
  permissionDisabled,
  serviceUnavailable,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

class ParentNotification {
  final String id;
  final String familyId;
  final String childId;
  final String childName;
  final NotificationType type;
  final NotificationPriority priority;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final bool isRead;

  const ParentNotification({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.childName,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
    this.expiresAt,
    this.isRead = false,
  });

  factory ParentNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ParentNotification(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      childId: data['childId'] ?? '',
      childName: data['childName'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.appRequest,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'childId': childId,
      'childName': childName,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isRead': isRead,
    };
  }

  ParentNotification copyWith({
    String? id,
    String? familyId,
    String? childId,
    String? childName,
    NotificationType? type,
    NotificationPriority? priority,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? expiresAt,
    bool? isRead,
  }) {
    return ParentNotification(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class FCMToken {
  final String userId;
  final String token;
  final String platform; // 'android', 'ios', 'web'
  final String? deviceId;
  final DateTime createdAt;
  final DateTime lastUsed;
  final bool isActive;

  const FCMToken({
    required this.userId,
    required this.token,
    required this.platform,
    this.deviceId,
    required this.createdAt,
    required this.lastUsed,
    this.isActive = true,
  });

  factory FCMToken.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FCMToken(
      userId: data['userId'] ?? '',
      token: data['token'] ?? '',
      platform: data['platform'] ?? 'android',
      deviceId: data['deviceId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUsed: (data['lastUsed'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'token': token,
      'platform': platform,
      'deviceId': deviceId,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUsed': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  FCMToken copyWith({
    String? userId,
    String? token,
    String? platform,
    String? deviceId,
    DateTime? createdAt,
    DateTime? lastUsed,
    bool? isActive,
  }) {
    return FCMToken(
      userId: userId ?? this.userId,
      token: token ?? this.token,
      platform: platform ?? this.platform,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      isActive: isActive ?? this.isActive,
    );
  }
}

class NotificationTemplate {
  static String getTitle(NotificationType type, String childName) {
    switch (type) {
      case NotificationType.appRequest:
        return 'App Permission Request';
      case NotificationType.newAppDetected:
        return 'New App Detected';
      case NotificationType.dailyLimitReached:
        return 'Daily Limit Reached';
      case NotificationType.deviceOffline:
        return 'Device Offline';
      case NotificationType.deviceOnline:
        return 'Device Online';
      case NotificationType.permissionDisabled:
        return 'Permission Disabled';
      case NotificationType.serviceUnavailable:
        return 'Monitoring Unavailable';
    }
  }

  static String getBody(NotificationType type, String childName, Map<String, dynamic> data) {
    switch (type) {
      case NotificationType.appRequest:
        final appName = data['appName'] ?? 'an app';
        final requestedMinutes = data['requestedMinutes'] ?? 30;
        return '$childName wants to use $appName for $requestedMinutes minutes.';
      
      case NotificationType.newAppDetected:
        final appName = data['appName'] ?? 'New app';
        return '$appName was installed on $childName\'s device.';
      
      case NotificationType.dailyLimitReached:
        final appName = data['appName'] ?? 'App';
        return '$childName has reached their daily limit for $appName.';
      
      case NotificationType.deviceOffline:
        return '$childName\'s device went offline.';
      
      case NotificationType.deviceOnline:
        return '$childName\'s device is back online.';
      
      case NotificationType.permissionDisabled:
        final permission = data['permission'] ?? 'A permission';
        return '$permission was disabled on $childName\'s device.';
      
      case NotificationType.serviceUnavailable:
        return 'Monitoring service stopped on $childName\'s device.';
    }
  }

  static NotificationPriority getPriority(NotificationType type) {
    switch (type) {
      case NotificationType.appRequest:
        return NotificationPriority.high;
      case NotificationType.permissionDisabled:
      case NotificationType.serviceUnavailable:
        return NotificationPriority.urgent;
      case NotificationType.dailyLimitReached:
      case NotificationType.deviceOffline:
        return NotificationPriority.normal;
      case NotificationType.newAppDetected:
      case NotificationType.deviceOnline:
        return NotificationPriority.low;
    }
  }

  static Duration? getExpirationTime(NotificationType type) {
    switch (type) {
      case NotificationType.appRequest:
        return const Duration(minutes: 15); // Request expires in 15 minutes
      case NotificationType.deviceOnline:
        return const Duration(hours: 1); // Status change notifications expire quickly
      case NotificationType.deviceOffline:
        return null; // Keep until resolved
      case NotificationType.newAppDetected:
        return const Duration(hours: 24); // Give parents a day to review
      case NotificationType.dailyLimitReached:
        return const Duration(hours: 8); // Reset overnight
      case NotificationType.permissionDisabled:
      case NotificationType.serviceUnavailable:
        return null; // Critical notifications don't expire
    }
  }
}