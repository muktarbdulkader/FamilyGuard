import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/user_model.dart';
import 'package:flutter_study_app/core/providers/user_provider.dart';
import 'package:flutter_study_app/features/permissions/presentation/screens/permission_onboarding_screen.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

void main() {
  testWidgets('device setup step scrolls on a short screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDataProvider.overrideWith(
            (ref) => Stream<UserModel?>.value(null),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const PermissionOnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Device Setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
