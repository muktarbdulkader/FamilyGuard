import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/app_info.dart';
import 'package:flutter_study_app/core/providers/family_provider.dart';
import 'package:flutter_study_app/core/providers/notification_provider.dart';
import 'package:flutter_study_app/features/apps/presentation/screens/parent_app_management_screen.dart';
import 'package:flutter_study_app/features/parent/presentation/screens/parent_dashboard_screen.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

void main() {
  testWidgets('app list remains scrollable when system apps are hidden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2025);
    final apps = [
      AppInfo(
        packageName: 'com.example.regular',
        name: 'Regular App',
        rule: AppControlRule.allow,
        detectedAt: now,
        updatedAt: now,
      ),
      AppInfo(
        packageName: 'com.example.system',
        name: 'System App',
        rule: AppControlRule.allow,
        detectedAt: now,
        updatedAt: now,
        isSystemApp: true,
      ),
      ...List.generate(
        8,
        (index) => AppInfo(
          packageName: 'com.example.regular${index + 1}',
          name: 'Regular App ${index + 1}',
          rule: AppControlRule.allow,
          detectedAt: now,
          updatedAt: now,
        ),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyChildAppsProvider.overrideWith(
            (ref, params) => Stream.value(apps),
          ),
          familyChildAppUsageProvider.overrideWith(
            (ref, params) => Stream.value({}),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: ParentAppManagementScreen(
            familyId: 'family-1',
            childId: 'child-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Regular App'), findsOneWidget);
    expect(find.text('System App'), findsOneWidget);

    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide System Apps'));
    await tester.pumpAndSettle();

    expect(find.text('Regular App'), findsOneWidget);
    expect(find.text('System App'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Regular App 8'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Regular App 8'), findsOneWidget);
    final layoutException = tester.takeException();
    expect(layoutException, isNull, reason: '$layoutException');
  });

  testWidgets('family controls keeps tabs visible on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userFamiliesProvider.overrideWith((ref) => Stream.value([])),
          familyChildrenProvider.overrideWith((ref) => Stream.value([])),
          unreadNotificationCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: ParentDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apps'), findsOneWidget);
    expect(find.text('Usage'), findsOneWidget);
    expect(find.text('Location'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

}
