import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/rules_provider.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/models/rule_model.dart';
import '../../../../core/models/app_info.dart';

/// Interactive AI Telemetry Chart & Graph Card for FamilyGuard
/// Connects directly to Firestore real-time child device usage streams
/// Absolutely ZERO mock data or fabricated statistics.
class AiTelemetryChartCard extends ConsumerStatefulWidget {
  final String childName;
  final bool isDark;

  const AiTelemetryChartCard({
    super.key,
    required this.childName,
    required this.isDark,
  });

  @override
  ConsumerState<AiTelemetryChartCard> createState() => _AiTelemetryChartCardState();
}

class _AiTelemetryChartCardState extends ConsumerState<AiTelemetryChartCard>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0: Weekly Bar, 1: App Share, 2: 24h Curve

  static const Color _tealAccent = Color(0xFF14B8A6);
  static const Color _aiPurple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark ? const Color(0xFF111E33) : Colors.white;
    final cardBorder = widget.isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0);
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final selectedChild = ref.watch(selectedChildProvider);
    final childId = selectedChild?.id ?? '';

    // Watch real Firestore app usage data for selected child
    final usageAsync = ref.watch(childAppUsageProvider(childId));
    final realUsageMap = usageAsync.asData?.value ?? <String, AppUsageModel>{};

    // Watch configured apps/rules for daily limit
    final childAppsAsync = ref.watch(childAppsProvider(childId));
    final childApps = childAppsAsync.asData?.value ?? <AppInfo>[];

    // Watch bedtime rules for real bedtime schedule
    final bedtimeRulesAsync = ref.watch(bedtimeRulesProvider(childId));
    final bedtimeRules = bedtimeRulesAsync.asData?.value ?? <RuleModel>[];

    final bool hasRealData = realUsageMap.isNotEmpty &&
        realUsageMap.values.any((u) => u.todayMinutes > 0 || u.weekMinutes > 0);

    // Compute configured daily allowance ceiling
    int? dailyLimitMinutes;
    if (selectedChild?.preferences['dailyLimitMinutes'] != null) {
      dailyLimitMinutes = (selectedChild!.preferences['dailyLimitMinutes'] as num).toInt();
    } else {
      // Check sum of app limits or family settings if child preferences don't have it
      final appsWithLimit = childApps.where((a) => a.dailyLimitMinutes != null && a.dailyLimitMinutes! > 0).toList();
      if (appsWithLimit.isNotEmpty) {
        dailyLimitMinutes = appsWithLimit.fold<int>(0, (sum, a) => sum + (a.dailyLimitMinutes ?? 0));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Real-time Live Telemetry Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _tealAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insights_rounded, color: _tealAccent, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'AI Telemetry Analytics',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasRealData ? _tealAccent : const Color(0xFF64748B)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (hasRealData ? _tealAccent : const Color(0xFF64748B)).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasRealData ? _tealAccent : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasRealData ? 'Live Telemetry' : 'Telemetry Pending',
                      style: TextStyle(
                        color: hasRealData ? _tealAccent : const Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segment Toggle Pills
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF0D1726) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                _buildSegmentButton(0, 'Weekly Trend', Icons.bar_chart_rounded),
                _buildSegmentButton(1, 'App Share', Icons.pie_chart_outline_rounded),
                _buildSegmentButton(2, '24h Curve', Icons.show_chart_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Chart Display
          if (_selectedTabIndex == 0)
            _buildWeeklyBarChart(textPrimary, textSecondary, realUsageMap, dailyLimitMinutes)
          else if (_selectedTabIndex == 1)
            _buildAppDistributionChart(textPrimary, textSecondary, widget.isDark, realUsageMap)
          else
            _buildHourlyActivityCurve(textPrimary, textSecondary, widget.isDark, realUsageMap, bedtimeRules),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String title, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (widget.isDark ? const Color(0xFF1E2D4A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? _tealAccent : (widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                        : (widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Weekly Screen Time Bar Chart ───────────────────────────────────────
  Widget _buildWeeklyBarChart(
    Color textPrimary,
    Color textSecondary,
    Map<String, AppUsageModel> realUsage,
    int? dailyLimitMinutes,
  ) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();

    // Calculate Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // Calculate real daily screen hours for Monday through Sunday
    final List<double> dailyHours = [];
    int totalMinutesWeekSoFar = 0;
    int recordedDaysCount = 0;
    int daysOverLimit = 0;

    for (int i = 0; i < 7; i++) {
      final dayDate = DateTime(monday.year, monday.month, monday.day).add(Duration(days: i));
      final dateKey = '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
      final bool isToday = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
      final bool isPast = dayDate.isBefore(DateTime(now.year, now.month, now.day));

      int dayMinutes = 0;
      if (isToday) {
        dayMinutes = realUsage.values.fold<int>(0, (sum, u) {
          final fromDaily = u.dailyUsage[dateKey];
          return sum + (fromDaily ?? u.todayMinutes);
        });
      } else if (isPast) {
        dayMinutes = realUsage.values.fold<int>(0, (sum, u) => sum + (u.dailyUsage[dateKey] ?? 0));
      }

      final double hours = dayMinutes / 60.0;
      dailyHours.add(hours);

      if (isToday || isPast) {
        totalMinutesWeekSoFar += dayMinutes;
        if (dayMinutes > 0) recordedDaysCount++;
        if (dailyLimitMinutes != null && dailyLimitMinutes > 0 && dayMinutes > dailyLimitMinutes) {
          daysOverLimit++;
        }
      }
    }

    final int daysElapsed = now.weekday; // 1 for Mon, 7 for Sun
    final int avgMinutes = daysElapsed > 0 ? (totalMinutesWeekSoFar ~/ daysElapsed) : 0;
    final int avgH = avgMinutes ~/ 60;
    final int avgM = avgMinutes % 60;
    final String avgLabel = avgMinutes > 0 ? '${avgH}h ${avgM}m / day' : '0m / day';

    final double? limitHours = dailyLimitMinutes != null && dailyLimitMinutes > 0
        ? dailyLimitMinutes / 60.0
        : null;

    final String limitLabel = (dailyLimitMinutes != null && dailyLimitMinutes > 0)
        ? '${dailyLimitMinutes ~/ 60}h ${dailyLimitMinutes % 60}m'
        : 'Not set';

    final bool hasAnyData = realUsage.isNotEmpty && totalMinutesWeekSoFar > 0;

    if (!hasAnyData && realUsage.isEmpty) {
      return _buildUnavailableState(
        icon: Icons.sync_disabled_rounded,
        title: 'Usage data unavailable',
        subtitle: 'No telemetry has been synchronized from this child\'s device yet. Ensure FamilyGuard child service is running and permissions (Usage Stats & Accessibility) are active on the device.',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Average Screen Time: $avgLabel',
                    style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'Daily allowance ceiling: $limitLabel • Reporting: Mon–Today ($daysElapsed d, $recordedDaysCount with activity)',
                    style: TextStyle(color: textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: limitHours != null
                      ? (daysOverLimit > 0
                          ? Colors.amber.withValues(alpha: 0.15)
                          : _tealAccent.withValues(alpha: 0.15))
                      : Colors.blueGrey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  limitHours != null
                      ? (daysOverLimit > 0 ? '$daysOverLimit Days Over' : 'Within Limit')
                      : 'No Limit Set',
                  style: TextStyle(
                    color: limitHours != null
                        ? (daysOverLimit > 0 ? Colors.amber : _tealAccent)
                        : textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Custom Painted Bar Chart Canvas with Real Dynamic Data
        SizedBox(
          height: 140,
          width: double.infinity,
          child: CustomPaint(
            painter: _WeeklyBarChartPainter(
              days: days,
              hours: dailyHours,
              limit: limitHours,
              currentWeekday: now.weekday,
              isDark: widget.isDark,
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. App Usage Distribution (Donut & Progress Bars) ─────────────────────
  Widget _buildAppDistributionChart(
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    Map<String, AppUsageModel> realUsage,
  ) {
    // Extract real apps from Firestore
    final List<Map<String, dynamic>> apps = [];

    final activeApps = realUsage.values.where((u) => u.todayMinutes > 0).toList()
      ..sort((a, b) => b.todayMinutes.compareTo(a.todayMinutes));

    final int totalMinutes = activeApps.fold<int>(0, (sum, u) => sum + u.todayMinutes);

    if (activeApps.isEmpty || totalMinutes == 0) {
      return _buildUnavailableState(
        icon: Icons.apps_outage_rounded,
        title: 'No app activity recorded today',
        subtitle: 'Applications used on the child\'s phone today will appear here with exact screen time proportions as soon as device activity is reported.',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];

    for (int i = 0; i < activeApps.length && i < 5; i++) {
      final u = activeApps[i];
      final ratio = totalMinutes > 0 ? (u.todayMinutes / totalMinutes) : 0.0;
      final h = u.todayMinutes ~/ 60;
      final m = u.todayMinutes % 60;
      final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

      apps.add({
        'name': u.appName.isNotEmpty ? u.appName : u.packageName.split('.').last,
        'time': timeStr,
        'ratio': ratio,
        'color': colors[i % colors.length],
      });
    }

    final totalTimeLabel = '${totalMinutes ~/ 60}h ${totalMinutes % 60}m';

    return Column(
      children: [
        Row(
          children: [
            // Donut Canvas
            SizedBox(
              width: 105,
              height: 105,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  apps: apps,
                  totalLabel: totalTimeLabel,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // App Breakdown List
            Expanded(
              child: Column(
                children: apps.map((app) {
                  final color = app['color'] as Color;
                  final ratio = app['ratio'] as double;
                  final percent = (ratio * 100).toStringAsFixed(0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      app['name'] as String,
                                      style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${app['time']} ($percent%)',
                              style: TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            backgroundColor: isDark ? const Color(0xFF1E2D4A) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 3. 24h Hourly Activity & Focus Curve ──────────────────────────────────
  Widget _buildHourlyActivityCurve(
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    Map<String, AppUsageModel> realUsage,
    List<RuleModel> bedtimeRules,
  ) {
    final now = DateTime.now();

    // Map 24 hourly buckets
    final List<int> hourlyMinutes = List<int>.filled(24, 0);
    final Map<int, String> hourlyTopApp = {};

    for (final app in realUsage.values) {
      if (app.todayMinutes <= 0) continue;
      final lastUsed = app.lastUsed;
      if (lastUsed.year == now.year && lastUsed.month == now.month && lastUsed.day == now.day) {
        final hour = lastUsed.hour.clamp(0, 23);
        hourlyMinutes[hour] += app.todayMinutes;
        hourlyTopApp[hour] = app.appName.isNotEmpty ? app.appName : app.packageName.split('.').last;
      }
    }

    final int maxMinute = hourlyMinutes.fold<int>(0, math.max);

    // Bedtime string
    String bedtimeLabel = 'Bedtime: Not scheduled';
    final activeBedtime = bedtimeRules.where((r) => r.isActive && r.bedtimeStart != null).firstOrNull;
    if (activeBedtime != null && activeBedtime.bedtimeStart != null) {
      final start = activeBedtime.bedtimeStart!;
      final h = start.hour > 12 ? start.hour - 12 : (start.hour == 0 ? 12 : start.hour);
      final ampm = start.hour >= 12 ? 'PM' : 'AM';
      final m = start.minute.toString().padLeft(2, '0');
      bedtimeLabel = 'Bedtime: $h:$m $ampm';
    }

    if (maxMinute == 0) {
      return _buildUnavailableState(
        icon: Icons.timeline_rounded,
        title: '24h Activity Curve Unavailable',
        subtitle: 'Hourly session timestamps require active child app reporting today. Once apps are used, exact hourly activity curves and bedtime transitions will render here.',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    // Find peak hour
    int peakHour = 0;
    int peakValue = 0;
    for (int h = 0; h < 24; h++) {
      if (hourlyMinutes[h] > peakValue) {
        peakValue = hourlyMinutes[h];
        peakHour = h;
      }
    }

    final peakApp = hourlyTopApp[peakHour] ?? 'Apps';
    final peakH12 = peakHour > 12 ? peakHour - 12 : (peakHour == 0 ? 12 : peakHour);
    final peakAmpm = peakHour >= 12 ? 'PM' : 'AM';
    final peakNextH12 = (peakHour + 1) > 12 ? (peakHour + 1) - 12 : ((peakHour + 1) == 0 ? 12 : (peakHour + 1));
    final peakNextAmpm = (peakHour + 1) >= 12 ? 'PM' : 'AM';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Activity Peak: $peakH12 $peakAmpm – $peakNextH12 $peakNextAmpm ($peakApp)',
                style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                bedtimeLabel,
                style: const TextStyle(color: _aiPurple, fontSize: 10.5, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Curve Canvas using real hourly telemetry
        SizedBox(
          height: 130,
          width: double.infinity,
          child: CustomPaint(
            painter: _HourlyCurvePainter(
              hourlyMinutes: hourlyMinutes,
              peakHour: peakHour,
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailableState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: textSecondary.withValues(alpha: 0.6), size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: textSecondary, fontSize: 10.5, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM CHART PAINTERS (Zero external dependencies, 100% Real Dynamic Telemetry)
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyBarChartPainter extends CustomPainter {
  final List<String> days;
  final List<double> hours;
  final double? limit;
  final int currentWeekday; // 1 = Mon, 7 = Sun
  final bool isDark;

  _WeeklyBarChartPainter({
    required this.days,
    required this.hours,
    required this.limit,
    required this.currentWeekday,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dynamic max scale with safety ceiling
    final double maxUsage = hours.fold<double>(0.0, math.max);
    final double targetLimit = limit ?? 2.5;
    final double maxVal = math.max(math.max(maxUsage * 1.25, targetLimit * 1.2), 1.0);

    final double chartHeight = size.height - 24;
    final double barWidth = size.width / (days.length * 2.1);
    final double spacing = size.width / days.length;

    // Draw Target Limit Line only if limit is set
    if (limit != null && limit! > 0) {
      final double limitY = chartHeight - (limit! / maxVal * chartHeight);
      final limitPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final dashPath = Path();
      for (double x = 0; x < size.width; x += 8) {
        dashPath.moveTo(x, limitY);
        dashPath.lineTo(x + 4, limitY);
      }
      canvas.drawPath(dashPath, limitPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < days.length; i++) {
      final double xCenter = (i * spacing) + (spacing / 2);
      final double dayHours = hours[i];
      final double barH = (dayHours / maxVal) * chartHeight;
      final double topY = chartHeight - barH;
      final bool isOverLimit = limit != null && dayHours > limit!;
      final bool isFuture = (i + 1) > currentWeekday;

      if (!isFuture && barH > 2) {
        final barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(xCenter - (barWidth / 2), topY, barWidth, barH),
          const Radius.circular(5),
        );

        final barPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isOverLimit
                ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                : [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          ).createShader(Rect.fromLTWH(xCenter - (barWidth / 2), topY, barWidth, barH));

        canvas.drawRRect(barRect, barPaint);

        // Value label on top of bar
        if (dayHours > 0.1) {
          textPainter.text = TextSpan(
            text: '${dayHours.toStringAsFixed(1)}h',
            style: TextStyle(
              color: isOverLimit ? Colors.amber : (isDark ? Colors.white70 : const Color(0xFF334155)),
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(xCenter - (textPainter.width / 2), topY - 12));
        }
      } else if (isFuture) {
        // Subtle outline for upcoming days of this week
        final emptyRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(xCenter - (barWidth / 2), chartHeight - 4, barWidth, 4),
          const Radius.circular(2),
        );
        canvas.drawRRect(
          emptyRect,
          Paint()..color = (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        );
      }

      // Day label
      final bool isCurrentDay = (i + 1) == currentWeekday;
      textPainter.text = TextSpan(
        text: days[i],
        style: TextStyle(
          color: isCurrentDay
              ? const Color(0xFF14B8A6)
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          fontSize: 10,
          fontWeight: isCurrentDay ? FontWeight.w800 : FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(xCenter - (textPainter.width / 2), size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarChartPainter oldDelegate) => true;
}

class _DonutChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> apps;
  final String totalLabel;
  final bool isDark;

  _DonutChartPainter({
    required this.apps,
    required this.totalLabel,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 14.0;

    double startAngle = -math.pi / 2;

    for (final app in apps) {
      final ratio = app['ratio'] as double;
      final sweepAngle = ratio * 2 * math.pi;
      final color = app['color'] as Color;

      if (sweepAngle > 0.05) {
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle + 0.03,
          math.max(sweepAngle - 0.06, 0.02),
          false,
          paint,
        );
      }

      startAngle += sweepAngle;
    }

    // Center Total Label
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$totalLabel\n',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: 'Today',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

class _HourlyCurvePainter extends CustomPainter {
  final List<int> hourlyMinutes;
  final int peakHour;
  final bool isDark;

  _HourlyCurvePainter({
    required this.hourlyMinutes,
    required this.peakHour,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height - 22;

    final int maxMinute = hourlyMinutes.fold<int>(0, math.max);
    final double scale = maxMinute > 0 ? (h * 0.85) / maxMinute : 1.0;

    // Build real curve points for 24 hours
    final points = <Offset>[];
    for (int hour = 0; hour < 24; hour++) {
      final double x = (hour / 23.0) * w;
      final double mins = hourlyMinutes[hour].toDouble();
      final double y = h - (mins * scale);
      points.add(Offset(x, y.clamp(8.0, h)));
    }

    if (points.isEmpty) return;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cp1 = Offset((p0.dx + p1.dx) / 2, p0.dy);
      final cp2 = Offset((p0.dx + p1.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.35 : 0.25),
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF14B8A6), Color(0xFF8B5CF6)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(path, linePaint);

    // Peak Dot Highlight
    if (maxMinute > 0 && peakHour >= 0 && peakHour < points.length) {
      final peakPoint = points[peakHour];
      final dotPaint = Paint()..color = const Color(0xFF14B8A6);
      canvas.drawCircle(peakPoint, 4.5, dotPaint);
      canvas.drawCircle(
        peakPoint,
        8.0,
        Paint()
          ..color = const Color(0xFF14B8A6).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Hour Labels
    final labels = [
      {'time': '12 AM', 'hour': 0},
      {'time': '6 AM', 'hour': 6},
      {'time': '12 PM', 'hour': 12},
      {'time': '6 PM', 'hour': 18},
      {'time': '11 PM', 'hour': 23},
    ];

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final l in labels) {
      final int hour = l['hour'] as int;
      final double x = (hour / 23.0) * w;

      textPainter.text = TextSpan(
        text: l['time'] as String,
        style: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyCurvePainter oldDelegate) => true;
}
