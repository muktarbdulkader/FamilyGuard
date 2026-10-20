import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_study_app/core/constants/app_routes.dart';
import 'package:flutter_study_app/core/models/chat_model.dart';
import 'package:flutter_study_app/core/providers/chat_provider.dart';
import 'package:flutter_study_app/core/providers/user_provider.dart';
import 'package:flutter_study_app/core/services/chat_service.dart';
import 'package:flutter_study_app/features/chat/presentation/screens/chat_inbox_screen.dart';

import 'chat_test_fakes.dart';

void main() {
  testWidgets('shows the latest preview and unread count and opens a contact', (
    tester,
  ) async {
    final conversationId = ChatService.conversationId(
      familyId: 'family-1',
      parentId: testParent.uid,
      childId: testChildContact.userId,
    );
    final router = GoRouter(
      initialLocation: AppRoutes.chat,
      routes: [
        GoRoute(
          path: AppRoutes.chat,
          builder: (context, state) => const ChatInboxScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.chat}/:familyId/:otherUserId',
          builder: (context, state) => Text(
            'Conversation route ${state.pathParameters['familyId']} '
            '${state.pathParameters['otherUserId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDataProvider.overrideWith(
            (ref) => Stream.value(testParent),
          ),
          chatContactsProvider.overrideWith(
            (ref) => Stream.value([testChildContact]),
          ),
          chatConversationsProvider.overrideWith(
            (ref) => Stream.value([
              ChatConversation(
                id: conversationId,
                familyId: 'family-1',
                parentId: testParent.uid,
                childId: testChildContact.userId,
                participantIds: [testParent.uid, testChildContact.userId],
                lastMessage: 'I finished my homework.',
                lastSenderId: testChildContact.userId,
                updatedAt: DateTime(2026, 3, 23, 14, 30),
                unreadCounts: {testParent.uid: 3},
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: chatLocalizationsDelegates,
          supportedLocales: chatSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leila'), findsOneWidget);
    expect(find.text('I finished my homework.'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('2:30'), findsOneWidget);

    await tester.tap(find.text('Leila'));
    await tester.pumpAndSettle();

    expect(find.text('Conversation route family-1 child-1'), findsOneWidget);
  });
}
