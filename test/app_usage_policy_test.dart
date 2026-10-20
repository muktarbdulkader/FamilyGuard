import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/app_info.dart';

void main() {
  AppInfo createApp({required int? bonusMinutes, required String? bonusDate}) {
    final now = DateTime(2026, 10, 20, 12);
    return AppInfo(
      packageName: 'com.example.video',
      name: 'Video',
      rule: AppControlRule.timeLimited,
      dailyLimitMinutes: 60,
      usageAlertThresholdPercent: 50,
      dailyLimitBonusMinutes: bonusMinutes ?? 0,
      dailyLimitBonusDate: bonusDate,
      detectedAt: now,
      updatedAt: now,
    );
  }

  test('extra minutes extend only the matching local day allowance', () {
    final app = createApp(bonusMinutes: 15, bonusDate: '2026-10-20');

    expect(app.effectiveDailyLimit(DateTime(2026, 10, 20, 23, 59)), 75);
    expect(app.effectiveDailyLimit(DateTime(2026, 10, 21)), 60);
  });

  test('unconfigured alert thresholds default to fifty percent', () {
    final app = createApp(bonusMinutes: null, bonusDate: null);
    expect(app.usageAlertThresholdPercent, 50);
  });
}
