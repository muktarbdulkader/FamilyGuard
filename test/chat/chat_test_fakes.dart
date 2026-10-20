import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_study_app/core/models/chat_model.dart';
import 'package:flutter_study_app/core/models/user_model.dart';
import 'package:flutter_study_app/core/services/chat_service.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

final testParent = UserModel(
  uid: 'parent-1',
  email: 'parent@example.com',
  displayName: 'Parent',
  role: UserRole.parent,
  familyId: 'family-1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const testChildContact = ChatContact(
  familyId: 'family-1',
  userId: 'child-1',
  displayName: 'Leila',
  isParent: false,
);

List<LocalizationsDelegate<dynamic>> get chatLocalizationsDelegates => const [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const chatSupportedLocales = [
  Locale('en'),
  Locale('om'),
  Locale('am'),
  Locale('ar'),
];

class SentMessageCall {
  const SentMessageCall({
    required this.messageId,
    required this.text,
    required this.retry,
  });

  final String messageId;
  final String text;
  final bool retry;
}

class FakeChatRepository implements ChatRepository {
  final List<SentMessageCall> sentMessages = [];
  int sendFailuresRemaining = 0;

  @override
  Future<String> ensureConversation({
    required String familyId,
    required String currentUserId,
    required UserRole currentUserRole,
    required String otherUserId,
  }) async => 'conversation-1';

  @override
  Future<List<ChatMessage>> loadOlderMessages({
    required String conversationId,
    required ChatMessage before,
  }) async => const [];

  @override
  Future<void> markMessagesRead({
    required String conversationId,
    required String currentUserId,
    required Iterable<ChatMessage> messages,
  }) async {}

  @override
  Future<String> sendMessage({
    required String conversationId,
    required String familyId,
    required String senderId,
    required String recipientId,
    required String text,
    required String messageId,
    bool retry = false,
  }) async {
    sentMessages.add(
      SentMessageCall(messageId: messageId, text: text, retry: retry),
    );
    if (sendFailuresRemaining > 0) {
      sendFailuresRemaining--;
      throw StateError('simulated send failure');
    }
    return messageId;
  }

  @override
  Stream<List<ChatContact>> watchContacts(UserModel user) =>
      Stream.value([testChildContact]);

  @override
  Stream<List<ChatConversation>> watchConversations(
    UserModel user,
    List<ChatContact> contacts,
  ) => Stream.value(const []);

  @override
  Stream<List<ChatMessage>> watchRecentMessages(String conversationId) =>
      Stream.value(const []);

  @override
  Stream<String?> watchParticipantName(String userId) =>
      Stream.value(testChildContact.displayName);
}
