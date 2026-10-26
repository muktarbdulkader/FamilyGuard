import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/chat_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/services/chat_service.dart';
import '../../../../l10n/app_localizations.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserDataProvider);
    final contactsAsync = ref.watch(chatContactsProvider);
    final conversationsAsync = ref.watch(chatConversationsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final isChild = userAsync.value?.role == UserRole.child;
              context.go(isChild ? AppRoutes.childHome : AppRoutes.parentHome);
            }
          },
        ),
        title: Text(
          l10n.conversations,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          icon: Icons.error_outline_rounded,
          message: l10n.chatListLoadError,
          color: colors.error,
          onRetry: () => ref.refresh(currentUserDataProvider),
          retryLabel: l10n.chatTryAgain,
        ),
        data: (user) {
          if (user == null) {
            return _MessageState(
              icon: Icons.lock_outline_rounded,
              message: l10n.noLinkedContacts,
              color: colors.onSurfaceVariant,
              onRetry: () => ref.refresh(currentUserDataProvider),
              retryLabel: l10n.chatTryAgain,
            );
          }

          return contactsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _MessageState(
              icon: Icons.error_outline_rounded,
              message: l10n.chatListLoadError,
              color: colors.error,
              onRetry: () => ref.refresh(chatContactsProvider),
              retryLabel: l10n.chatTryAgain,
            ),
            data: (contacts) {
              if (contacts.isEmpty) {
                return _MessageState(
                  icon: Icons.forum_outlined,
                  message: l10n.noLinkedContacts,
                  color: colors.onSurfaceVariant,
                  onRetry: () => ref.refresh(chatContactsProvider),
                  retryLabel: l10n.chatTryAgain,
                );
              }
              return conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _MessageState(
                  icon: Icons.error_outline_rounded,
                  message: l10n.chatListLoadError,
                  color: colors.error,
                  onRetry: () => ref.refresh(chatConversationsProvider),
                  retryLabel: l10n.chatTryAgain,
                ),
                data: (conversations) {
                  final byId = {
                    for (final conversation in conversations)
                      conversation.id: conversation,
                  };
                  final sortedContacts = [...contacts];
                  sortedContacts.sort((left, right) {
                    final leftConversation =
                        byId[_conversationId(user.uid, user.role, left)];
                    final rightConversation =
                        byId[_conversationId(user.uid, user.role, right)];
                    if (leftConversation == null && rightConversation == null) {
                      return left.displayName.toLowerCase().compareTo(
                        right.displayName.toLowerCase(),
                      );
                    }
                    if (leftConversation == null) return 1;
                    if (rightConversation == null) return -1;
                    return rightConversation.updatedAt.compareTo(
                      leftConversation.updatedAt,
                    );
                  });

                  final hasConversations = conversations.isNotEmpty;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: colors.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.chatPrivacyNotice,
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.conversations,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (!hasConversations) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.noConversations,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 10),
                      for (final contact in sortedContacts)
                        _ConversationTile(
                          contact: contact,
                          conversation:
                              byId[_conversationId(
                                user.uid,
                                user.role,
                                contact,
                              )],
                          currentUserId: user.uid,
                          onTap: () {
                            final uri = Uri(
                              path:
                                  '${AppRoutes.chat}/${Uri.encodeComponent(contact.familyId)}/${Uri.encodeComponent(contact.userId)}',
                            );
                            context.push(uri.toString());
                          },
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _conversationId(
    String currentUserId,
    UserRole role,
    ChatContact contact,
  ) {
    final parentId = role == UserRole.parent ? currentUserId : contact.userId;
    final childId = role == UserRole.child ? currentUserId : contact.userId;
    return ChatService.conversationId(
      familyId: contact.familyId,
      parentId: parentId,
      childId: childId,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.contact,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatContact contact;
  final ChatConversation? conversation;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unreadCount = conversation?.unreadCountFor(currentUserId) ?? 0;
    final preview = conversation?.lastMessage.trim().isNotEmpty == true
        ? conversation!.lastMessage
        : l10n.startConversation;
    final time = conversation == null
        ? ''
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(conversation!.updatedAt.toLocal()),
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  contact.displayName.isNotEmpty
                      ? contact.displayName.characters.first.toUpperCase()
                      : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.color,
    this.onRetry,
    this.retryLabel,
  });

  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: color),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
