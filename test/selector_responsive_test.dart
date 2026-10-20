import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/family_model.dart';
import 'package:flutter_study_app/features/parent/presentation/widgets/child_selector.dart';
import 'package:flutter_study_app/features/parent/presentation/widgets/family_selector.dart';

void main() {
  testWidgets('family selector fits a narrow dashboard column', (tester) async {
    final now = DateTime.now();
    final family = FamilyModel(
      id: 'family-id',
      name: 'A family name that is long enough to need truncation',
      createdBy: 'parent-id',
      parentIds: const ['parent-id'],
      childIds: const ['child-id', 'another-child-id', 'third-child-id'],
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: FamilySelector(
                families: [family],
                selectedFamily: family,
                onFamilySelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('child selector fits a narrow dashboard column', (tester) async {
    final now = DateTime.now();
    final child = ChildModel(
      id: 'child-id',
      displayName: 'A child name that is long enough to need truncation',
      email: 'child@example.com',
      familyId: 'family-id',
      joinedAt: now,
      lastActiveAt: now,
      isOnline: true,
      deviceInfo: 'A long device name that should truncate instead of overflow',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: ChildSelector(
                children: [child],
                selectedChild: child,
                onChildSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
