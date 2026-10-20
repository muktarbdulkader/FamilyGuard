import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../l10n/app_localizations.dart';

class ChatHomeCard extends ConsumerWidget {
  const ChatHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserDataProvider).value;
    final contacts = ref.watch(chatContactsProvider).value ?? const [];
    final conversations =
        ref.watch(chatConversationsProvider).value ?? const [];
    final unreadCount = user == null
        ? 0
        : conversations.fold<int>(
            0,
            (total, conversation) =>
                total + conversation.unreadCountFor(user.uid),
          );
    final latest = conversations.isEmpty ? null : conversations.first;
    final contact = latest == null
        ? contacts.firstOrNull
        : contacts.where((item) {
            final otherId = user?.role == UserRole.parent
                ? latest.childId
                : latest.parentId;
            return item.familyId == latest.familyId && item.userId == otherId;
          }).firstOrNull;
    final preview = latest?.lastMessage.trim().isNotEmpty == true
        ? latest!.lastMessage
        : contacts.isEmpty
        ? l10n.noLinkedContacts
        : l10n.startConversation;
    final latestTime = latest == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(latest.updatedAt.toLocal()));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.chat),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.chat,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (contact != null)
                      Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (latestTime != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            latestTime,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
