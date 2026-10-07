import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/providers/notification_provider.dart';

class ParentNotificationsScreen extends ConsumerStatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  ConsumerState<ParentNotificationsScreen> createState() => _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends ConsumerState<ParentNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(currentUserNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final urgentNotifications = ref.watch(urgentNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: () {
                ref.read(notificationActionsProvider).markAllAsRead();
              },
              tooltip: 'Mark all as read',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'All',
              icon: unreadCount > 0
                  ? Badge(
                      label: Text('$unreadCount'),
                      child: const Icon(Icons.notifications),
                    )
                  : const Icon(Icons.notifications),
            ),
            Tab(
              text: 'Urgent',
              icon: urgentNotifications.isNotEmpty
                  ? Badge(
                      label: Text('${urgentNotifications.length}'),
                      child: const Icon(Icons.priority_high),
                    )
                  : const Icon(Icons.priority_high),
            ),
            const Tab(
              text: 'Settings',
              icon: Icon(Icons.settings),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllNotificationsTab(notifications: notifications),
          _UrgentNotificationsTab(notifications: urgentNotifications),
          const _NotificationSettingsTab(),
        ],
      ),
    );
  }
}

class _AllNotificationsTab extends ConsumerWidget {
  final AsyncValue<List<ParentNotification>> notifications;

  const _AllNotificationsTab({required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return notifications.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading notifications: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(currentUserNotificationsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No notifications yet'),
                SizedBox(height: 8),
                Text(
                  'You\'ll receive notifications when your children need permissions or encounter issues.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentUserNotificationsProvider);
          },
          child: ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          ),
        );
      },
    );
  }
}

class _UrgentNotificationsTab extends ConsumerWidget {
  final List<ParentNotification> notifications;

  const _UrgentNotificationsTab({required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No urgent notifications'),
            SizedBox(height: 8),
            Text(
              'All critical issues have been addressed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationTile(notification: notification, showUrgentBadge: true);
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final ParentNotification notification;
  final bool showUrgentBadge;

  const _NotificationTile({
    required this.notification,
    this.showUrgentBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: notification.isRead ? 1 : 3,
      child: ListTile(
        leading: _getNotificationIcon(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            if (showUrgentBadge && notification.priority == NotificationPriority.urgent)
              const Badge(
                label: Text('!'),
                backgroundColor: Colors.red,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: TextStyle(
                color: notification.isRead ? Colors.grey[600] : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getTimeAgo(notification.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          _handleNotificationTap(context, ref, notification);
        },
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            if (!notification.isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, size: 16),
                    SizedBox(width: 8),
                    Text('Mark as read'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Text('View details'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'mark_read':
                ref.read(notificationActionsProvider).markAsRead(notification.id);
                break;
              case 'details':
                _showNotificationDetails(context, notification);
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _getNotificationIcon() {
    Color color;
    IconData icon;

    switch (notification.type) {
      case NotificationType.appRequest:
        color = Colors.blue;
        icon = Icons.app_registration;
        break;
      case NotificationType.newAppDetected:
        color = Colors.orange;
        icon = Icons.new_releases;
        break;
      case NotificationType.dailyLimitReached:
        color = Colors.amber;
        icon = Icons.timer_off;
        break;
      case NotificationType.deviceOffline:
        color = Colors.red;
        icon = Icons.phone_android;
        break;
      case NotificationType.deviceOnline:
        color = Colors.green;
        icon = Icons.phone_android;
        break;
      case NotificationType.permissionDisabled:
        color = Colors.red;
        icon = Icons.security;
        break;
      case NotificationType.serviceUnavailable:
        color = Colors.red;
        icon = Icons.warning;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(BuildContext context, WidgetRef ref, ParentNotification notification) {
    // Mark as read
    if (!notification.isRead) {
      ref.read(notificationActionsProvider).markAsRead(notification.id);
    }

    // Navigate based on notification type
    final data = notification.data;
    switch (notification.type) {
      case NotificationType.appRequest:
        final requestId = data['requestId'];
        if (requestId != null) {
          // Navigate to request approval screen
          context.go('/parent/requests/$requestId');
        }
        break;
      case NotificationType.newAppDetected:
        final childId = data['childId'];
        if (childId != null) {
          // Navigate to app management screen
          context.go('/parent/apps?childId=$childId');
        }
        break;
      case NotificationType.dailyLimitReached:
        final childId = data['childId'];
        if (childId != null) {
          // Navigate to usage dashboard
          context.go('/parent/usage?childId=$childId');
        }
        break;
      default:
        // Navigate to general parent dashboard
        context.go('/parent');
        break;
    }
  }

  void _showNotificationDetails(BuildContext context, ParentNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 16),
            Text(
              'Child: ${notification.childName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: ${notification.createdAt.toString()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Priority: ${notification.priority.name.toUpperCase()}',
              style: TextStyle(
                color: _getPriorityColor(notification.priority),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.normal:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.grey;
    }
  }
}

class _NotificationSettingsTab extends StatelessWidget {
  const _NotificationSettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Notification Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('App Requests'),
                subtitle: const Text('Notify when children request app access'),
                value: true,
                onChanged: (value) {
                  // TODO: Implement notification preference saving
                },
              ),
              SwitchListTile(
                title: const Text('New Apps'),
                subtitle: const Text('Notify when new apps are installed'),
                value: true,
                onChanged: (value) {
                  // TODO: Implement notification preference saving
                },
              ),
              SwitchListTile(
                title: const Text('Daily Limits'),
                subtitle: const Text('Notify when daily usage limits are reached'),
                value: true,
                onChanged: (value) {
                  // TODO: Implement notification preference saving
                },
              ),
              SwitchListTile(
                title: const Text('Device Status'),
                subtitle: const Text('Notify when devices go online/offline'),
                value: false,
                onChanged: (value) {
                  // TODO: Implement notification preference saving
                },
              ),
              SwitchListTile(
                title: const Text('Security Alerts'),
                subtitle: const Text('Notify about permissions and service issues'),
                value: true,
                onChanged: (value) {
                  // TODO: Implement notification preference saving
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Notification Sound'),
                subtitle: const Text('Default notification sound'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implement sound selection
                },
              ),
              ListTile(
                title: const Text('Quiet Hours'),
                subtitle: const Text('10:00 PM - 7:00 AM'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Implement quiet hours setting
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}