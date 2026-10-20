import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/providers/chat_provider.dart';
import 'package:flutter_study_app/core/providers/user_provider.dart';
import 'package:flutter_study_app/features/chat/presentation/screens/chat_conversation_screen.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

import 'chat_test_fakes.dart';

void main() {
  testWidgets('retries a Unicode message with the same message ID', (
    tester,
  ) async {
    final repository = FakeChatRepository()..sendFailuresRemaining = 1;
    final localizations = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDataProvider.overrideWith(
            (ref) => Stream.value(testParent),
          ),
          chatServiceProvider.overrideWith((ref) => repository),
        ],
        child: MaterialApp(
          localizationsDelegates: chatLocalizationsDelegates,
          supportedLocales: chatSupportedLocales,
          home: const ChatConversationScreen(
            familyId: 'family-1',
            otherUserId: 'child-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const unicodeMessage = 'مرحبا 👋 — See you soon!';
    await tester.enterText(find.byType(TextField), unicodeMessage);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text(localizations.retrySendMessage), findsOneWidget);
    expect(repository.sentMessages, hasLength(1));
    final firstAttempt = repository.sentMessages.single;
    expect(firstAttempt.text, unicodeMessage);
    expect(firstAttempt.retry, isFalse);

    await tester.tap(find.text(localizations.retrySendMessage));
    await tester.pumpAndSettle();

    expect(repository.sentMessages, hasLength(2));
    expect(repository.sentMessages.last.messageId, firstAttempt.messageId);
    expect(repository.sentMessages.last.text, unicodeMessage);
    expect(repository.sentMessages.last.retry, isTrue);
    expect(find.text(localizations.retrySendMessage), findsNothing);
  });

  testWidgets('editing a failed draft uses a new message ID', (tester) async {
    final repository = FakeChatRepository()..sendFailuresRemaining = 1;
    final localizations = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDataProvider.overrideWith(
            (ref) => Stream.value(testParent),
          ),
          chatServiceProvider.overrideWith((ref) => repository),
        ],
        child: MaterialApp(
          localizationsDelegates: chatLocalizationsDelegates,
          supportedLocales: chatSupportedLocales,
          home: const ChatConversationScreen(
            familyId: 'family-1',
            otherUserId: 'child-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'First draft');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    final firstMessageId = repository.sentMessages.single.messageId;

    await tester.enterText(find.byType(TextField), 'Edited draft');
    await tester.pump();
    expect(find.text(localizations.retrySendMessage), findsNothing);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(repository.sentMessages, hasLength(2));
    expect(repository.sentMessages.last.messageId, isNot(firstMessageId));
    expect(repository.sentMessages.last.text, 'Edited draft');
    expect(repository.sentMessages.last.retry, isFalse);
  });
}
