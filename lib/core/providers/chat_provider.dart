import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import 'user_provider.dart';

final chatServiceProvider = Provider<ChatRepository>((ref) => ChatService());

final chatContactsProvider = StreamProvider<List<ChatContact>>((ref) {
  final userAsync = ref.watch(currentUserDataProvider);
  return userAsync.when(
    data: (user) => user == null
        ? Stream.value(const [])
        : ref.watch(chatServiceProvider).watchContacts(user),
    loading: () => Stream.value(const []),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});

final chatConversationsProvider = StreamProvider<List<ChatConversation>>((ref) {
  final userAsync = ref.watch(currentUserDataProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value(const []);
      return ref
          .watch(chatContactsProvider)
          .when(
            data: (contacts) => ref
                .watch(chatServiceProvider)
                .watchConversations(user, contacts),
            loading: () => Stream.value(const []),
            error: (error, stackTrace) => Stream.error(error, stackTrace),
          );
    },
    loading: () => Stream.value(const []),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});

final chatParticipantNameProvider = StreamProvider.family<String?, String>((
  ref,
  userId,
) {
  return ref.watch(chatServiceProvider).watchParticipantName(userId);
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  if (conversationId.isEmpty) return Stream.value(const []);
  return ref.watch(chatServiceProvider).watchRecentMessages(conversationId);
});
