import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/family_model.dart';
import 'package:flutter_study_app/core/models/location_model.dart';

void main() {
  group('Child presence', () {
    final now = DateTime(2026, 10, 19, 12);

    test('a heartbeat up to seven minutes old is online', () {
      expect(
        ChildPresence.isOnlineAt(
          now.subtract(const Duration(minutes: 7)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a heartbeat older than seven minutes is offline', () {
      expect(
        ChildPresence.isOnlineAt(
          now.subtract(const Duration(minutes: 7, seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a missing or future heartbeat is not considered online', () {
      expect(ChildPresence.isOnlineAt(null, now: now), isFalse);
      expect(
        ChildPresence.isOnlineAt(now.add(const Duration(seconds: 1)), now: now),
        isFalse,
      );
    });
  });

  group('GPS freshness', () {
    test('location is considered stale after five minutes', () {
      final location = FamilyLocation(
        id: 'location',
        familyId: 'family',
        childId: 'child',
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
      );

      expect(location.isStale, isTrue);
    });

    test('location with a recent timestamp is not stale', () {
      final location = FamilyLocation(
        id: 'location',
        familyId: 'family',
        childId: 'child',
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      expect(location.isStale, isFalse);
    });
  });
}
