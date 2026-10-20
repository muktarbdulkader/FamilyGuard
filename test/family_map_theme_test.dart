import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/user_model.dart';
import 'package:flutter_study_app/core/providers/user_provider.dart';
import 'package:flutter_study_app/core/providers/notification_provider.dart';
import 'package:flutter_study_app/core/theme/app_colors.dart';
import 'package:flutter_study_app/core/theme/app_theme.dart';
import 'package:flutter_study_app/features/location/presentation/screens/family_map_screen.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

void main() {
  testWidgets('family location screen follows light and dark appearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDataProvider.overrideWith(
            (ref) => Stream<UserModel?>.value(null),
          ),
          unreadNotificationCountProvider.overrideWithValue(2),
        ],
        child: const _ThemeHarness(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.dark.background,
    );
    expect(find.text('Alerts'), findsOneWidget);

    tester
        .state<_ThemeHarnessState>(find.byType(_ThemeHarness))
        .setMode(ThemeMode.light);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.light.background,
    );
  });
}

class _ThemeHarness extends StatefulWidget {
  const _ThemeHarness();

  @override
  State<_ThemeHarness> createState() => _ThemeHarnessState();
}

class _ThemeHarnessState extends State<_ThemeHarness> {
  var _themeMode = ThemeMode.dark;

  void setMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const FamilyMapScreen(),
    );
  }
}
