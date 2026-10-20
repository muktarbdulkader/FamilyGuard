import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/chat_model.dart';
import 'package:flutter_study_app/core/providers/chat_provider.dart';
import 'package:flutter_study_app/core/providers/user_provider.dart';
import 'package:flutter_study_app/features/chat/presentation/screens/chat_inbox_screen.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

import 'chat_test_fakes.dart';

void main() {
  test('every supported locale has translated chat labels', () async {
    for (final locale in chatSupportedLocales) {
      final localizations = await AppLocalizations.delegate.load(locale);
      expect(localizations.conversations, isNotEmpty);
      expect(localizations.chatPrivacyNotice, isNotEmpty);
      expect(localizations.noMessagesYet, isNotEmpty);
      expect(localizations.typeMessage, isNotEmpty);
      expect(localizations.retrySendMessage, isNotEmpty);
    }
  });

  testWidgets('renders the Arabic chat inbox in RTL direction', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDataProvider.overrideWith(
            (ref) => Stream.value(testParent),
          ),
          chatContactsProvider.overrideWith(
            (ref) => Stream.value([
              const ChatContact(
                familyId: 'family-1',
                userId: 'child-1',
                displayName: 'ليلى',
                isParent: false,
              ),
            ]),
          ),
          chatConversationsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: chatLocalizationsDelegates,
          supportedLocales: chatSupportedLocales,
          home: ChatInboxScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nameFinder = find.text('ليلى');
    expect(nameFinder, findsOneWidget);
    expect(Directionality.of(tester.element(nameFinder)), TextDirection.rtl);
  });
}
