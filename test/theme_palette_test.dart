import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/theme/app_colors.dart';
import 'package:flutter_study_app/core/theme/app_theme.dart';

void main() {
  testWidgets('app palette follows the active light and dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(const _ThemeHarness());

    expect(
      find.text(AppColors.dark.background.value.toString()),
      findsOneWidget,
    );

    tester
        .state<_ThemeHarnessState>(find.byType(_ThemeHarness))
        .setMode(ThemeMode.light);
    await tester.pumpAndSettle();

    expect(
      find.text(AppColors.light.background.value.toString()),
      findsOneWidget,
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
      home: Builder(
        builder: (context) {
          final background = AppColors.of(context).background;
          return Scaffold(
            body: Center(child: Text(background.value.toString())),
          );
        },
      ),
    );
  }
}
