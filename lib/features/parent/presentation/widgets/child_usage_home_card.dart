import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// Shared helper to format minutes cleanly as "2h 20m" or "45m".
String formatUsageMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Categorize an app into a human-readable usage category from package/app name.
String categorizeAppUsage(String packageName, String appName) {
  final p = '$packageName $appName'.toLowerCase();
  if (p.contains('whatsapp') ||
      p.contains('facebook') ||
      p.contains('instagram') ||
      p.contains('snapchat') ||
      p.contains('telegram') ||
      p.contains('messenger') ||
      p.contains('twitter') ||
      p.contains('discord') ||
      p.contains('tiktok') ||
      p.contains('musically')) {
    return 'Social Networking';
  }
  if (p.contains('game') ||
      p.contains('roblox') ||
      p.contains('minecraft') ||
      p.contains('pubg') ||
      p.contains('freefire') ||
      p.contains('brawl') ||
      p.contains('clash') ||
      p.contains('play.games')) {
    return 'Games';
  }
  if (p.contains('youtube') ||
      p.contains('netflix') ||
      p.contains('spotify') ||
      p.contains('twitch') ||
      p.contains('disney') ||
      p.contains('primevideo') ||
      p.contains('video') ||
      p.contains('music')) {
    return 'Entertainment';
  }
  if (p.contains('classroom') ||
      p.contains('duolingo') ||
      p.contains('khan') ||
      p.contains('study') ||
      p.contains('docs') ||
      p.contains('chrome') ||
      p.contains('browser')) {
    return 'Education & Web';
  }
  return 'Other Apps';
}

/// Home screen card replacing About FamilyGuard: shows real child app usage
/// summary (total today, mini bar chart, top apps) and opens [AppUsageOverviewScreen].
class ChildUsageHomeCard extends ConsumerWidget {
  const ChildUsageHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorsProvider);
    final user = ref.watch(currentUserDataProvider).value;
    final family = ref.watch(selectedFamilyProvider);
    final familyId = (family != null && family.id.isNotEmpty)
        ? family.id
        : (user?.familyId ?? '');

    final children =
        ref.watch(familyChildrenProvider).value ?? const <ChildModel>[];
    final selectedChild = ref.watch(selectedChildProvider);
    final activeChild =
        selectedChild ?? (children.isNotEmpty ? children.first : null);

    if (familyId.isEmpty || activeChild == null) {
      return const SizedBox.shrink();
    }

    final usageMap =
        ref
            .watch(
              familyChildAppUsageProvider(
                FamilyChildParams(familyId: familyId, childId: activeChild.id),
              ),
            )
            .value ??
        const <String, AppUsageModel>{};

    final activeUsages = usageMap.values
        .where((u) => u.todayMinutes > 0)
        .toList()
      ..sort((a, b) => b.todayMinutes.compareTo(a.todayMinutes));

    final totalMinutes = activeUsages.fold<int>(
      0,
      (sum, item) => sum + item.todayMinutes,
    );

    // Build 6 4-hour buckets (00-04, 04-08, 08-12, 12-16, 16-20, 20-24)
    final buckets = List<int>.filled(6, 0);
    for (final u in activeUsages) {
      final bucket = (u.lastUsed.hour ~/ 4).clamp(0, 5);
      buckets[bucket] += u.todayMinutes;
    }
    final maxBucket = buckets.reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push(
            '${AppRoutes.childUsage}/${Uri.encodeComponent(activeChild.id)}/${Uri.encodeComponent(activeChild.displayName)}?familyId=${Uri.encodeComponent(familyId)}',
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Title + Total Usage Pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        color: colors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total App Usage',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${activeChild.displayName} · Today',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatUsageMinutes(totalMinutes),
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Mini 6-bucket usage bar preview
                SizedBox(
                  height: 44,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(6, (i) {
                      final val = buckets[i];
                      final ratio = maxBucket > 0 ? (val / maxBucket) : 0.0;
                      final barH = val > 0 ? (10 + 30 * ratio) : 6.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                height: barH,
                                width: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: val > 0
                                      ? LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            colors.primary,
                                            colors.accent,
                                          ],
                                        )
                                      : null,
                                  color: val > 0
                                      ? null
                                      : colors.border.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom row: Top apps summary + chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activeUsages.isEmpty
                            ? 'No app usage recorded today yet'
                            : activeUsages
                                .take(2)
                                .map(
                                  (u) =>
                                      '${u.appName.isNotEmpty ? u.appName : u.packageName} (${formatUsageMinutes(u.todayMinutes)})',
                                )
                                .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
