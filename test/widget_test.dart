// Basic widget test for the Flutter Parental Control App
// Note: Comprehensive testing will be added in later prompts

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_study_app/main.dart';

void main() {
  testWidgets('App starts and loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(
      child: ParentalControlApp(),
    ));

    // Wait for the initial route to load
    await tester.pumpAndSettle();

    // Verify that the app loads (basic smoke test)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
