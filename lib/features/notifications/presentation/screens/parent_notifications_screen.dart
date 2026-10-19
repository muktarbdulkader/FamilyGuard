import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/models/request_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/models/family_model.dart';
import '../../../../l10n/app_localizations.dart';

/// Parent Notifications Screen with top-tier UI:
/// - Prominently displays the child's name with custom avatars and tags
/// - Immediate one-tap actions (approve 30m, deny, set rules, view map)
/// - Filter tabs: All, Requests, Urgent, and Settings
/// - Verified, functional GoRouter navigation
class ParentNotificationsScreen extends ConsumerStatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  ConsumerState<ParentNotificationsScreen> createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState
    extends ConsumerState<ParentNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notificationsAsync = ref.watch(currentUserNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final urgentNotifications = ref.watch(urgentNotificationsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C1829)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0C1829) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        leading: IconButton(
          icon: Icon(
            isRtl
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.notifications,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2DD4BF)
                          : const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount New',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF0C1829) : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              l10n.realTimeAlerts,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF8BA0B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: Icon(
                Icons.done_all_rounded,
                color: isDark
                    ? const Color(0xFF2DD4BF)
                    : const Color(0xFF4F46E5),
              ),
              tooltip: l10n.markAllAsRead,
              onPressed: () {
                ref.read(notificationActionsProvider).markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark
              ? const Color(0xFF2DD4BF)
              : const Color(0xFF4F46E5),
          unselectedLabelColor: isDark
              ? const Color(0xFF8BA0B8)
              : const Color(0xFF64748B),
          indicatorColor: isDark
              ? const Color(0xFF2DD4BF)
              : const Color(0xFF4F46E5),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Requests'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Urgent'),
                  if (urgentNotifications.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${urgentNotifications.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Settings'),
          ],
        ),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error loading notifications',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(currentUserNotificationsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (notifications) {
          final requestNotifications = notifications
              .where((n) => n.type == NotificationType.appRequest)
              .toList();

          final urgentList = notifications
              .where(
                (n) =>
                    n.priority == NotificationPriority.urgent ||
                    n.priority == NotificationPriority.high,
              )
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _NotificationList(
                notifications: notifications,
                emptyTitle: 'No notifications yet',
                emptySubtitle:
                    'You will receive real-time alerts when children request apps, exceed limits, or install new applications.',
                emptyIcon: Icons.notifications_none_rounded,
              ),
              _NotificationList(
                notifications: requestNotifications,
                emptyTitle: 'No pending requests',
                emptySubtitle:
                    'When your children request access to blocked applications, they will appear here for one-tap approval.',
                emptyIcon: Icons.pending_actions_rounded,
              ),
              _NotificationList(
                notifications: urgentList,
                emptyTitle: 'All caught up!',
                emptySubtitle:
                    'No critical alerts or security issues on any child device right now.',
                emptyIcon: Icons.verified_user_rounded,
              ),
              const _NotificationSettingsTab(),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  final List<ParentNotification> notifications;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  const _NotificationList({
    required this.notifications,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  size: 54,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentUserNotificationsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _ChildNotificationCard(notification: notification);
        },
      ),
    );
  }
}

/// Rich, aesthetic Notification Card explicitly highlighting the child's name
class _ChildNotificationCard extends ConsumerWidget {
  final ParentNotification notification;

  const _ChildNotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(familyChildrenProvider).value ?? [];
    final selectedChild = ref.watch(selectedChildProvider);

    // Resolve real child name from notification or family children
    String childName = notification.childName.trim();
    if (childName.isEmpty ||
        childName.toLowerCase() == 'child' ||
        childName.toLowerCase() == 'your child') {
      final match = children.cast<ChildModel?>().firstWhere(
        (c) => c?.id == notification.childId,
        orElse: () => null,
      );
      if (match != null && match.displayName.trim().isNotEmpty) {
        childName = match.displayName.trim();
      } else if (selectedChild != null &&
          selectedChild.displayName.trim().isNotEmpty) {
        childName = selectedChild.displayName.trim();
      } else if (children.isNotEmpty &&
          children.first.displayName.trim().isNotEmpty) {
        childName = children.first.displayName.trim();
      } else {
        childName = 'Child';
      }
    }

    // Ensure child's real name is prominently in the title
    String cardTitle = notification.title.trim();
    if (childName != 'Child') {
      if (cardTitle.startsWith('Child:')) {
        cardTitle = cardTitle.replaceFirst('Child:', '$childName:');
      } else if (cardTitle.startsWith('Your child:')) {
        cardTitle = cardTitle.replaceFirst('Your child:', '$childName:');
      } else if (cardTitle.startsWith('🚫 Child:')) {
        cardTitle = cardTitle.replaceFirst('🚫 Child:', '🚫 $childName:');
      } else if (!cardTitle.contains(childName)) {
        cardTitle = '$childName: $cardTitle';
      }
    }

    // Ensure child's real name is in the body
    String cardBody = notification.body.trim();
    if (childName != 'Child') {
      cardBody = cardBody
          .replaceAll('Your child', childName)
          .replaceAll('your child', childName)
          .replaceAll('Child ', '$childName ');
    }

    final isUnread = !notification.isRead;
    final isUrgent = notification.priority == NotificationPriority.urgent;
    final isRequest = notification.type == NotificationType.appRequest;
    final isApproved = notification.isApproved;
    final isDenied = notification.isDenied;

    final typeColor = isApproved
        ? const Color(0xFF10B981)
        : isDenied
        ? const Color(0xFFEF4444)
        : _getTypeColor(notification.type);
    final typeIcon = isApproved
        ? Icons.check_circle_rounded
        : isDenied
        ? Icons.cancel_rounded
        : _getTypeIcon(notification.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread
              ? typeColor.withOpacity(0.4)
              : const Color(0xFFE2E8F0),
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread
                ? typeColor.withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _handleCardTap(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Child Identity Banner + Priority + Time
                Row(
                  children: [
                    // Child Avatar with Initials
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          childName.isNotEmpty
                              ? childName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Child Name & Relationship Tag
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  childName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFC7D2FE),
                                  ),
                                ),
                                child: const Text(
                                  'Child Device',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTimeAgo(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Priority Badge / Unread indicator
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      )
                    else if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                      ),

                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'read') {
                          ref
                              .read(notificationActionsProvider)
                              .markAsRead(notification.id);
                        } else if (value == 'details') {
                          _showDetailsDialog(context);
                        }
                      },
                      itemBuilder: (context) => [
                        if (isUnread)
                          const PopupMenuItem(
                            value: 'read',
                            child: Row(
                              children: [
                                Icon(Icons.mark_email_read_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Mark as read'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('View full details'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Notification Title with Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cardTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cardBody,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Quick Action Buttons
                if (isRequest) ...[
                  if (isApproved) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Approved ${notification.grantedMinutes != null ? "(${notification.grantedMinutes}m granted)" : ""}',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isDenied) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.cancel_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Request Denied',
                            style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _quickDenyRequest(context, ref),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Deny',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _quickApproveRequest(context, ref, 30),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text(
                              'Approve 30m',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else if (notification.type ==
                    NotificationType.newAppDetected) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToChildApps(context),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text(
                            'Configure App Rules',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (notification.type ==
                    NotificationType.dailyLimitReached) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.parentApps),
                          icon: const Icon(Icons.timelapse_rounded, size: 16),
                          label: const Text(
                            'View App Limits',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCardTap(BuildContext context, WidgetRef ref) {
    if (!notification.isRead) {
      ref.read(notificationActionsProvider).markAsRead(notification.id);
    }

    switch (notification.type) {
      case NotificationType.appRequest:
        context.push(AppRoutes.parentRequests);
        break;
      case NotificationType.newAppDetected:
        _navigateToChildApps(context);
        break;
      case NotificationType.dailyLimitReached:
        context.push(AppRoutes.parentApps);
        break;
      case NotificationType.deviceOnline:
      case NotificationType.deviceOffline:
        context.push(AppRoutes.parentLocation);
        break;
      default:
        _showDetailsDialog(context);
        break;
    }
  }

  void _navigateToChildApps(BuildContext context) {
    final childId = notification.childId;
    final childName = notification.childName;
    if (childId.isNotEmpty) {
      context.push('/parent-apps/$childId/$childName');
    } else {
      context.push(AppRoutes.parentApps);
    }
  }

  Future<void> _quickApproveRequest(
    BuildContext context,
    WidgetRef ref,
    int minutes,
  ) async {
    final requestId = notification.data['requestId'];
    final familyId = notification.familyId;
    final childId = notification.childId;

    if (requestId == null || familyId.isEmpty) {
      context.push(AppRoutes.parentRequests);
      return;
    }

    try {
      final parentId = ref.read(authProvider).user?.uid ?? 'parent';
      final now = Timestamp.now();
      final expires = Timestamp.fromDate(
        DateTime.now().add(Duration(minutes: minutes)),
      );

      final updateData = {
        'status': RequestStatus.approved.name,
        'grantedMinutes': minutes,
        'decidedAt': now,
        'decidedBy': parentId,
        'accessExpiresAt': expires,
      };

      // 1. Update in families/{familyId}/requests
      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('requests')
          .doc(requestId)
          .set(updateData, SetOptions(merge: true));

      // 2. Update child subcollection if exists
      if (childId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('families')
              .doc(familyId)
              .collection('children')
              .doc(childId)
              .collection('requests')
              .doc(requestId)
              .set(updateData, SetOptions(merge: true));
        } catch (_) {}

        // 3. Write temporary approval doc for native enforcement engine
        final packageName = notification.data['packageName'] as String? ?? '';
        if (packageName.isNotEmpty) {
          try {
            final pkgClean = packageName.replaceAll('.', '_');
            await FirebaseFirestore.instance
                .collection('families')
                .doc(familyId)
                .collection('children')
                .doc(childId)
                .collection('temporaryApprovals')
                .doc(pkgClean)
                .set({
                  'packageName': packageName,
                  'approvedAt': now,
                  'durationMinutes': minutes,
                  'approvedBy': parentId,
                  'accessExpiresAt': expires,
                }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Error writing temporaryApproval in quickApprove: $e');
          }
        }
      }

      // 4. Mark notification as approved & read
      await ref.read(notificationActionsProvider).markAsRead(notification.id);
      final notifApprovedPayload = {
        'status': 'approved',
        'isApproved': true,
        'grantedMinutes': minutes,
        'isRead': true,
        'readAt': now,
      };
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .set(notifApprovedPayload, SetOptions(merge: true));
      } catch (_) {}
      try {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .collection('notifications')
            .doc(notification.id)
            .set(notifApprovedPayload, SetOptions(merge: true));
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Approved $minutes minutes for ${notification.childName}',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _quickDenyRequest(BuildContext context, WidgetRef ref) async {
    final requestId = notification.data['requestId'];
    final familyId = notification.familyId;
    final childId = notification.childId;

    if (requestId == null || familyId.isEmpty) {
      context.push(AppRoutes.parentRequests);
      return;
    }

    try {
      final parentId = ref.read(authProvider).user?.uid ?? 'parent';
      final updateData = {
        'status': RequestStatus.denied.name,
        'decidedAt': Timestamp.now(),
        'decidedBy': parentId,
      };

      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('requests')
          .doc(requestId)
          .set(updateData, SetOptions(merge: true));

      if (childId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('families')
              .doc(familyId)
              .collection('children')
              .doc(childId)
              .collection('requests')
              .doc(requestId)
              .set(updateData, SetOptions(merge: true));
        } catch (_) {}
      }

      await ref.read(notificationActionsProvider).markAsRead(notification.id);
      final notifDenyPayload = {
        'status': 'denied',
        'isDenied': true,
        'isRead': true,
        'readAt': Timestamp.now(),
      };
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .set(notifDenyPayload, SetOptions(merge: true));
      } catch (_) {}
      try {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .collection('notifications')
            .doc(notification.id)
            .set(notifDenyPayload, SetOptions(merge: true));
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request denied for ${notification.childName}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deny: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getTypeColor(notification.type).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTypeIcon(notification.type),
                color: _getTypeColor(notification.type),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildDetailRow('Child Name', notification.childName),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Time',
              notification.createdAt.toString().split('.')[0],
            ),
            const SizedBox(height: 6),
            _buildDetailRow(
              'Priority',
              notification.priority.name.toUpperCase(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.appRequest:
        return const Color(0xFF4F46E5);
      case NotificationType.appApproved:
        return const Color(0xFF10B981);
      case NotificationType.appDenied:
        return const Color(0xFFEF4444);
      case NotificationType.newAppDetected:
        return const Color(0xFF2563EB);
      case NotificationType.dailyLimitReached:
        return const Color(0xFFD97706);
      case NotificationType.deviceOffline:
      case NotificationType.permissionDisabled:
      case NotificationType.serviceUnavailable:
        return const Color(0xFFDC2626);
      case NotificationType.deviceOnline:
        return const Color(0xFF10B981);
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.appRequest:
        return Icons.app_registration_rounded;
      case NotificationType.appApproved:
        return Icons.check_circle_rounded;
      case NotificationType.appDenied:
        return Icons.cancel_rounded;
      case NotificationType.newAppDetected:
        return Icons.new_releases_rounded;
      case NotificationType.dailyLimitReached:
        return Icons.timer_off_rounded;
      case NotificationType.deviceOffline:
        return Icons.phonelink_off_rounded;
      case NotificationType.deviceOnline:
        return Icons.phonelink_ring_rounded;
      case NotificationType.permissionDisabled:
        return Icons.security_update_warning_rounded;
      case NotificationType.serviceUnavailable:
        return Icons.warning_amber_rounded;
    }
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
}

class _NotificationSettingsTab extends StatefulWidget {
  const _NotificationSettingsTab();

  @override
  State<_NotificationSettingsTab> createState() =>
      _NotificationSettingsTabState();
}

class _NotificationSettingsTabState extends State<_NotificationSettingsTab> {
  bool _appRequests = true;
  bool _newApps = true;
  bool _dailyLimits = true;
  bool _deviceStatus = true;
  bool _securityAlerts = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Notification Preferences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose what notifications you receive for your children.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),
        _buildSettingTile(
          title: 'App Permission Requests',
          subtitle: 'Alerts when a child asks to unlock or use a blocked app',
          icon: Icons.app_registration_rounded,
          value: _appRequests,
          onChanged: (v) => setState(() => _appRequests = v),
        ),
        _buildSettingTile(
          title: 'New App Installations',
          subtitle: 'Notify immediately when any child installs a new app',
          icon: Icons.new_releases_rounded,
          value: _newApps,
          onChanged: (v) => setState(() => _newApps = v),
        ),
        _buildSettingTile(
          title: 'Daily Screen Time Limits',
          subtitle: 'Alerts when children reach their scheduled app limit',
          icon: Icons.timer_rounded,
          value: _dailyLimits,
          onChanged: (v) => setState(() => _dailyLimits = v),
        ),
        _buildSettingTile(
          title: 'Device Online / Offline Status',
          subtitle: 'Notifications when child devices disconnect or reconnect',
          icon: Icons.phonelink_ring_rounded,
          value: _deviceStatus,
          onChanged: (v) => setState(() => _deviceStatus = v),
        ),
        _buildSettingTile(
          title: 'Critical Security & Permissions',
          subtitle:
              'Emergency alerts if permissions or services are tampered with',
          icon: Icons.security_rounded,
          value: _securityAlerts,
          onChanged: (v) => setState(() => _securityAlerts = v),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        value: value,
        activeColor: const Color(0xFF4F46E5),
        onChanged: onChanged,
      ),
    );
  }
}
