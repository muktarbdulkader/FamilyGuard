import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/user_model.dart';

void main() {
  group('UserRole transitions', () {
    test('an unassigned profile can select a parent or child role', () {
      expect(UserRole.none.canTransitionTo(UserRole.parent), isTrue);
      expect(UserRole.none.canTransitionTo(UserRole.child), isTrue);
    });

    test('an assigned role cannot be changed', () {
      expect(UserRole.child.canTransitionTo(UserRole.parent), isFalse);
      expect(UserRole.parent.canTransitionTo(UserRole.child), isFalse);
      expect(UserRole.parent.canTransitionTo(UserRole.parent), isFalse);
    });

    test('an unassigned profile cannot select the unassigned role', () {
      expect(UserRole.none.canTransitionTo(UserRole.none), isFalse);
    });
  });
}
