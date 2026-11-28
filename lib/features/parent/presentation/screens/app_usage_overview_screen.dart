import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/app_info.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon_widget.dart';
import '../widgets/child_usage_home_card.dart';

/// Detailed App Usage overview screen for a child, matching the stacked-bar
/// chart + Most Used By Categories + Most Used By Apps layout using [AppColors].
class AppUsageOverviewScreen extends ConsumerWidget {
  final String familyId;
  final String childId;
  final String childName;

  const AppUsageOverviewScreen({
    super.key,
    required this.familyId,
    required this.childId,
    required this.childName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorsProvider);
    final params = FamilyChildParams(familyId: familyId, childId: childId);
    final usageAsync = ref.watch(familyChildAppUsageProvider(params));
    final appsAsync = ref.watch(familyChildAppsProvider(params));

    final usageMap = usageAsync.value ?? const <String, AppUsageModel>{};
    final appsList = appsAsync.value ?? const <AppInfo>[];
    final appByPkg = {for (final a in appsList) a.packageName: a};

    final activeUsages = usageMap.values
        .where((u) => u.todayMinutes > 0)
        .toList()
      ..sort((a, b) => b.todayMinutes.compareTo(a.todayMinutes));

    final totalMinutes = activeUsages.fold<int>(
      0,
      (sum, item) => sum + item.todayMinutes,
    );

    // Group into 6 4-hour buckets (00-04 .. 20-24) split by category
    final bucketCategoryMinutes = List.generate(
      6,
      (_) => <String, int>{},
    );
    final categoryTotals = <String, int>{};

    for (final u in activeUsages) {
      final cat = categorizeAppUsage(u.packageName, u.appName);
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + u.todayMinutes;
      final bucket = (u.lastUsed.hour ~/ 4).clamp(0, 5);
      bucketCategoryMinutes[bucket][cat] =
          (bucketCategoryMinutes[bucket][cat] ?? 0) + u.todayMinutes;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final nonZeroBuckets = bucketCategoryMinutes
        .where((b) => b.values.fold<int>(0, (s, v) => s + v) > 0)
        .length;
    final avgBucketMinutes =
        nonZeroBuckets > 0 ? (totalMinutes / nonZeroBuckets).round() : 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Usage',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              childName,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: usageAsync.isLoading && usageMap.isEmpty
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Card 1: Total App Usage & Bar Chart ──────────────────
                _SectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.bar_chart_rounded,
                              color: colors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Total App Usage',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            formatUsageMinutes(totalMinutes),
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Stacked vertical bar chart (00 .. 24)
                      _UsageBarChart(
                        colors: colors,
                        bucketCategoryMinutes: bucketCategoryMinutes,
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: colors.border),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active period average usage',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            formatUsageMinutes(avgBucketMinutes),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Card 2: Most Used By Categories ──────────────────────
                _SectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most Used By Categories',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (sortedCategories.isEmpty)
                        _EmptyHint(
                          colors: colors,
                          text: 'No category usage recorded today.',
                        )
                      else
                        ...sortedCategories.map((entry) {
                          final (icon, catColor) = _categoryStyle(
                            entry.key,
                            colors,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: catColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        formatUsageMinutes(entry.value),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: colors.textMuted,
                                  size: 20,
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Card 3: Most Used By Apps ────────────────────────────
                _SectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most Used By Apps',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (activeUsages.isEmpty)
                        _EmptyHint(
                          colors: colors,
                          text: 'No app usage recorded today.',
                        )
                      else
                        ...activeUsages.map((usage) {
                          final appInfo = appByPkg[usage.packageName];
                          final displayTitle = usage.appName.isNotEmpty
                              ? usage.appName
                              : (appInfo?.name ?? usage.packageName);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.push(
                              '/parent-apps/${Uri.encodeComponent(childId)}/${Uri.encodeComponent(childName)}?familyId=${Uri.encodeComponent(familyId)}&packageName=${Uri.encodeComponent(usage.packageName)}',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  AppIconWidget(
                                    iconBase64: appInfo?.iconBase64,
                                    size: 42,
                                    borderRadius: 12,
                                    fallbackColor: colors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              formatUsageMinutes(
                                                usage.todayMinutes,
                                              ),
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            if (appInfo?.dailyLimitMinutes !=
                                                null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colors.warning
                                                      .withValues(alpha: 0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.hourglass_bottom_rounded,
                                                  size: 12,
                                                  color: colors.warning,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: colors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  (IconData, Color) _categoryStyle(String category, AppColors colors) {
    return switch (category) {
      'Social Networking' => (Icons.forum_rounded, colors.error),
      'Games' => (Icons.sports_esports_rounded, colors.warning),
      'Entertainment' => (Icons.play_circle_filled_rounded, colors.primary),
      'Education & Web' => (Icons.school_rounded, colors.success),
      _ => (Icons.apps_rounded, colors.accent),
    };
  }
}

class _SectionCard extends StatelessWidget {
  final AppColors colors;
  final Widget child;

  const _SectionCard({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final AppColors colors;
  final String text;

  const _EmptyHint({required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(color: colors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _UsageBarChart extends StatelessWidget {
  final AppColors colors;
  final List<Map<String, int>> bucketCategoryMinutes;

  const _UsageBarChart({
    required this.colors,
    required this.bucketCategoryMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final totals = bucketCategoryMinutes
        .map((b) => b.values.fold<int>(0, (s, v) => s + v))
        .toList();
    final rawMax = totals.reduce((a, b) => a > b ? a : b);
    final maxMinutes = rawMax < 60 ? 60 : ((rawMax / 60).ceil() * 60);
    final maxHoursLabel = '${maxMinutes ~/ 60}h';
    final midHoursLabel = '${(maxMinutes / 120).toStringAsFixed(maxMinutes % 120 == 0 ? 0 : 1)}h';
    const labels = ['00', '04', '08', '12', '16', '20', '24'];

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            children: [
              // Bars
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(6, (i) {
                    final catMap = bucketCategoryMinutes[i];
                    final social = catMap['Social Networking'] ?? 0;
                    final games = catMap['Games'] ?? 0;
                    final ent = catMap['Entertainment'] ?? 0;
                    final other =
                        (catMap['Education & Web'] ?? 0) +
                        (catMap['Other Apps'] ?? 0);
                    final total = social + games + ent + other;
                    final barTotalH = total > 0
                        ? (120 * (total / maxMinutes)).clamp(8.0, 120.0)
                        : 6.0;

                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? colors.background.withValues(alpha: 0.65)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 4),
                        child: total == 0
                            ? Container(
                                width: 10,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.border.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 10,
                                  height: barTotalH,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (other > 0)
                                        Expanded(
                                          flex: other,
                                          child: Container(
                                            color: colors.success,
                                          ),
                                        ),
                                      if (ent > 0)
                                        Expanded(
                                          flex: ent,
                                          child: Container(
                                            color: colors.primary,
                                          ),
                                        ),
                                      if (games > 0)
                                        Expanded(
                                          flex: games,
                                          child: Container(
                                            color: colors.warning,
                                          ),
                                        ),
                                      if (social > 0)
                                        Expanded(
                                          flex: social,
                                          child: Container(color: colors.error),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8),
              // Y-axis labels
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    maxHoursLabel,
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                  Text(
                    midHoursLabel,
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                  Text(
                    '0h',
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(right: 26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map(
                  (l) => Text(
                    l,
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
