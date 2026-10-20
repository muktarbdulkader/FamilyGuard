import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_study_app/core/providers/notification_provider.dart';
import 'package:flutter_study_app/core/widgets/family_bottom_navigation.dart';
import 'package:flutter_study_app/l10n/app_localizations.dart';

void main() {
  testWidgets('parent navigation switches between controls and alerts', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/parent-home',
      routes: [
        GoRoute(
          path: '/parent-home',
          builder: (context, state) => const _ParentPage(
            title: 'Parent Home',
            selected: FamilyNavDestination.home,
          ),
        ),
        GoRoute(
          path: '/parent-apps',
          builder: (context, state) => const _ParentPage(
            title: 'Family Controls',
            selected: FamilyNavDestination.apps,
          ),
        ),
        GoRoute(
          path: '/parent-location',
          builder: (context, state) => const _ParentPage(
            title: 'Location',
            selected: FamilyNavDestination.location,
          ),
        ),
        GoRoute(
          path: '/parent-requests',
          builder: (context, state) => const _ParentPage(
            title: 'Requests',
            selected: FamilyNavDestination.requests,
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const _ParentPage(
            title: 'Notifications',
            selected: FamilyNavDestination.notifications,
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const _ParentPage(
            title: 'Profile',
            selected: FamilyNavDestination.profile,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [unreadNotificationCountProvider.overrideWithValue(3)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parent Home'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Control'));
    await tester.pumpAndSettle();
    expect(find.text('Family Controls'), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('child navigation opens device monitoring and apps', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/child-status',
      routes: [
        GoRoute(
          path: '/child-status',
          builder: (context, state) => const _ChildPage(
            title: 'Device Monitoring',
            selected: FamilyNavDestination.health,
          ),
        ),
        GoRoute(
          path: '/child-apps',
          builder: (context, state) => const _ChildPage(
            title: 'Child Apps',
            selected: FamilyNavDestination.apps,
          ),
        ),
        GoRoute(
          path: '/child-home',
          builder: (context, state) => const _ChildPage(
            title: 'Child Home',
            selected: FamilyNavDestination.home,
          ),
        ),
        GoRoute(
          path: '/child-permissions',
          builder: (context, state) => const _ChildPage(
            title: 'Setup',
            selected: FamilyNavDestination.setup,
          ),
        ),
        GoRoute(
          path: '/child-education',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return _ChildPage(
              title: 'Child Learning ${extra?['childName']}',
              selected: FamilyNavDestination.lessons,
            );
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const _ChildPage(
            title: 'Profile',
            selected: FamilyNavDestination.profile,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Device Monitoring'), findsOneWidget);
    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    expect(find.text('Child Apps'), findsOneWidget);

    await tester.tap(find.text('Lessons'));
    await tester.pumpAndSettle();
    expect(find.text('Child Learning Child'), findsOneWidget);
  });
}

class _ParentPage extends StatelessWidget {
  const _ParentPage({required this.title, required this.selected});

  final String title;
  final FamilyNavDestination selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(title)),
      bottomNavigationBar: FamilyBottomNavigation(
        isParent: true,
        selected: selected,
      ),
    );
  }
}

class _ChildPage extends StatelessWidget {
  const _ChildPage({required this.title, required this.selected});

  final String title;
  final FamilyNavDestination selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(title)),
      bottomNavigationBar: FamilyBottomNavigation(
        isParent: false,
        selected: selected,
        familyId: 'family-1',
        childId: 'child-1',
        childName: 'Child',
      ),
    );
  }
}
