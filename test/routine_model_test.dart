import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/routine_model.dart';

RoutineModel _routine({
  required String id,
  required String name,
  required int startHour,
  required int endHour,
  required List<int> days,
  bool active = true,
}) {
  final now = DateTime(2026, 1, 1);
  return RoutineModel(
    id: id,
    familyId: 'family',
    childId: 'child',
    name: name,
    startTime: TimeOfDay(hour: startHour, minute: 0),
    endTime: TimeOfDay(hour: endHour, minute: 0),
    daysOfWeek: days,
    isActive: active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('RoutineModel.findConflicts', () {
    test('detects an overlap on a shared day', () {
      final candidate = _routine(
        id: 'candidate',
        name: 'Study',
        startHour: 16,
        endHour: 18,
        days: [1, 3, 5],
      );
      final existing = _routine(
        id: 'existing',
        name: 'Dinner',
        startHour: 17,
        endHour: 19,
        days: [3],
      );

      expect(
        RoutineModel.findConflicts(candidate, [existing]),
        contains(contains('Dinner')),
      );
    });

    test('detects overnight overlap crossing into the next weekday', () {
      final candidate = _routine(
        id: 'candidate',
        name: 'Bedtime',
        startHour: 22,
        endHour: 6,
        days: [7],
      );
      final existing = _routine(
        id: 'existing',
        name: 'Early study',
        startHour: 2,
        endHour: 3,
        days: [1],
      );

      expect(RoutineModel.findConflicts(candidate, [existing]), hasLength(1));
    });

    test(
      'an overnight routine stays active after midnight on the next day',
      () {
        final routine = _routine(
          id: 'overnight',
          name: 'Bedtime',
          startHour: 22,
          endHour: 6,
          days: [7],
        );

        expect(
          routine.isCurrentlyActive(nowTime: DateTime(2026, 1, 5, 2)),
          isTrue,
        );
        expect(
          routine.isCurrentlyActive(nowTime: DateTime(2026, 1, 5, 6)),
          isFalse,
        );
      },
    );

    test('does not report adjacent routines or inactive routines', () {
      final candidate = _routine(
        id: 'candidate',
        name: 'Study',
        startHour: 16,
        endHour: 17,
        days: [1],
      );
      final adjacent = _routine(
        id: 'adjacent',
        name: 'Dinner',
        startHour: 17,
        endHour: 18,
        days: [1],
      );
      final inactive = _routine(
        id: 'inactive',
        name: 'Old plan',
        startHour: 16,
        endHour: 18,
        days: [1],
        active: false,
      );

      expect(
        RoutineModel.findConflicts(candidate, [adjacent, inactive]),
        isEmpty,
      );
    });
  });
}
