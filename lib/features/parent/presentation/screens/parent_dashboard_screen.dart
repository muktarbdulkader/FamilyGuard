import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/app_info.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/geocoding_service.dart';
import '../widgets/family_selector.dart';
import '../widgets/child_selector.dart';
import '../widgets/app_usage_indicator.dart';
import '../widgets/app_rule_editor_sheet.dart';
import '../../../apps/presentation/screens/parent_app_management_screen.dart';

/// Main parent dashboard screen with family and child selection
/// Professional UI for managing parental controls
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _autoSelectDone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Auto-select first family + first child so tabs are immediately usable
  void _maybeAutoSelect(
    List<FamilyModel> families,
    FamilyModel? selectedFamily,
    List<ChildModel> children,
    ChildModel? selectedChild,
  ) {
    if (_autoSelectDone) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectedFamily == null && families.isNotEmpty) {
        ref.read(selectedFamilyProvider.notifier).state = families.first;
      }
      if (selectedChild == null && children.isNotEmpty) {
        ref.read(selectedChildProvider.notifier).state = children.first;
      }
      _autoSelectDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(userFamiliesProvider);
    final selectedFamily = ref.watch(selectedFamilyProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final childrenAsync = ref.watch(familyChildrenProvider);

    // Auto-select first family and child on load
    familiesAsync.whenData((families) {
      childrenAsync.whenData((children) {
        _maybeAutoSelect(families, selectedFamily, children, selectedChild);
      });
    });

    final effectiveFamilyId = selectedFamily?.id ?? '';
    final effectiveChildId = selectedChild?.id ?? '';
    final hasSelection = effectiveFamilyId.isNotEmpty && effectiveChildId.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Icon(Icons.family_restroom, size: 28, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Family Controls',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            Text(
                              'Parental Control Dashboard',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showSettings(),
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Family Selector
                  familiesAsync.when(
                    loading: () => const _LoadingSelector(title: 'Loading families...'),
                    error: (error, stack) => _ErrorSelector(
                      title: 'Error loading families',
                      error: error.toString(),
                    ),
                    data: (families) {
                      if (families.isEmpty) {
                        return _EmptyStateSelector(
                          title: 'No families found',
                          subtitle: 'Create a family to start managing parental controls',
                          onAction: () => _showCreateFamilyDialog(),
                          actionLabel: 'Create Family',
                        );
                      }
                      return FamilySelector(
                        families: families,
                        selectedFamily: selectedFamily ?? families.first,
                        onFamilySelected: (family) {
                          ref.read(selectedFamilyProvider.notifier).state = family;
                          ref.read(selectedChildProvider.notifier).state = null;
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Child Selector (always show when family available)
                  if (selectedFamily != null)
                    childrenAsync.when(
                      loading: () => const _LoadingSelector(title: 'Loading children...'),
                      error: (error, stack) => _ErrorSelector(
                        title: 'Error loading children',
                        error: error.toString(),
                      ),
                      data: (children) {
                        if (children.isEmpty) {
                          return _EmptyStateSelector(
                            title: 'No children in this family',
                            subtitle: 'Invite children to join this family',
                            onAction: () => _showInviteChildDialog(),
                            actionLabel: 'Invite Child',
                          );
                        }
                        return ChildSelector(
                          children: children,
                          selectedChild: selectedChild ?? children.first,
                          onChildSelected: (child) {
                            ref.read(selectedChildProvider.notifier).state = child;
                          },
                        );
                      },
                    ),
                ],
              ),
            ),

            // ── Tab Bar — always visible ──────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.blue[700],
                tabs: const [
                  Tab(text: 'Apps', icon: Icon(Icons.apps_outlined, size: 20)),
                  Tab(text: 'Usage', icon: Icon(Icons.bar_chart_outlined, size: 20)),
                  Tab(text: 'Location', icon: Icon(Icons.location_on_outlined, size: 20)),
                ],
              ),
            ),

            // ── Tab Views ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Apps Tab
                  hasSelection
                      ? ParentAppManagementScreen(
                          childId: effectiveChildId,
                          familyId: effectiveFamilyId,
                        )
                      : _buildNoSelectionPrompt(
                          icon: Icons.apps_rounded,
                          color: Colors.blue,
                          title: 'Select a Child to Manage Apps',
                          subtitle:
                              'Choose a family and child above to see installed apps and set rules.',
                        ),

                  // Usage Tab
                  hasSelection
                      ? _buildUsageTab(
                          familyId: effectiveFamilyId,
                          childId: effectiveChildId,
                          child: selectedChild,
                        )
                      : _buildNoSelectionPrompt(
                          icon: Icons.bar_chart_rounded,
                          color: Colors.green,
                          title: 'Select a Child to View Usage',
                          subtitle:
                              'Choose a child above to view their screen time reports.',
                        ),

                  // Location Tab
                  _buildLocationTab(
                    familyId: effectiveFamilyId,
                    childId: effectiveChildId,
                    child: selectedChild,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generic "no child selected" prompt shown inside tabs
  Widget _buildNoSelectionPrompt({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 52, color: color),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.familySetup),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Pair a Child Device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  // ──────────────────────────────────────────────────────────────────────────
  // USAGE TAB (REAL DATA & INTERACTION)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildUsageTab({
    required String familyId,
    required String childId,
    required ChildModel? child,
  }) {
    final childName = child?.displayName ?? 'Child';
    final appsAsync = ref.watch(
      familyChildAppsProvider(FamilyChildParams(familyId: familyId, childId: childId)),
    );
    final usageAsync = ref.watch(
      familyChildAppUsageProvider(FamilyChildParams(familyId: familyId, childId: childId)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(familyChildAppsProvider(FamilyChildParams(familyId: familyId, childId: childId)));
        ref.invalidate(familyChildAppUsageProvider(FamilyChildParams(familyId: familyId, childId: childId)));
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── Child Screen Time Hero Card ───────────────────────────
          usageAsync.when(
            loading: () => Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                'Could not load usage data: $err',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
            data: (usageMap) {
              final totalMinutesToday = usageMap.values.fold<int>(
                0,
                (sum, u) => sum + u.todayMinutes,
              );
              final activeAppsCount = usageMap.values.where((u) => u.todayMinutes > 0).length;
              final totalOpens = usageMap.values.fold<int>(
                0,
                (sum, u) => sum + u.openCount,
              );

              final hours = totalMinutesToday ~/ 60;
              final minutes = totalMinutesToday % 60;
              final timeString = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

              // Standard guideline allowance: 120 minutes daily
              const targetAllowanceMinutes = 120;
              final allowanceRatio = (totalMinutesToday / targetAllowanceMinutes).clamp(0.0, 1.0);

              final Color progressColor;
              final String statusChipText;
              final Color chipBg;
              final Color chipText;

              if (totalMinutesToday >= targetAllowanceMinutes) {
                progressColor = const Color(0xFFEF4444);
                statusChipText = 'Daily Target Exceeded';
                chipBg = const Color(0xFFFEE2E2);
                chipText = const Color(0xFFB91C1C);
              } else if (allowanceRatio > 0.75) {
                progressColor = const Color(0xFFF59E0B);
                statusChipText = 'Approaching Limit';
                chipBg = const Color(0xFFFEF3C7);
                chipText = const Color(0xFF92400E);
              } else {
                progressColor = const Color(0xFF10B981);
                statusChipText = 'Normal Activity';
                chipBg = const Color(0xFFD1FAE5);
                chipText = const Color(0xFF065F46);
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF3B82F6),
                                child: Text(
                                  childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$childName's Screen Time",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'Today\'s Device Activity',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusChipText,
                            style: TextStyle(
                              color: chipText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          timeString,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'used today',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: allowanceRatio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF334155),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Stats Row
                    Row(
                      children: [
                        _buildUsageStatPill(
                          icon: Icons.apps_rounded,
                          label: 'Active Apps',
                          value: '$activeAppsCount',
                        ),
                        const SizedBox(width: 12),
                        _buildUsageStatPill(
                          icon: Icons.launch_rounded,
                          label: 'App Launches',
                          value: '$totalOpens',
                        ),
                        const SizedBox(width: 12),
                        _buildUsageStatPill(
                          icon: Icons.sync_rounded,
                          label: 'Live Sync',
                          value: '30s',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Section Header ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Apps Used Today',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                label: const Text('Manage Rules'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Apps Usage Breakdown ──────────────────────────────────
          appsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Text('Error loading apps: $err'),
            ),
            data: (apps) {
              return usageAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (usageMap) {
                  if (apps.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.devices_other_rounded, size: 48, color: Colors.blue[300]),
                          const SizedBox(height: 12),
                          Text(
                            "Waiting for $childName's Device",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Once the companion app runs on $childName's phone, installed apps and usage reports will sync here in real time.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sort apps: apps with usage today first (descending), then alphabetically
                  final sortedApps = List<AppInfo>.from(apps);
                  sortedApps.sort((a, b) {
                    final usageA = usageMap[a.packageName]?.todayMinutes ?? 0;
                    final usageB = usageMap[b.packageName]?.todayMinutes ?? 0;
                    if (usageB != usageA) {
                      return usageB.compareTo(usageA);
                    }
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedApps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final app = sortedApps[index];
                      final usage = usageMap[app.packageName];
                      final usedMinutes = usage?.todayMinutes ?? 0;
                      final opens = usage?.openCount ?? 0;

                      return _buildAppUsageCard(
                        app: app,
                        usage: usage,
                        usedMinutes: usedMinutes,
                        opens: opens,
                        familyId: familyId,
                        childId: childId,
                        usageMap: usageMap,
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUsageStatPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF334155).withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUsageCard({
    required AppInfo app,
    required AppUsageModel? usage,
    required int usedMinutes,
    required int opens,
    required String familyId,
    required String childId,
    required Map<String, AppUsageModel> usageMap,
  }) {
    final isBlocked = app.rule == AppControlRule.block;
    final isLimited = app.rule == AppControlRule.timeLimited;
    final limitMinutes = app.dailyLimitMinutes ?? 60;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBlocked ? Colors.red.withOpacity(0.3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => AppRuleEditorSheet(
              appWithUsage: AppWithUsage(app: app, usage: usage),
              familyId: familyId,
              childId: childId,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAppDashboardIcon(app),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                usedMinutes > 0 ? '${usedMinutes}m used today' : 'No usage today',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: usedMinutes > 0 ? const Color(0xFF4338CA) : Colors.grey[600],
                                ),
                              ),
                            ),
                            if (opens > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• $opens opens',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildRuleStatusBadge(app.rule, app.dailyLimitMinutes),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Edit Rule',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => AppRuleEditorSheet(
                          appWithUsage: AppWithUsage(app: app, usage: usage),
                          familyId: familyId,
                          childId: childId,
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (isLimited || usedMinutes > 0) ...[
                const SizedBox(height: 8),
                AppUsageIndicator(
                  usedMinutes: usedMinutes,
                  limitMinutes: isLimited ? limitMinutes : 120,
                  showText: isLimited,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleStatusBadge(AppControlRule rule, int? limitMinutes) {
    Color bg;
    Color fg;
    String label;

    switch (rule) {
      case AppControlRule.block:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Blocked';
        break;
      case AppControlRule.allow:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Allowed';
        break;
      case AppControlRule.ask:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Ask Parent';
        break;
      case AppControlRule.timeLimited:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        label = limitMinutes != null ? '${limitMinutes}m limit' : 'Time limit';
        break;
      case AppControlRule.timeRestricted:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7C3AED);
        label = 'Restricted';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAppDashboardIcon(AppInfo app) {
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _buildDashboardFallbackIcon(app),
          ),
        );
      } catch (_) {}
    }
    return _buildDashboardFallbackIcon(app);
  }

  Widget _buildDashboardFallbackIcon(AppInfo app) {
    final letter = app.name.isNotEmpty ? app.name[0].toUpperCase() : 'A';
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF0D9488),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
    ];
    final color = colors[app.packageName.hashCode.abs() % colors.length];

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOCATION TAB (REAL GPS, ACCURACY, NAVIGATION & LIVE UPDATES)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLocationTab({
    required String familyId,
    required String childId,
    required ChildModel? child,
  }) {
    if (familyId.isEmpty) {
      return _buildNoSelectionPrompt(
        icon: Icons.location_on_rounded,
        color: Colors.orange,
        title: 'Select a Family',
        subtitle: 'Choose a family from above to access live GPS location monitoring.',
      );
    }

    final childName = child?.displayName ?? 'Child';

    return StreamBuilder<List<FamilyLocation>>(
      stream: LocationService().getFamilyLocations(familyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final locations = snapshot.data ?? [];
        final childLoc = locations.cast<FamilyLocation?>().firstWhere(
              (loc) => loc?.childId == childId,
              orElse: () => null,
            );

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── Primary Child Live GPS Card ───────────────────────────
            if (childLoc != null)
              _buildChildLiveGpsCard(childLoc, childName)
            else
              _buildChildAwaitingGpsCard(childName),

            const SizedBox(height: 20),

            // ── Full Map Navigation Banner ────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Interactive Family Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track all children, geofences, and safe zones on full screen.',
                          style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => context.push(AppRoutes.parentLocation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Open Map', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Other Family Members' Locations ──────────────────────
            if (locations.length > 1 || (locations.isNotEmpty && childLoc == null)) ...[
              Text(
                'All Family Devices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 10),
              ...locations.map((loc) {
                final isCurrentChild = loc.childId == childId;
                final name = loc.childName ?? (isCurrentChild ? childName : 'Child Device');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrentChild ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                      width: isCurrentChild ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFEEF2FF),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isCurrentChild) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Selected',
                                      style: TextStyle(
                                        color: Color(0xFF4F46E5),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            FutureBuilder<String?>(
                              future: (loc.address != null && loc.address!.trim().isNotEmpty)
                                  ? Future.value(loc.address)
                                  : GeocodingService.instance.getPlaceName(loc.latitude, loc.longitude),
                              builder: (context, snapshot) {
                                final place = snapshot.data ?? loc.address;
                                final placePrefix = (place != null && place.trim().isNotEmpty) ? '$place • ' : '';
                                return Text(
                                  '$placePrefix${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} • ${_formatTimestampAgo(loc.timestamp)}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.navigation_rounded, color: Color(0xFF4F46E5), size: 20),
                        tooltip: 'Navigate',
                        onPressed: () => _openLocationInMaps(loc),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildChildLiveGpsCard(FamilyLocation loc, String childName) {
    final isStale = loc.isStale;
    final speedKmH = ((loc.speed ?? 0) * 3.6).clamp(0.0, 200.0);
    final accuracy = loc.accuracy ?? 15.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isStale ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isStale ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isStale ? 'LAST KNOWN GPS' : 'LIVE GPS LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isStale ? const Color(0xFFD97706) : const Color(0xFF059669),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestampAgo(loc.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Child Name Title
          Text(
            "$childName's Current Position",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          // Readable City, Village & Country Place Banner
          FutureBuilder<String?>(
            future: (loc.address != null && loc.address!.trim().isNotEmpty)
                ? Future.value(loc.address)
                : GeocodingService.instance.getPlaceName(loc.latitude, loc.longitude),
            builder: (context, snapshot) {
              final place = snapshot.data ?? loc.address;
              if (place == null || place.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Lat/Lng Coordinates
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 4),
              Text(
                '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _copyLocationCoordinates(loc),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: const [
                      Icon(Icons.copy_rounded, size: 13, color: Color(0xFF4F46E5)),
                      SizedBox(width: 2),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Metrics Pills
          Row(
            children: [
              _buildLocationMetric(
                label: 'Precision',
                value: '±${accuracy.toStringAsFixed(0)}m',
                icon: Icons.gps_fixed_rounded,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 10),
              _buildLocationMetric(
                label: 'Speed',
                value: '${speedKmH.toStringAsFixed(1)} km/h',
                icon: Icons.speed_rounded,
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              _buildLocationMetric(
                label: 'Altitude',
                value: '${loc.altitude?.toStringAsFixed(0) ?? 0}m',
                icon: Icons.terrain_rounded,
                color: const Color(0xFF9333EA),
              ),
            ],
          ),

          if (isStale) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reported over 30 mins ago. The child device may be sleeping or offline.',
                      style: TextStyle(color: Colors.amber[900], fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openLocationInMaps(loc),
                  icon: const Icon(Icons.navigation_rounded, size: 17),
                  label: const Text('Open in Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _copyLocationCoordinates(loc),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Coordinates'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildAwaitingGpsCard(String childName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.satellite_alt_rounded, size: 40, color: Colors.orange[600]),
          ),
          const SizedBox(height: 16),
          Text(
            "Waiting for $childName's GPS Signal",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            "Location tracking is active. As soon as $childName's companion app establishes satellite lock, real-time coordinates will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Check that Location permission is 'Allow all the time' on $childName's device.",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.parentLocation),
            icon: const Icon(Icons.map_rounded),
            label: const Text('Open Live Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocationInMaps(FamilyLocation loc) async {
    final uri = 'geo:${loc.latitude},${loc.longitude}?q=${loc.latitude},${loc.longitude}';
    const channel = MethodChannel('family_guardian/permissions');
    try {
      await channel.invokeMethod('openUrl', {'url': uri});
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: '${loc.latitude}, ${loc.longitude}'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordinates copied to clipboard. Paste into Google Maps.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copyLocationCoordinates(FamilyLocation loc) async {
    await Clipboard.setData(
      ClipboardData(text: '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied coordinates: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTimestampAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parent Controls Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded, color: Color(0xFF4F46E5)),
                title: const Text('Notification Preferences'),
                subtitle: const Text('Alerts for requests, new apps, and limits'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/notifications');
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_rounded, color: Color(0xFF10B981)),
                title: const Text('Pair New Device'),
                subtitle: const Text('Generate 6-digit code or QR for child'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.familySetup);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFD97706)),
                title: const Text('Switch Role'),
                subtitle: const Text('Change account mode to child companion'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.roleSelection);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFamilyDialog() {
    context.push(AppRoutes.familySetup);
  }

  void _showInviteChildDialog() {
    context.push(AppRoutes.familySetup);
  }

}


// Helper widgets
class _LoadingSelector extends StatelessWidget {
  final String title;

  const _LoadingSelector({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
    );
  }
}

class _ErrorSelector extends StatelessWidget {
  final String title;
  final String error;

  const _ErrorSelector({
    required this.title,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                Text(
                  error,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateSelector extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAction;
  final String actionLabel;

  const _EmptyStateSelector({
    required this.title,
    required this.subtitle,
    required this.onAction,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
