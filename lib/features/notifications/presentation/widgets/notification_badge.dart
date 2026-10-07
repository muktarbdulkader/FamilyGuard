import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/models/notification_model.dart';

class NotificationBadge extends ConsumerWidget {
  final Widget child;
  final bool showCount;
  final VoidCallback? onTap;

  const NotificationBadge({
    super.key,
    required this.child,
    this.showCount = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final urgentNotifications = ref.watch(urgentNotificationsProvider);
    
    Widget badgeChild = child;
    
    if (unreadCount > 0) {
      badgeChild = Badge(
        label: showCount ? Text('$unreadCount') : null,
        backgroundColor: urgentNotifications.isNotEmpty ? Colors.red : Colors.blue,
        child: child,
      );
    }

    return GestureDetector(
      onTap: onTap ?? () => context.go('/parent/notifications'),
      child: badgeChild,
    );
  }
}

class NotificationFloatingActionButton extends ConsumerWidget {
  const NotificationFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final urgentNotifications = ref.watch(urgentNotificationsProvider);
    
    // Don't show FAB if no notifications
    if (unreadCount == 0) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: () => context.go('/parent/notifications'),
      backgroundColor: urgentNotifications.isNotEmpty ? Colors.red : Colors.blue,
      child: Badge(
        label: Text('$unreadCount'),
        backgroundColor: Colors.white,
        textColor: urgentNotifications.isNotEmpty ? Colors.red : Colors.blue,
        child: const Icon(Icons.notifications, color: Colors.white),
      ),
    );
  }
}

class UrgentNotificationBanner extends ConsumerWidget {
  const UrgentNotificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgentNotifications = ref.watch(urgentNotificationsProvider);
    
    if (urgentNotifications.isEmpty) {
      return const SizedBox.shrink();
    }

    final notification = urgentNotifications.first;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.priority_high, color: Colors.red),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(notification.body),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (urgentNotifications.length > 1)
              Badge(
                label: Text('${urgentNotifications.length}'),
                child: const Icon(Icons.more_vert),
              )
            else
              const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: () => context.go('/parent/notifications'),
      ),
    );
  }
}

class NotificationSummaryCard extends ConsumerWidget {
  const NotificationSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(currentUserNotificationsProvider);
    
    return notifications.when(
      loading: () => const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Loading notifications...'),
        ),
      ),
      error: (error, stack) => const Card(
        child: ListTile(
          leading: Icon(Icons.error, color: Colors.red),
          title: Text('Error loading notifications'),
        ),
      ),
      data: (notifications) {
        final unread = notifications.where((n) => !n.isRead).length;
        final urgent = notifications
            .where((n) => n.priority == NotificationPriority.urgent && !n.isRead)
            .length;
        final today = notifications
            .where((n) => _isToday(n.createdAt) && !n.isRead)
            .length;

        if (unread == 0) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green[700]),
              title: const Text('All caught up!'),
              subtitle: const Text('No new notifications'),
            ),
          );
        }

        return Card(
          child: ListTile(
            leading: Badge(
              label: Text('$unread'),
              backgroundColor: urgent > 0 ? Colors.red : Colors.blue,
              child: const Icon(Icons.notifications),
            ),
            title: Text('$unread new notification${unread == 1 ? '' : 's'}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (urgent > 0)
                  Text(
                    '$urgent urgent alert${urgent == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                if (today > 0)
                  Text('$today from today'),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.go('/parent/notifications'),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
}