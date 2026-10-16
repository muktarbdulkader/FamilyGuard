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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final nestedData = Map<String, dynamic>.from(data['data'] ?? {});
    
    // Resolve child name with comprehensive multi-field fallbacks
    String resolvedChildName = (data['childName'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (data['child_name'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (data['childDisplayName'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (data['displayName'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (data['name'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (nestedData['childName'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (nestedData['child_name'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (nestedData['childDisplayName'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (nestedData['displayName'] as String?)?.trim() ?? '';
    if (resolvedChildName.isEmpty) resolvedChildName = (nestedData['name'] as String?)?.trim() ?? '';

    // If still empty or generic, check if the raw title contains the child's name (e.g. "Maya: App Request")
    final rawTitle = (data['title'] as String?)?.trim() ?? '';
    if ((resolvedChildName.isEmpty || resolvedChildName.toLowerCase() == 'child' || resolvedChildName.toLowerCase() == 'your child') && rawTitle.contains(':')) {
      final prefix = rawTitle.split(':').first.replaceAll('🚫', '').trim();
      if (prefix.isNotEmpty && prefix.toLowerCase() != 'child' && prefix.toLowerCase() != 'your child') {
        resolvedChildName = prefix;
      }
    }

    if (resolvedChildName.isEmpty) {
      resolvedChildName = 'Child';
    }

    // Resolve type supporting both camelCase and snake_case
    final rawType = (data['type'] ?? nestedData['type'] ?? '').toString();
    final NotificationType resolvedType = switch (rawType) {
      'appRequest' || 'app_request' || 'blocked_app_attempt' => NotificationType.appRequest,
      'newAppDetected' || 'new_app_detected' => NotificationType.newAppDetected,
      'dailyLimitReached' || 'daily_limit_reached' => NotificationType.dailyLimitReached,
      'deviceOffline' || 'device_offline' => NotificationType.deviceOffline,
      'deviceOnline' || 'device_online' => NotificationType.deviceOnline,
      'permissionDisabled' || 'permission_disabled' => NotificationType.permissionDisabled,
      'serviceUnavailable' || 'service_unavailable' => NotificationType.serviceUnavailable,
      _ => NotificationType.values.firstWhere(
          (e) => e.name == rawType,
          orElse: () => NotificationType.appRequest,
        ),
    };

    final rawPriority = (data['priority'] ?? '').toString();
    final NotificationPriority resolvedPriority = NotificationPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == rawPriority.toLowerCase(),
      orElse: () => NotificationTemplate.getPriority(resolvedType),
    );

    // Resolve title and body with smart fallback using NotificationTemplate
    String resolvedTitle = (data['title'] as String?)?.trim() ?? '';
    if (resolvedTitle.isEmpty) {
      resolvedTitle = NotificationTemplate.getTitle(resolvedType, resolvedChildName);
    }

    String resolvedBody = (data['body'] as String?)?.trim() ?? '';
    if (resolvedBody.isEmpty) {
      resolvedBody = NotificationTemplate.getBody(resolvedType, resolvedChildName, nestedData);
    }
    
    return ParentNotification(
      id: doc.id,
      familyId: data['familyId'] ?? nestedData['familyId'] ?? '',
      childId: data['childId'] ?? nestedData['childId'] ?? '',
      childName: resolvedChildName,
      type: resolvedType,
      priority: resolvedPriority,
      title: resolvedTitle,
      body: resolvedBody,
      data: nestedData.isNotEmpty ? nestedData : data,
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
    final name = childName.trim().isNotEmpty ? childName.trim() : 'Child';
    switch (type) {
      case NotificationType.appRequest:
        return '$name: App Permission Request';
      case NotificationType.newAppDetected:
        return '$name: New App Detected';
      case NotificationType.dailyLimitReached:
        return '$name: Daily Screen Limit Reached';
      case NotificationType.deviceOffline:
        return '$name: Device Offline';
      case NotificationType.deviceOnline:
        return '$name: Device Back Online';
      case NotificationType.permissionDisabled:
        return '$name: Permission Disabled';
      case NotificationType.serviceUnavailable:
        return '$name: Monitoring Service Stopped';
    }
  }

  static String getBody(NotificationType type, String childName, Map<String, dynamic> data) {
    final name = childName.trim().isNotEmpty ? childName.trim() : 'Child';
    switch (type) {
      case NotificationType.appRequest:
        final appName = data['appName'] ?? 'an app';
        final requestedMinutes = data['requestedMinutes'] ?? 30;
        return '$name requested to use $appName for $requestedMinutes minutes.';
      
      case NotificationType.newAppDetected:
        final appName = data['appName'] ?? 'A new app';
        return '$appName was installed on $name\'s device.';
      
      case NotificationType.dailyLimitReached:
        final appName = data['appName'] ?? 'an app';
        return '$name reached their daily limit for $appName.';
      
      case NotificationType.deviceOffline:
        return '$name\'s device went offline.';
      
      case NotificationType.deviceOnline:
        return '$name\'s device is back online and protected.';
      
      case NotificationType.permissionDisabled:
        final permission = data['permission'] ?? 'A required permission';
        return '$permission was disabled on $name\'s device.';
      
      case NotificationType.serviceUnavailable:
        return 'Monitoring service stopped on $name\'s device.';
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