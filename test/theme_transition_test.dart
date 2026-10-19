import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/theme/app_theme.dart';

void main() {
  test('light and dark themes can be interpolated during theme changes', () {
    expect(
      () => ThemeData.lerp(AppTheme.darkTheme, AppTheme.lightTheme, 0.5),
      returnsNormally,
    );
  });
}
