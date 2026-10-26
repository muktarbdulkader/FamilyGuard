import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/chat_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../l10n/app_localizations.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({
    required this.familyId,
    required this.otherUserId,
    super.key,
  });

  final String familyId;
  final String otherUserId;

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageIdGenerator = const Uuid();
  final Map<String, ChatMessage> _messageCache = {};
  final Set<String> _readInFlight = {};

  String? _conversationId;
  String? _startedForUser;
  String? _initializationError;
  String? _pendingMessageId;
  String? _sendError;
  bool _isInitializing = false;
  bool _isSending = false;
  bool _isLoadingOlder = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    NotificationService.instance.setActiveChatConversation(null);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoadingOlder ||
        !_hasMore ||
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 160) {
      return;
    }
    _loadOlderMessages();
  }

  void _ensureConversation(UserModel user) {
    if (_startedForUser == user.uid || _isInitializing) return;
    _startedForUser = user.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openConversation(user);
    });
  }

  Future<void> _openConversation(UserModel user) async {
    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });
    try {
      final conversationId = await ref
          .read(chatServiceProvider)
          .ensureConversation(
            familyId: widget.familyId,
            currentUserId: user.uid,
            currentUserRole: user.role,
            otherUserId: widget.otherUserId,
          );
      if (!mounted) return;
      setState(() {
        _conversationId = conversationId;
        _isInitializing = false;
      });
      NotificationService.instance.setActiveChatConversation(conversationId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializationError = error.toString();
        _isInitializing = false;
      });
      debugPrint('Could not open chat conversation: $error');
    }
  }

  Future<void> _loadOlderMessages() async {
    final conversationId = _conversationId;
    final messages = _orderedMessages;
    if (conversationId == null || messages.isEmpty || _isLoadingOlder) return;

    setState(() => _isLoadingOlder = true);
    try {
      final older = await ref
          .read(chatServiceProvider)
          .loadOlderMessages(
            conversationId: conversationId,
            before: messages.last,
          );
      if (!mounted) return;
      setState(() {
        for (final message in older) {
          _messageCache[message.id] = message;
        }
        if (older.length < 30) _hasMore = false;
        _isLoadingOlder = false;
      });
      _scheduleMarkRead(older);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingOlder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).chatMessagesLoadError),
        ),
      );
    }
  }

  List<ChatMessage> get _orderedMessages {
    final messages = _messageCache.values.toList();
    messages.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
    return messages;
  }

  void _mergeMessages(List<ChatMessage> messages) {
    for (final message in messages) {
      _messageCache[message.id] = message;
    }
  }

  void _scheduleMarkRead(Iterable<ChatMessage> messages) {
    final currentUserId = ref.read(currentUserDataProvider).value?.uid;
    final conversationId = _conversationId;
    if (currentUserId == null || conversationId == null) return;

    final unread = messages
        .where(
          (message) =>
              message.recipientId == currentUserId &&
              message.readAt == null &&
              !_readInFlight.contains(message.id),
        )
        .toList(growable: false);
    if (unread.isEmpty) return;
    _readInFlight.addAll(unread.map((message) => message.id));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref
            .read(chatServiceProvider)
            .markMessagesRead(
              conversationId: conversationId,
              currentUserId: currentUserId,
              messages: unread,
            );
      } catch (error) {
        _readInFlight.removeAll(unread.map((message) => message.id));
        debugPrint('Could not mark chat messages as read: $error');
      }
    });
  }

  Future<void> _sendMessage(UserModel user) async {
    final conversationId = _conversationId;
    final text = _textController.text.trim();
    if (conversationId == null || text.isEmpty || _isSending) return;
    if (text.length > 4000) {
      setState(
        () => _sendError = AppLocalizations.of(context).messageFailedToSend,
      );
      return;
    }

    final messageId = _pendingMessageId ?? _messageIdGenerator.v4();
    final recipientId = widget.otherUserId;
    final isRetry = _sendError != null;
    setState(() {
      _isSending = true;
      _sendError = null;
      _pendingMessageId = messageId;
    });

    try {
      await ref
          .read(chatServiceProvider)
          .sendMessage(
            conversationId: conversationId,
            familyId: widget.familyId,
            senderId: user.uid,
            recipientId: recipientId,
            text: text,
            messageId: messageId,
            retry: isRetry,
          );
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _pendingMessageId = null;
        _sendError = null;
      });
      _textController.clear();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sendError = error is FirebaseException && error.code == 'unavailable'
            ? AppLocalizations.of(context).noInternetConnection
            : AppLocalizations.of(context).messageFailedToSend;
      });
      debugPrint('Chat message send failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserDataProvider);
    final theme = Theme.of(context);

    return userAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.chat)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.chat)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.chatListLoadError),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.refresh(currentUserDataProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.chatTryAgain),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null ||
            (user.role != UserRole.parent && user.role != UserRole.child)) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.chat)),
            body: Center(child: Text(l10n.noLinkedContacts)),
          );
        }

        _ensureConversation(user);
        final participantNameAsync = ref.watch(
          chatParticipantNameProvider(widget.otherUserId),
        );
        final fallbackName = user.role == UserRole.parent
            ? l10n.child
            : l10n.parent;
        final participantName =
            participantNameAsync.value?.trim().isNotEmpty == true
            ? participantNameAsync.value!.trim()
            : fallbackName;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(
                    user.role == UserRole.child
                        ? AppRoutes.childHome
                        : AppRoutes.parentHome,
                  );
                }
              },
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    participantName.isNotEmpty
                        ? participantName.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    participantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.55,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: Text(
                  l10n.chatPrivacyNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: _buildMessageArea(user)),
              _buildComposer(user),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageArea(UserModel user) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final conversationId = _conversationId;

    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.loadingMessages),
          ],
        ),
      );
    }
    if (_initializationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(l10n.chatListLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  _startedForUser = null;
                  _ensureConversation(user);
                },
                child: Text(l10n.chatTryAgain),
              ),
            ],
          ),
        ),
      );
    }
    if (conversationId == null) {
      return Center(child: Text(l10n.loadingMessages));
    }

    final messagesAsync = ref.watch(chatMessagesProvider(conversationId));
    return messagesAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.loadingMessages),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.chatMessagesLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(chatMessagesProvider(conversationId)),
                child: Text(l10n.chatTryAgain),
              ),
            ],
          ),
        ),
      ),
      data: (messages) {
        _mergeMessages(messages);
        _scheduleMarkRead(messages);
        final allMessages = _orderedMessages;
        if (allMessages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noMessagesYet,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.startConversation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
          itemCount: allMessages.length + (_isLoadingOlder ? 1 : 0),
          itemBuilder: (context, index) {
            if (_isLoadingOlder && index == allMessages.length) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _MessageBubble(
              message: allMessages[index],
              isMine: allMessages[index].senderId == user.uid,
            );
          },
        );
      },
    );
  }

  Widget _buildComposer(UserModel user) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sendError!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.retrySendMessage),
                      onPressed: _isSending ? null : () => _sendMessage(user),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l10n.typeMessage,
                      counterText: '',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      if (_sendError != null || _pendingMessageId != null) {
                        setState(() {
                          _sendError = null;
                          _pendingMessageId = null;
                        });
                      }
                    },
                    onSubmitted: (_) => _sendMessage(user),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l10n.send,
                  onPressed: _isSending ? null : () => _sendMessage(user),
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final date = message.createdAt.toLocal();
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final yesterdayDate = today.subtract(const Duration(days: 1));
    final isYesterday =
        date.year == yesterdayDate.year &&
        date.month == yesterdayDate.month &&
        date.day == yesterdayDate.day;
    final dateLabel = isToday
        ? l10n.today
        : isYesterday
        ? l10n.yesterday
        : MaterialLocalizations.of(context).formatMediumDate(date);
    final timeLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(date));
    final bubbleColor = isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(isMine ? 18 : 5),
              bottomEnd: Radius.circular(isMine ? 5 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SelectableText(
                message.text,
                style: TextStyle(color: foregroundColor, height: 1.35),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$dateLabel · $timeLabel',
                    style: TextStyle(
                      color: foregroundColor.withOpacity(0.72),
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 5),
                    Icon(
                      message.readAt == null
                          ? Icons.check_rounded
                          : Icons.done_all_rounded,
                      size: 13,
                      color: foregroundColor.withOpacity(0.75),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      message.readAt == null ? l10n.sent : l10n.read,
                      style: TextStyle(
                        color: foregroundColor.withOpacity(0.72),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
