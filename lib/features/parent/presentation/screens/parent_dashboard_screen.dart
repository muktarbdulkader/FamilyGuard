import '../../../../core/widgets/family_page_header.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/app_info.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/models/emergency_sos_model.dart';
import '../../../../core/models/activity_log_model.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/services/emergency_service.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon_widget.dart';
import '../widgets/app_usage_indicator.dart';
import '../widgets/app_rule_editor_sheet.dart';
import '../../../apps/presentation/screens/parent_app_management_screen.dart';
import '../widgets/send_educational_dialog.dart';
import '../../../../core/models/educational_material_model.dart';
import '../../../../core/services/education_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/family_bottom_navigation.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main parent dashboard screen with family and child selection
/// Professional UI for managing parental controls
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _autoSelectDone = false;
  Timer? _presenceRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _presenceRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _presenceRefreshTimer?.cancel();
    super.dispose();
  }

  /// Auto-select first family + first child so tabs are immediately usable.
  /// Also guard against stale child selections that belong to another family.
  void _maybeAutoSelect(
    List<FamilyModel> families,
    FamilyModel? selectedFamily,
    List<ChildModel> children,
    ChildModel? selectedChild,
  ) {
    if (_autoSelectDone) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final selectedFamilyId = selectedFamily?.id;
      FamilyModel? activeFamily = selectedFamily;
      if (selectedFamilyId != null) {
        activeFamily = null;
        for (final family in families) {
          if (family.id == selectedFamilyId) {
            activeFamily = family;
            break;
          }
        }
      }
      if (activeFamily == null && families.isNotEmpty) {
        ref.read(selectedFamilyProvider.notifier).state = families.first;
      }

      final selectedChildId = selectedChild?.id;
      ChildModel? activeChild = selectedChild;
      if (selectedChildId != null) {
        activeChild = null;
        for (final child in children) {
          if (child.id == selectedChildId) {
            activeChild = child;
            break;
          }
        }
      }
      if (activeChild == null && children.isNotEmpty) {
        ref.read(selectedChildProvider.notifier).state = children.first;
      }

      _autoSelectDone = true;
    });
  }

  void _showFamilySwitcherSheet(
    BuildContext context,
    List<FamilyModel> families,
    FamilyModel? selectedFamily,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF132238) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Switch Family',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...families.map((family) {
              final isSel = family.id == selectedFamily?.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSel
                      ? (isDark ? const Color(0xFF0F3B39) : const Color(0xFFEEF2FF))
                      : (isDark ? const Color(0xFF1E3554).withOpacity(0.4) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel
                        ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF4F46E5))
                        : Colors.transparent,
                  ),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    Icons.home_rounded,
                    color: isSel
                        ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF4F46E5))
                        : (isDark ? const Color(0xFF8BA0B8) : Colors.grey),
                  ),
                  title: Text(
                    family.name,
                    style: TextStyle(
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: isSel
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF4F46E5),
                        )
                      : null,
                  onTap: () {
                    ref.read(selectedFamilyProvider.notifier).state = family;
                    ref.read(selectedChildProvider.notifier).state = null;
                    Navigator.pop(ctx);
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCreateFamilyDialog();
                },
                icon: const Icon(Icons.add_home_rounded),
                label: const Text('Create Another Family'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

    final children = childrenAsync.maybeWhen(
      data: (items) => items,
      orElse: () => <ChildModel>[],
    );
    final activeSelectedChild = selectedFamily != null && children.isNotEmpty
        ? children.firstWhere(
            (child) => child.id == selectedChild?.id,
            orElse: () => children.first,
          )
        : selectedChild;

    if (selectedFamily != null &&
        activeSelectedChild != null &&
        selectedChild?.id != activeSelectedChild.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedChildProvider.notifier).state = activeSelectedChild;
        }
      });
    }

    final effectiveFamilyId = selectedFamily?.id ?? '';
    final effectiveChildId = activeSelectedChild?.id ?? '';
    final hasSelection =
        effectiveFamilyId.isNotEmpty && effectiveChildId.isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1829) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // ── Reusable Top Page Header with Dynamic Subtitle & Family Switcher ──
            FamilyPageHeader(
              title: l10n.familyControls,
              subtitle: selectedFamily != null
                  ? (children.isNotEmpty
                      ? '${selectedFamily.name} • ${children.length} ${children.length == 1 ? 'child' : 'children'}'
                      : selectedFamily.name)
                  : l10n.parentDashboard,
              icon: Icons.tune_rounded,
              actions: [
                // Multi-family switcher button if parent has >1 family
                if (familiesAsync.value != null && familiesAsync.value!.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showFamilySwitcherSheet(
                        context,
                        familiesAsync.value!,
                        selectedFamily,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF132238) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E3554) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 15,
                              color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 80),
                              child: Text(
                                selectedFamily?.name ?? 'Family',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: isDark ? const Color(0xFF8BA0B8) : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                IconButton(
                  onPressed: () => _showSettings(),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: Icon(
                    Icons.settings_outlined,
                    color: isDark
                        ? const Color(0xFF8BA0B8)
                        : const Color(0xFF64748B),
                  ),
                  tooltip: l10n.settings,
                ),
              ],
            ),

            // ── Ultra-Comfortable Compact Horizontal Child Selector Bar ──
            // Stays fixed at 56px height, supporting 1 to 20+ children without pushing down content!
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C1829) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF1E3554)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: familiesAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Text(
                        'Failed to load family',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        onPressed: () => ref.refresh(userFamiliesProvider),
                      ),
                    ],
                  ),
                ),
                data: (families) {
                  if (families.isEmpty) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: () => _showCreateFamilyDialog(),
                        icon: const Icon(Icons.add_home_rounded, size: 18),
                        label: const Text(
                          'Create a Family',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }

                  return childrenAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Text(
                            'Failed to load children',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            onPressed: () => ref.refresh(familyChildrenProvider),
                          ),
                        ],
                      ),
                    ),
                    data: (children) {
                      if (children.isEmpty) {
                        return Center(
                          child: TextButton.icon(
                            onPressed: () => _showInviteChildDialog(),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text(
                              'Invite / Pair a Child Device',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: children.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          // "+ Add" Child button at the end
                          if (index == children.length) {
                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showInviteChildDialog(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF132238) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1E3554) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                      color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add Child',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF8BA0B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final child = children[index];
                          final isSelected = child.id == activeSelectedChild?.id;
                          final initial = child.displayName.isNotEmpty
                              ? child.displayName[0].toUpperCase()
                              : 'C';
                          final permissionAge = child.lastPermissionCheck == null
                              ? null
                              : DateTime.now().difference(
                                  child.lastPermissionCheck!,
                                );
                          final hasRecentPermissionReport =
                              permissionAge != null &&
                              !permissionAge.isNegative &&
                              permissionAge <= ChildPresence.onlineThreshold;

                          return InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              ref.read(selectedChildProvider.notifier).state = child;
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                        ? const Color(0xFF0F3B39)
                                        : const Color(0xFFEEF2FF))
                                    : (isDark
                                        ? const Color(0xFF132238)
                                        : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark
                                          ? const Color(0xFF2DD4BF)
                                          : const Color(0xFF4F46E5))
                                      : (isDark
                                          ? const Color(0xFF1E3554)
                                          : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: (isDark
                                                  ? const Color(0xFF2DD4BF)
                                                  : const Color(0xFF4F46E5))
                                              .withOpacity(isDark ? 0.3 : 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Avatar circle with Online status & Tamper indicator
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isSelected
                                            ? (isDark
                                                ? const Color(0xFF2DD4BF)
                                                : const Color(0xFF4F46E5))
                                            : (isDark
                                                ? const Color(0xFF1E3554)
                                                : const Color(0xFFE2E8F0)),
                                        child: Text(
                                          initial,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected
                                                ? (isDark ? const Color(0xFF042421) : Colors.white)
                                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                          ),
                                        ),
                                      ),
                                      // Online indicator dot
                                      Positioned(
                                        bottom: -1,
                                        right: -1,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: child.isOnline
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF94A3B8),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF132238)
                                                  : Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Do not infer tampering from missing or stale permission reports.
                                      if (hasRecentPermissionReport &&
                                          (!child.hasOverlayPermission ||
                                              !child.hasUsageStatsPermission))
                                        Positioned(
                                          top: -3,
                                          left: -3,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF132238) : Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                '!',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 7,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    child.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: isDark
                                          ? const Color(0xFF2DD4BF)
                                          : const Color(0xFF4F46E5),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // ── Emergency Alert Banner ─────────────────────────────
            if (effectiveFamilyId.isNotEmpty)
              _EmergencyAlertBanner(familyId: effectiveFamilyId),
            // ── Tab Bar — always visible ──────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C1829) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E3554) : Colors.grey[200]!,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: isDark
                    ? const Color(0xFF2DD4BF)
                    : const Color(0xFF4F46E5),
                unselectedLabelColor: isDark
                    ? const Color(0xFF8BA0B8)
                    : const Color(0xFF64748B),
                indicatorColor: isDark
                    ? const Color(0xFF2DD4BF)
                    : const Color(0xFF4F46E5),
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    text: l10n.apps,
                    icon: const Icon(Icons.apps_rounded, size: 20),
                  ),
                  const Tab(
                    text: 'Usage',
                    icon: Icon(Icons.bar_chart_rounded, size: 20),
                  ),
                  Tab(
                    text: l10n.location,
                    icon: const Icon(Icons.location_on_rounded, size: 20),
                  ),
                  const Tab(
                    text: 'History',
                    icon: Icon(Icons.history_rounded, size: 20),
                  ),
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
                          childName: activeSelectedChild?.displayName,
                          isEmbedded: true,
                        )
                      : _buildNoSelectionPrompt(
                          icon: Icons.apps_rounded,
                          color: const Color(0xFF4F46E5),
                          title: 'Select a Child to Manage Apps',
                          subtitle:
                              'Choose a family and child above to see installed apps and set rules.',
                        ),

                  // Usage Tab
                  hasSelection
                      ? _buildUsageTab(
                          familyId: effectiveFamilyId,
                          childId: effectiveChildId,
                          child: activeSelectedChild,
                        )
                      : _buildNoSelectionPrompt(
                          icon: Icons.bar_chart_rounded,
                          color: const Color(0xFF7C3AED),
                          title: 'Select a Child to View Usage',
                          subtitle:
                              'Choose a child above to view their screen time reports.',
                        ),

                  // Location Tab
                  _buildLocationTab(
                    familyId: effectiveFamilyId,
                    childId: effectiveChildId,
                    child: activeSelectedChild,
                  ),

                  // History Tab
                  _buildHistoryTab(
                    familyId: effectiveFamilyId,
                    childId: hasSelection ? effectiveChildId : null,
                    children: children,
                    selectedChild: activeSelectedChild,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const FamilyBottomNavigation(
        isParent: true,
        selected: FamilyNavDestination.apps,
      ),
    );
  }

  // ── Activity History Tab ──────────────────────────────────────────────────
  Widget _buildHistoryTab({
    required String familyId,
    String? childId,
    required List<ChildModel> children,
    ChildModel? selectedChild,
  }) {
    if (familyId.isEmpty) {
      return _buildNoSelectionPrompt(
        icon: Icons.history_rounded,
        color: const Color(0xFF8B5CF6),
        title: 'No Family Selected',
        subtitle: 'Select a family to view activity history.',
      );
    }
    return _ActivityHistoryTab(
      familyId: familyId,
      childId: childId,
      children: children,
      selectedChild: selectedChild,
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
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 64.0,
            ),
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
    final colors = AppColors.of(context);
    final childName = child?.displayName ?? 'Child';
    final appsAsync = ref.watch(
      familyChildAppsProvider(
        FamilyChildParams(familyId: familyId, childId: childId),
      ),
    );
    final usageAsync = ref.watch(
      familyChildAppUsageProvider(
        FamilyChildParams(familyId: familyId, childId: childId),
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          familyChildAppsProvider(
            FamilyChildParams(familyId: familyId, childId: childId),
          ),
        );
        ref.invalidate(
          familyChildAppUsageProvider(
            FamilyChildParams(familyId: familyId, childId: childId),
          ),
        );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
        children: [
          if (child != null) _buildDeviceHealthCard(child),
          if (child != null) const SizedBox(height: 16),
          // ── Child Screen Time Hero Card ───────────────────────────
          usageAsync.when(
            loading: () => Container(
              height: 140,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: CircularProgressIndicator(color: colors.primary),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.error.withOpacity(0.35)),
              ),
              child: Text(
                'Could not load usage data: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (usageMap) {
              final totalMinutesToday = usageMap.values.fold<int>(
                0,
                (sum, u) => sum + u.todayMinutes,
              );
              final activeAppsCount = usageMap.values
                  .where((u) => u.todayMinutes > 0)
                  .length;
              final totalOpens = usageMap.values.fold<int>(
                0,
                (sum, u) => sum + u.openCount,
              );

              DateTime? latestUsageSync;
              for (final u in usageMap.values) {
                if (latestUsageSync == null ||
                    u.lastUsed.isAfter(latestUsageSync)) {
                  latestUsageSync = u.lastUsed;
                }
              }
              latestUsageSync ??= child?.lastSyncTimestamp ?? child?.lastSeen;
              final syncLabel = latestUsageSync != null
                  ? AppFormatters.formatRelativeTime(latestUsageSync)
                  : 'Waiting';

              final hours = totalMinutesToday ~/ 60;
              final minutes = totalMinutesToday % 60;
              final timeString = hours > 0
                  ? '${hours}h ${minutes}m'
                  : '${minutes}m';

              final prefLimit =
                  (child?.preferences['dailyScreenTimeLimitMinutes'] as num?)
                      ?.toInt() ??
                  0;
              final targetAllowanceMinutes = prefLimit > 0 ? prefLimit : 120;
              final allowanceRatio =
                  (totalMinutesToday / targetAllowanceMinutes).clamp(0.0, 1.0);

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
                                  childName.isNotEmpty
                                      ? childName[0].toUpperCase()
                                      : 'C',
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
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusChipText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: chipText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor,
                        ),
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
                        const SizedBox(width: 8),
                        _buildUsageStatPill(
                          icon: Icons.launch_rounded,
                          label: 'App Launches',
                          value: '$totalOpens',
                        ),
                        const SizedBox(width: 8),
                        _buildUsageStatPill(
                          icon: Icons.sync_rounded,
                          label: 'Last Sync',
                          value: syncLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Send Study Material Card ───────────────────────────────
          _buildSendEducationCard(
            familyId: familyId,
            childId: childId,
            childName: childName,
          ),

          const SizedBox(height: 16),

          // ── Education Tasks Sent ───────────────────────────────────
          _buildEducationTasksSection(familyId: familyId, childId: childId),

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
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                label: const Text('Manage Rules'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
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
            error: (err, _) => Center(child: Text('Error loading apps: $err')),
            data: (apps) {
              return usageAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (usageMap) {
                  if (apps.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.devices_other_rounded,
                            size: 48,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Waiting for $childName's Device",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Once the companion app runs on $childName's phone, installed apps and usage reports will sync here in real time.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
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

  Widget _buildDeviceHealthCard(ChildModel child) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lastSync = child.lastSyncTimestamp;
    final age = lastSync == null ? null : DateTime.now().difference(lastSync);
    final isFresh =
        age != null && !age.isNegative && age <= ChildPresence.onlineThreshold;
    final isStale = age != null && age > ChildPresence.onlineThreshold;
    final permissionAge = child.lastPermissionCheck == null
        ? null
        : DateTime.now().difference(child.lastPermissionCheck!);
    final permissionsAreFresh = permissionAge != null &&
        !permissionAge.isNegative &&
        permissionAge <= ChildPresence.onlineThreshold;
    final monitoringStatus = !isFresh
        ? null
        : child.isMonitoringActive;
    final statusColor = monitoringStatus == null
        ? const Color(0xFFD97706)
        : monitoringStatus
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_rounded, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.deviceHealthTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.refreshDeviceStatus,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.invalidate(familyChildrenProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              monitoringStatus == null
                  ? l10n.monitoringStatusUnverified
                  : monitoringStatus
                  ? l10n.monitoringStatusActive
                  : l10n.monitoringStatusUnavailable,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lastSync == null
                  ? l10n.deviceHealthNeverReported
                  : isStale
                  ? l10n.deviceHealthStale(_formatDeviceTimestamp(lastSync))
                  : l10n.deviceHealthLastReported(
                      _formatDeviceTimestamp(lastSync),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _healthStatusChip(
                  l10n.usageAccess,
                  permissionsAreFresh ? child.hasUsageStatsPermission : null,
                ),
                _healthStatusChip(
                  l10n.appBlocking,
                  permissionsAreFresh ? child.hasOverlayPermission : null,
                ),
                _healthStatusChip(
                  l10n.locationPermission,
                  permissionsAreFresh ? child.hasLocationPermission : null,
                ),
                _healthStatusChip(
                  l10n.notificationPermission,
                  permissionsAreFresh ? child.hasNotificationPermission : null,
                ),
                _healthStatusChip(
                  l10n.batteryOptimization,
                  permissionsAreFresh
                      ? child.hasBatteryOptimizationDisabled
                      : null,
                ),
                _healthStatusChip(
                  l10n.deviceConnection,
                  child.lastSeen == null ? null : child.isOnline,
                ),
              ],
            ),
            if (permissionsAreFresh &&
                (!child.hasUsageStatsPermission ||
                    !child.hasOverlayPermission ||
                    !child.hasLocationPermission ||
                    !child.hasNotificationPermission)) ...[
              const SizedBox(height: 12),
              Text(
                l10n.restorePermissionsInstruction,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (isFresh &&
                (child.batteryLevel != null && child.batteryLevel! >= 0 ||
                    child.networkType != null)) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (child.batteryLevel != null && child.batteryLevel! >= 0)
                    'Battery ${child.batteryLevel}%${child.isCharging ? ' (charging)' : ''}',
                  if (child.networkType != null &&
                      child.networkType!.trim().isNotEmpty)
                    'Network ${child.networkType}',
                ].join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _healthStatusChip(String label, bool? isEnabled) {
    final l10n = AppLocalizations.of(context);
    final (icon, color, status) = switch (isEnabled) {
      true => (
        Icons.check_circle_rounded,
        const Color(0xFF059669),
        l10n.statusOn,
      ),
      false => (Icons.error_rounded, const Color(0xFFDC2626), l10n.statusOff),
      null => (Icons.help_rounded, const Color(0xFFD97706), l10n.statusUnknown),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: $status',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeviceTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    return '${materialLocalizations.formatMediumDate(local)} '
        '${materialLocalizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  // ── Send Education Card ──────────────────────────────────────────────────
  Widget _buildSendEducationCard({
    required String familyId,
    required String childId,
    required String childName,
  }) {
    final parentName =
        ref.watch(authNotifierProvider).user?.displayName ?? 'Parent';

    return InkWell(
      onTap: () => SendEducationalDialog.show(
        context,
        familyId: familyId,
        childId: childId,
        childName: childName,
        parentName: parentName,
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Send Study Material',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Share videos, links & tasks with $childName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_rounded, size: 14, color: Color(0xFF4F46E5)),
                  SizedBox(width: 4),
                  Text(
                    'Send',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Education Tasks & Materials Section ──────────────────────────────────
  Widget _buildEducationTasksSection({
    required String familyId,
    required String childId,
  }) {
    final materialsAsync = ref.watch(
      childEducationalMaterialsProvider((familyId: familyId, childId: childId)),
    );
    final tasksAsync = ref.watch(
      childEducationTasksProvider((familyId: familyId, childId: childId)),
    );

    final materials = materialsAsync.value ?? [];
    final tasks = tasksAsync.value ?? [];

    // Unified list: prioritizing EducationalMaterial
    final seenIds = <String>{};
    final unifiedItems =
        <
          ({
            String id,
            String title,
            String subject,
            String note,
            String? url,
            String? fileName,
            String typeBadge,
            bool isCompleted,
            bool isDoc,
          })
        >[];

    for (final mat in materials) {
      seenIds.add(mat.id);
      unifiedItems.add((
        id: mat.id,
        title: mat.title,
        subject: mat.subject,
        note: mat.instructions ?? mat.description,
        url: mat.fileUrl.isNotEmpty ? mat.fileUrl : null,
        fileName: mat.fileName,
        typeBadge: mat.materialType.badgeLabel,
        isCompleted: mat.isCompletedBy(childId),
        isDoc: mat.materialType != EduFileType.url,
      ));
    }

    for (final task in tasks) {
      if (!seenIds.contains(task.id)) {
        seenIds.add(task.id);
        unifiedItems.add((
          id: task.id,
          title: task.title,
          subject: task.subject,
          note: task.note,
          url: task.url,
          fileName: null,
          typeBadge: task.url != null && task.url!.isNotEmpty ? 'LINK' : 'TASK',
          isCompleted: task.isCompleted,
          isDoc: false,
        ));
      }
    }

    if (unifiedItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                '📚 Study Documents & Tasks',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${unifiedItems.length} item${unifiedItems.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...unifiedItems
            .take(4)
            .map(
              (item) => _buildUnifiedEducationCard(
                item: item,
                familyId: familyId,
                childId: childId,
              ),
            ),
        if (unifiedItems.length > 4)
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.parentEducation),
            icon: const Icon(Icons.school_rounded, size: 16),
            label: Text('View all ${unifiedItems.length} in Education Center'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4F46E5),
            ),
          ),
      ],
    );
  }

  Widget _buildUnifiedEducationCard({
    required ({
      String id,
      String title,
      String subject,
      String note,
      String? url,
      String? fileName,
      String typeBadge,
      bool isCompleted,
      bool isDoc,
    })
    item,
    required String familyId,
    required String childId,
  }) {
    final color = _subjectColor(item.subject);
    final icon = _subjectIcon(item.subject);

    return InkWell(
      onTap: item.url != null && item.url!.isNotEmpty
          ? () async {
              try {
                final uri = Uri.parse(item.url!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isCompleted ? Colors.green[200]! : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: item.isCompleted
                                ? Colors.grey[500]
                                : const Color(0xFF0F172A),
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.typeBadge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.fileName != null && item.fileName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.attachment_rounded,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.fileName!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4F46E5),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.note,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isCompleted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.schedule_rounded,
                    color: Colors.orange[400],
                    size: 18,
                  ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () async {
                    await ref
                        .read(educationServiceProvider)
                        .deleteTask(
                          familyId: familyId,
                          childId: childId,
                          taskId: item.id,
                        );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red[300],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _subjectColor(String subject) {
    switch (subject) {
      case 'Math':
      case 'Mathematics':
        return const Color(0xFF2563EB);
      case 'Reading':
      case 'English & Literature':
        return const Color(0xFFD97706);
      case 'Language':
      case 'History':
        return const Color(0xFF7C3AED);
      case 'Video':
        return const Color(0xFFDC2626);
      case 'Assignment':
      case 'Coding & Tech':
        return const Color(0xFF0891B2);
      default:
        return const Color(0xFF059669);
    }
  }

  IconData _subjectIcon(String subject) {
    switch (subject) {
      case 'Math':
        return Icons.calculate_rounded;
      case 'Reading':
        return Icons.menu_book_rounded;
      case 'Language':
        return Icons.translate_rounded;
      case 'Video':
        return Icons.play_circle_fill_rounded;
      case 'Assignment':
        return Icons.assignment_rounded;
      default:
        return Icons.science_rounded;
    }
  }

  Widget _buildUsageStatPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF334155).withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
    final colors = AppColors.of(context);
    final isBlocked = app.rule == AppControlRule.block;
    final isLimited = app.rule == AppControlRule.timeLimited;
    final limitMinutes = app.dailyLimitMinutes ?? 60;
    final usageLabel = usedMinutes == 0
        ? 'No usage today'
        : usedMinutes < 60
        ? '${usedMinutes}m used today'
        : '${usedMinutes ~/ 60}h ${usedMinutes % 60}m used today';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked ? colors.error.withOpacity(0.4) : colors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colors.isDark ? 0.14 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.all(14),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: usedMinutes > 0
                                    ? colors.primary.withOpacity(0.12)
                                    : colors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                usageLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: usedMinutes > 0
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                            if (opens > 0) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '• $opens opens',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildRuleStatusBadge(app.rule, app.dailyLimitMinutes),
                  IconButton(
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
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
                const SizedBox(height: 10),
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
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAppDashboardIcon(AppInfo app) {
    final bytes = AppIconWidget.decodeCached(app.iconBase64);
    if (bytes != null) {
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
        subtitle:
            'Choose a family from above to access live GPS location monitoring.',
      );
    }

    final childName = child?.displayName ?? 'Child';

    return StreamBuilder<List<FamilyLocation>>(
      stream: LocationService().getFamilyLocations(familyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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
              _buildChildAwaitingGpsCard(
                childName,
                child?.isOnline ?? false,
                child?.lastSeen,
              ),

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
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
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
                          style: TextStyle(
                            color: Color(0xFFE0E7FF),
                            fontSize: 12,
                          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Open Map',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Other Family Members' Locations ──────────────────────
            if (locations.length > 1 ||
                (locations.isNotEmpty && childLoc == null)) ...[
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
                final name =
                    loc.childName ??
                    (isCurrentChild ? childName : 'Child Device');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrentChild
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
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
                              future:
                                  (loc.address != null &&
                                      loc.address!.trim().isNotEmpty)
                                  ? Future.value(loc.address)
                                  : GeocodingService.instance.getPlaceName(
                                      loc.latitude,
                                      loc.longitude,
                                    ),
                              builder: (context, snapshot) {
                                final place = snapshot.data ?? loc.address;
                                final placePrefix =
                                    (place != null && place.trim().isNotEmpty)
                                    ? '$place • '
                                    : '';
                                return Text(
                                  '$placePrefix${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} • ${_formatTimestampAgo(loc.timestamp)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.navigation_rounded,
                          color: Color(0xFF4F46E5),
                          size: 20,
                        ),
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
                        color: isStale
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'GPS LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isStale
                              ? const Color(0xFFD97706)
                              : const Color(0xFF059669),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'GPS: updated ${_formatTimestampAgo(loc.timestamp)}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isStale ? const Color(0xFFD97706) : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          if (!loc.isDeviceOnline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 17,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.lastSeen == null
                          ? '$childName is offline. Device heartbeat has not been received yet.'
                          : '$childName is offline. Last seen ${_formatTimestampAgo(loc.lastSeen!)}.',
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
                : GeocodingService.instance.getPlaceName(
                    loc.latitude,
                    loc.longitude,
                  ),
            builder: (context, snapshot) {
              final place = snapshot.data ?? loc.address;
              if (place == null || place.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_city_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
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
              const Icon(
                Icons.place_rounded,
                size: 16,
                color: Color(0xFFEF4444),
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: Color(0xFF4F46E5),
                      ),
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
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS is stale. The device may be sleeping or offline.',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _buildChildAwaitingGpsCard(
    String childName,
    bool isOnline,
    DateTime? lastSeen,
  ) {
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
            child: Icon(
              Icons.satellite_alt_rounded,
              size: 40,
              color: Colors.orange[600],
            ),
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
          if (!isOnline) ...[
            const SizedBox(height: 12),
            Text(
              lastSeen == null
                  ? '$childName is offline. No device heartbeat has been received.'
                  : '$childName is offline. Last seen ${_formatTimestampAgo(lastSeen)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Check that Location permission is 'Allow all the time' on $childName's device.",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                    ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocationInMaps(FamilyLocation loc) async {
    final uri =
        'geo:${loc.latitude},${loc.longitude}?q=${loc.latitude},${loc.longitude}';
    const channel = MethodChannel('family_guardian/permissions');
    try {
      await channel.invokeMethod('openUrl', {'url': uri});
    } catch (_) {
      await Clipboard.setData(
        ClipboardData(text: '${loc.latitude}, ${loc.longitude}'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Coordinates copied to clipboard. Paste into Google Maps.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copyLocationCoordinates(FamilyLocation loc) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF132238) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parent Controls Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Theme / Color Mode Toggle
              Consumer(
                builder: (context, ref, _) {
                  final currentMode = ref.watch(themeModeProvider);
                  final isCurrentDark = currentMode == ThemeMode.dark;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14243B)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E3554)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCurrentDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: const Color(0xFF2DD4BF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dark Navy Palette',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                isCurrentDark
                                    ? 'Dark theme enabled across all pages'
                                    : 'Light theme active',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF8BA0B8)
                                      : Colors.grey[600],
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isCurrentDark,
                          activeColor: const Color(0xFF2DD4BF),
                          activeTrackColor: const Color(0xFF0D5E57),
                          onChanged: (val) {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),

              ListTile(
                leading: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF2DD4BF),
                ),
                title: Text(
                  'Notification Preferences',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Alerts for requests, new apps, and limits',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF8BA0B8) : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/notifications');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.qr_code_rounded,
                  color: Color(0xFF38BDF8),
                ),
                title: Text(
                  'Pair New Device',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Generate 6-digit code or QR for child',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF8BA0B8) : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.familySetup);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFFF59E0B),
                ),
                title: Text(
                  'Switch Role',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Change account mode to child companion',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF8BA0B8) : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Emergency Alert Banner — shown when there are active/pending SOS alerts
// ─────────────────────────────────────────────────────────────────────────────
class _EmergencyAlertBanner extends ConsumerWidget {
  final String familyId;
  const _EmergencyAlertBanner({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(activeEmergencyAlertsProvider(familyId));

    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) return const SizedBox.shrink();

        final sosAlerts = alerts.where((a) => a.isSos).toList();
        if (sosAlerts.isEmpty) return const SizedBox.shrink();

        final alert = sosAlerts.first;
        return GestureDetector(
          onTap: () => _showAlertDialog(context, ref, alert),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚨 EMERGENCY SOS: ${alert.childName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.address ?? 'Location: gathering...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    alert.isPending ? 'Respond' : 'Continue',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showAlertDialog(BuildContext context, WidgetRef ref, EmergencyAlert alert) {
    final auth = ref.read(authStateProvider).value;
    final parentName = auth?.displayName ?? 'Parent';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '🚨 Emergency SOS — ${alert.childName}',
          style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.address != null) ...[
              const Text('📍 Location:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(alert.address!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            ],
            Text(
              'Status: ${alert.status.displayName}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Sent: ${AppFormatters.formatRelativeTime(alert.timestamp)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (alert.isPending)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await EmergencyService.instance.acknowledgeAlert(
                  familyId: alert.familyId,
                  alertId: alert.id,
                  parentId: auth?.uid ?? '',
                  parentName: parentName,
                );
              },
              child: const Text(
                'Acknowledge',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await EmergencyService.instance.resolveAlert(
                familyId: alert.familyId,
                alertId: alert.id,
                parentId: auth?.uid ?? '',
                parentName: parentName,
                resolutionNotes: 'Resolved by parent',
              );
            },
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity History Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityHistoryTab extends ConsumerStatefulWidget {
  final String familyId;
  final String? childId;
  final List<ChildModel> children;
  final ChildModel? selectedChild;

  const _ActivityHistoryTab({
    required this.familyId,
    this.childId,
    required this.children,
    this.selectedChild,
  });

  @override
  ConsumerState<_ActivityHistoryTab> createState() => _ActivityHistoryTabState();
}

class _ActivityHistoryTabState extends ConsumerState<_ActivityHistoryTab> {
  String? _filterChildId;
  String? _filterType;
  final _allTypes = [
    ('all', 'All Events'),
    ('rule_change', 'Rules'),
    ('time_extension', 'Screen Time'),
    ('routine_toggle', 'Routines'),
    ('emergency_sos', 'Emergency'),
    ('safety_checkin', 'Safety'),
    ('quiz_completed', 'Quizzes'),
    ('permission_tamper', 'Security'),
  ];

  @override
  void initState() {
    super.initState();
    _filterChildId = widget.childId;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(familyActivityLogsProvider((
      familyId: widget.familyId,
      childId: _filterChildId,
      type: _filterType,
    )));

    return Column(
      children: [
        // Filter bar
        Container(
          color: isDark ? const Color(0xFF0C1829) : Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              // Child filter
              if (widget.children.isNotEmpty)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All Children',
                          selected: _filterChildId == null,
                          onTap: () => setState(() => _filterChildId = null),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        for (final child in widget.children)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _FilterChip(
                              label: child.displayName,
                              selected: _filterChildId == child.id,
                              onTap: () => setState(() => _filterChildId = child.id),
                              isDark: isDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Type filter
        Container(
          height: 36,
          color: isDark ? const Color(0xFF0C1829) : const Color(0xFFF8FAFC),
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemCount: _allTypes.length,
            itemBuilder: (ctx, i) {
              final (type, label) = _allTypes[i];
              final isSelected = (type == 'all' && _filterType == null) ||
                  (_filterType == type);
              return _FilterChip(
                label: label,
                selected: isSelected,
                onTap: () => setState(() =>
                    _filterType = type == 'all' ? null : type),
                isDark: isDark,
                accent: const Color(0xFF8B5CF6),
              );
            },
          ),
        ),
        // Log list
        Expanded(
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load history from Firebase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(
                      familyActivityLogsProvider((
                        familyId: widget.familyId,
                        childId: _filterChildId,
                        type: _filterType,
                      )),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 56,
                          color: isDark ? Colors.white24 : Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No activity history yet',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (ctx, i) {
                  final log = logs[i];
                  return _ActivityLogCard(
                    log: log,
                    relativeTime: AppFormatters.formatRelativeTime(
                      log.timestamp,
                      includeHoursMinutesInDay: true,
                      fallbackToDateTime: true,
                    ),
                    isDark: isDark,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color accent;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.accent = const Color(0xFF4F46E5),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? accent
              : (isDark ? const Color(0xFF132238) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : (isDark ? const Color(0xFF1E3554) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ActivityLogCard extends StatelessWidget {
  final ActivityLogModel log;
  final String relativeTime;
  final bool isDark;

  const _ActivityLogCard({required this.log, required this.relativeTime, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final type = log.type;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3554) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: type.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(type.icon, color: type.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      relativeTime,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  log.description,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: type.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type.displayName,
                        style: TextStyle(color: type.color, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'by ${log.actorName}',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    if (log.childName.isNotEmpty && log.childName != 'Child') ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${log.childName}',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
