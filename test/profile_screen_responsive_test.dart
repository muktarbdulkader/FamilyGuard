import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/user_model.dart';
import 'package:flutter_study_app/core/providers/family_provider.dart';
import 'package:flutter_study_app/core/providers/user_provider.dart';
import 'package:flutter_study_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

void main() {
  testWidgets('profile handles missing optional fields on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final user = UserModel(
      uid: 'user-id',
      email: 'parent@example.com',
      displayName: 'Parent',
      role: UserRole.parent,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDataProvider.overrideWith(
            (ref) => Stream<UserModel?>.value(user),
          ),
          familyChildrenProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
