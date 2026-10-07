import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final currentUserNotificationsProvider = StreamProvider<List<ParentNotification>>((ref) {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  
  if (user == null) {
    return Stream.value([]);
  }

  // Get user's family ID first
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .asyncExpand((userDoc) {
    if (!userDoc.exists) return Stream.value(<ParentNotification>[]);
    
    final userData = userDoc.data();
    final familyId = userData?['familyId'];
    
    if (familyId == null) return Stream.value(<ParentNotification>[]);
    
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('familyId', isEqualTo: familyId)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ParentNotification.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  });
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(currentUserNotificationsProvider);
  
  return notifications.when(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final urgentNotificationsProvider = Provider<List<ParentNotification>>((ref) {
  final notifications = ref.watch(currentUserNotificationsProvider);
  
  return notifications.when(
    data: (notifications) => notifications
        .where((n) => n.priority == NotificationPriority.urgent && !n.isRead)
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// Notification actions provider
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref ref;
  
  NotificationActions(this.ref);
  
  Future<void> markAsRead(String notificationId) async {
    final service = ref.read(notificationServiceProvider);
    await service.markNotificationAsRead(notificationId);
  }
  
  Future<void> markAllAsRead() async {
    final notifications = ref.read(currentUserNotificationsProvider);
    final service = ref.read(notificationServiceProvider);
    
    notifications.whenData((notifications) async {
      for (final notification in notifications.where((n) => !n.isRead)) {
        await service.markNotificationAsRead(notification.id);
      }
    });
  }
  
  Future<void> sendAppRequestNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String appName,
    required String packageName,
    required int requestedMinutes,
    required String requestId,
  }) async {
    final service = ref.read(notificationServiceProvider);
    
    await service.sendAppRequestNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      appName: appName,
      packageName: packageName,
      requestedMinutes: requestedMinutes,
      requestId: requestId,
    );
  }
  
  Future<void> sendNewAppDetectedNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String appName,
    required String packageName,
  }) async {
    final service = ref.read(notificationServiceProvider);
    
    await service.sendNewAppDetectedNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      appName: appName,
      packageName: packageName,
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
    final service = ref.read(notificationServiceProvider);
    
    await service.sendDailyLimitReachedNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      appName: appName,
      packageName: packageName,
      dailyLimitMinutes: dailyLimitMinutes,
    );
  }
  
  Future<void> sendDeviceStatusNotification({
    required String familyId,
    required String childId,
    required String childName,
    required bool isOnline,
  }) async {
    final service = ref.read(notificationServiceProvider);
    
    await service.sendDeviceStatusNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      isOnline: isOnline,
    );
  }
  
  Future<void> sendPermissionDisabledNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String permission,
  }) async {
    final service = ref.read(notificationServiceProvider);
    
    await service.sendPermissionDisabledNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      permission: permission,
    );
  }
  
  Future<void> sendServiceUnavailableNotification({
    required String familyId,
    required String childId,
    required String childName,
    required String service,
  }) async {
    final notificationService = ref.read(notificationServiceProvider);
    
    await notificationService.sendServiceUnavailableNotification(
      familyId: familyId,
      childId: childId,
      childName: childName,
      service: service,
    );
  }
}