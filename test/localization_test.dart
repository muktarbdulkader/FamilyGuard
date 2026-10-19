import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_study_app/l10n/app_localizations.dart';
import 'package:flutter_study_app/core/providers/locale_provider.dart';
import 'package:flutter_study_app/features/profile/presentation/pages/language_settings_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Locale and AppLanguage Registry Tests', () {
    test('AppLanguages.supported includes en, om, am, ar', () {
      final codes = AppLanguages.supported.map((l) => l.code).toList();
      expect(codes, containsAll(['en', 'om', 'am', 'ar']));
      expect(codes.length, 4);
    });

    test('Arabic is marked as RTL, others as LTR', () {
      final ar = AppLanguages.fromCode('ar');
      expect(ar.isRtl, isTrue);

      final en = AppLanguages.fromCode('en');
      expect(en.isRtl, isFalse);

      final om = AppLanguages.fromCode('om');
      expect(om.isRtl, isFalse);

      final am = AppLanguages.fromCode('am');
      expect(am.isRtl, isFalse);
    });

    test(
      'All locales load their respective AppLocalizations correctly',
      () async {
        for (final code in ['en', 'om', 'am', 'ar']) {
          final loc = await AppLocalizations.delegate.load(Locale(code));
          expect(loc.appName, 'FamilyGuard');
          expect(loc.home.isNotEmpty, isTrue);
          expect(loc.control.isNotEmpty, isTrue);
          expect(loc.location.isNotEmpty, isTrue);
          expect(loc.requests.isNotEmpty, isTrue);
          expect(loc.alerts.isNotEmpty, isTrue);
          expect(loc.profile.isNotEmpty, isTrue);
          expect(loc.settings.isNotEmpty, isTrue);
          expect(loc.signOut.isNotEmpty, isTrue);
          expect(loc.appLanguage.isNotEmpty, isTrue);
          expect(loc.chooseLanguage.isNotEmpty, isTrue);
        }
      },
    );
  });

  group('LanguageSettingsPage Widget Tests', () {
    testWidgets('Renders all 4 language options and allows switching', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('om'),
              Locale('am'),
              Locale('ar'),
            ],
            home: const LanguageSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify native names are present
      expect(find.text('English'), findsWidgets);
      expect(find.text('Afaan Oromoo'), findsOneWidget);
      expect(find.text('አማርኛ'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);

      // Verify cards can be tapped
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
    });
  });
}
