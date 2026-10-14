import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/app_info.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../parent/presentation/widgets/app_rule_editor_sheet.dart';

/// Parent app management screen allowing real-time monitoring and control
/// of child's applications: blocking, allowing, notifying (ask parent),
/// setting time limits, and displaying real application icons.
class ParentAppManagementScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String childId;

  const ParentAppManagementScreen({
    super.key,
    required this.familyId,
    required this.childId,
  });

  @override
  ConsumerState<ParentAppManagementScreen> createState() =>
      _ParentAppManagementScreenState();
}

enum _AppFilter { all, blocked, ask, allowed, timeLimited }

class _ParentAppManagementScreenState
    extends ConsumerState<ParentAppManagementScreen> {
  String _searchQuery = '';
  _AppFilter _activeFilter = _AppFilter.all;
  bool _hideSystemApps = false;

  String _resolveFamilyId() {
    if (widget.familyId.isNotEmpty) return widget.familyId;
    final selectedFamily = ref.read(selectedFamilyProvider);
    if (selectedFamily != null && selectedFamily.id.isNotEmpty) {
      return selectedFamily.id;
    }
    final user = ref.read(currentUserDataProvider).value;
    return user?.familyId ?? '';
  }

  String _resolveChildId() {
    if (widget.childId.isNotEmpty) return widget.childId;
    final selectedChild = ref.read(selectedChildProvider);
    return selectedChild?.id ?? '';
  }

  Future<void> _quickSetRule(AppInfo app, AppControlRule newRule) async {
    final familyId = _resolveFamilyId();
    final childId = _resolveChildId();
    if (familyId.isEmpty || childId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot update rule: Family or child not selected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ref.read(appRuleServiceProvider).updateAppRule(
            familyId: familyId,
            childId: childId,
            packageName: app.packageName,
            rule: newRule,
            dailyLimitMinutes: newRule == AppControlRule.timeLimited
                ? (app.dailyLimitMinutes ?? 60)
                : null,
            allowedFrom: newRule == AppControlRule.timeRestricted
                ? app.allowedFrom
                : null,
            allowedUntil: newRule == AppControlRule.timeRestricted
                ? app.allowedUntil
                : null,
          );

      if (mounted) {
        final ruleLabel = _getRuleLabel(newRule);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app.name} is now $ruleLabel'),
            duration: const Duration(seconds: 2),
            backgroundColor: _getRuleColor(newRule),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update rule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openRuleEditor(AppInfo app, Map<String, AppUsageModel> usageMap) {
    final familyId = _resolveFamilyId();
    final childId = _resolveChildId();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppRuleEditorSheet(
        appWithUsage: AppWithUsage(
          app: app,
          usage: usageMap[app.packageName],
        ),
        familyId: familyId,
        childId: childId,
      ),
    );
  }

  Future<void> _batchApplyRule(
      List<AppInfo> apps, AppControlRule targetRule) async {
    final familyId = _resolveFamilyId();
    final childId = _resolveChildId();
    if (familyId.isEmpty || childId.isEmpty) return;

    final targetApps = _hideSystemApps
        ? apps.where((a) => !a.isSystemApp).toList()
        : apps;

    if (targetApps.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply to ${targetApps.length} Apps?'),
        content: Text(
          'Are you sure you want to set all ${targetApps.length} apps to ${_getRuleLabel(targetRule)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRuleColor(targetRule),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final updates = targetApps
          .map((a) => BatchAppRuleUpdate(
                packageName: a.packageName,
                rule: targetRule,
              ))
          .toList();

      await ref.read(appRuleServiceProvider).batchUpdateAppRules(
            familyId: familyId,
            childId: childId,
            updates: updates,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Updated ${targetApps.length} apps to ${_getRuleLabel(targetRule)}'),
            backgroundColor: _getRuleColor(targetRule),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyId = _resolveFamilyId();
    final childId = _resolveChildId();

    final appsAsync = ref.watch(
      familyChildAppsProvider(
        FamilyChildParams(familyId: familyId, childId: childId),
      ),
    );
    final usageAsync = ref.watch(childAppUsageProvider(childId));
    final usageMap = usageAsync.value ?? <String, AppUsageModel>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'App Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Batch Actions',
            onSelected: (action) {
              final apps = appsAsync.value ?? [];
              if (action == 'block_all') {
                _batchApplyRule(apps, AppControlRule.block);
              } else if (action == 'allow_all') {
                _batchApplyRule(apps, AppControlRule.allow);
              } else if (action == 'ask_all') {
                _batchApplyRule(apps, AppControlRule.ask);
              } else if (action == 'toggle_system') {
                setState(() => _hideSystemApps = !_hideSystemApps);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_system',
                child: Row(
                  children: [
                    Icon(
                      _hideSystemApps
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 12),
                    Text(_hideSystemApps
                        ? 'Show System Apps'
                        : 'Hide System Apps'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'block_all',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Block All User Apps'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ask_all',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        size: 20, color: Colors.amber),
                    SizedBox(width: 12),
                    Text('Set All to Ask/Notify'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'allow_all',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Allow All Apps'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: appsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              SizedBox(height: 16),
              Text(
                'Loading child applications...',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 56, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load applications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(
                    familyChildAppsProvider(
                      FamilyChildParams(familyId: familyId, childId: childId),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (allApps) {
          final appsList = allApps.where((app) {
            if (_hideSystemApps && app.isSystemApp) return false;
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesName = app.name.toLowerCase().contains(query);
              final matchesPkg = app.packageName.toLowerCase().contains(query);
              if (!matchesName && !matchesPkg) return false;
            }
            switch (_activeFilter) {
              case _AppFilter.all:
                return true;
              case _AppFilter.blocked:
                return app.rule == AppControlRule.block;
              case _AppFilter.ask:
                return app.rule == AppControlRule.ask;
              case _AppFilter.allowed:
                return app.rule == AppControlRule.allow;
              case _AppFilter.timeLimited:
                return app.rule == AppControlRule.timeLimited ||
                    app.rule == AppControlRule.timeRestricted;
            }
          }).toList();

          final totalCount = allApps.length;
          final blockedCount =
              allApps.where((a) => a.rule == AppControlRule.block).length;
          final askCount =
              allApps.where((a) => a.rule == AppControlRule.ask).length;
          final allowedCount =
              allApps.where((a) => a.rule == AppControlRule.allow).length;

          return Column(
            children: [
              // Header Summary Metrics
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildMetricChip(
                          label: 'Total',
                          count: totalCount,
                          color: const Color(0xFF1E3A8A),
                          isSelected: _activeFilter == _AppFilter.all,
                          onTap: () =>
                              setState(() => _activeFilter = _AppFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricChip(
                          label: 'Blocked',
                          count: blockedCount,
                          color: Colors.red[700]!,
                          isSelected: _activeFilter == _AppFilter.blocked,
                          onTap: () => setState(
                              () => _activeFilter = _AppFilter.blocked),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricChip(
                          label: 'Notify / Ask',
                          count: askCount,
                          color: Colors.amber[800]!,
                          isSelected: _activeFilter == _AppFilter.ask,
                          onTap: () =>
                              setState(() => _activeFilter = _AppFilter.ask),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricChip(
                          label: 'Allowed',
                          count: allowedCount,
                          color: Colors.green[700]!,
                          isSelected: _activeFilter == _AppFilter.allowed,
                          onTap: () => setState(
                              () => _activeFilter = _AppFilter.allowed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search apps or package name...',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (query) {
                        setState(() => _searchQuery = query);
                      },
                    ),
                  ],
                ),
              ),

              // Apps List / Empty View
              Expanded(
                child: appsList.isEmpty
                    ? _buildEmptyState(allApps.isEmpty)
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.refresh(
                            familyChildAppsProvider(
                              FamilyChildParams(
                                familyId: familyId,
                                childId: childId,
                              ),
                            ),
                          );
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: appsList.length,
                          itemBuilder: (context, index) {
                            final app = appsList[index];
                            return _buildAppCard(app, usageMap);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(AppInfo app) {
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64!);
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.memory(
              bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackIcon(app),
            ),
          ),
        );
      } catch (_) {
        return _buildFallbackIcon(app);
      }
    }
    return _buildFallbackIcon(app);
  }

  Widget _buildFallbackIcon(AppInfo app) {
    final letter = app.name.isNotEmpty ? app.name[0].toUpperCase() : 'A';
    final colors = [
      Colors.blue[700]!,
      Colors.indigo[600]!,
      Colors.teal[700]!,
      Colors.deepPurple[600]!,
      Colors.orange[700]!,
    ];
    final color = colors[app.packageName.hashCode.abs() % colors.length];

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAppCard(AppInfo app, Map<String, AppUsageModel> usageMap) {
    final ruleColor = _getRuleColor(app.rule);
    final ruleLabel = _getRuleLabel(app.rule);
    final isBlocked = app.rule == AppControlRule.block;
    final isAsk = app.rule == AppControlRule.ask;
    final isAllowed = app.rule == AppControlRule.allow;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBlocked ? Colors.red.withOpacity(0.4) : const Color(0xFFE2E8F0),
          width: isBlocked ? 1.5 : 1.0,
        ),
      ),
      color: isBlocked ? const Color(0xFFFEF2F2) : Colors.white,
      child: InkWell(
        onTap: () => _openRuleEditor(app, usageMap),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: App Icon + Name + Current Rule Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAppIcon(app),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                app.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (app.isSystemApp) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'System',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          app.packageName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Rule Status Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ruleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getRuleIcon(app.rule),
                                  size: 13, color: ruleColor),
                              const SizedBox(width: 4),
                              Text(
                                ruleLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ruleColor,
                                ),
                              ),
                              if (app.rule == AppControlRule.timeLimited &&
                                  app.dailyLimitMinutes != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${app.dailyLimitMinutes}m/day)',
                                  style: TextStyle(
                                      fontSize: 10, color: ruleColor),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Action Toolbar: Block, Notify/Ask, Allow, Configure
              Row(
                children: [
                  // Block Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        foregroundColor:
                            isBlocked ? Colors.white : Colors.red[700],
                        backgroundColor:
                            isBlocked ? Colors.red[600] : Colors.transparent,
                        side: BorderSide(
                          color: isBlocked ? Colors.red[600]! : Colors.red[200]!,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _quickSetRule(app, AppControlRule.block),
                      icon: const Icon(Icons.block_rounded, size: 16),
                      label: const Text('Block',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Notify / Ask Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        foregroundColor:
                            isAsk ? Colors.white : Colors.amber[900],
                        backgroundColor:
                            isAsk ? Colors.amber[700] : Colors.transparent,
                        side: BorderSide(
                          color: isAsk ? Colors.amber[700]! : Colors.amber[200]!,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _quickSetRule(app, AppControlRule.ask),
                      icon: const Icon(Icons.notifications_active_rounded, size: 16),
                      label: const Text('Notify',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Allow Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        foregroundColor:
                            isAllowed ? Colors.white : Colors.green[700],
                        backgroundColor:
                            isAllowed ? Colors.green[600] : Colors.transparent,
                        side: BorderSide(
                          color: isAllowed
                              ? Colors.green[600]!
                              : Colors.green[200]!,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _quickSetRule(app, AppControlRule.allow),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Allow',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // More Settings
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    tooltip: 'More Rules & Limits',
                    color: Colors.blueGrey,
                    onPressed: () => _openRuleEditor(app, usageMap),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noAppsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noAppsAtAll
                  ? Icons.phonelink_setup_rounded
                  : Icons.search_off_rounded,
              size: 64,
              color: Colors.blueGrey[300],
            ),
            const SizedBox(height: 16),
            Text(
              noAppsAtAll ? 'No Installed Apps Yet' : 'No Matching Apps Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noAppsAtAll
                  ? 'Once your child connects and launches the companion app, installed apps and icons will appear here automatically.'
                  : 'Try clearing your search query or filter chips.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (!noAppsAtAll) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _activeFilter = _AppFilter.all;
                  });
                },
                child: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRuleColor(AppControlRule rule) {
    switch (rule) {
      case AppControlRule.block:
        return const Color(0xFFDC2626); // Crimson
      case AppControlRule.ask:
        return const Color(0xFFD97706); // Amber / Notify
      case AppControlRule.timeLimited:
        return const Color(0xFF2563EB); // Royal Blue
      case AppControlRule.timeRestricted:
        return const Color(0xFF7C3AED); // Purple
      case AppControlRule.allow:
        return const Color(0xFF16A34A); // Green
    }
  }

  String _getRuleLabel(AppControlRule rule) {
    switch (rule) {
      case AppControlRule.block:
        return 'Blocked';
      case AppControlRule.ask:
        return 'Notify / Ask Parent';
      case AppControlRule.timeLimited:
        return 'Time Limited';
      case AppControlRule.timeRestricted:
        return 'Schedule Restricted';
      case AppControlRule.allow:
        return 'Allowed';
    }
  }

  IconData _getRuleIcon(AppControlRule rule) {
    switch (rule) {
      case AppControlRule.block:
        return Icons.block_rounded;
      case AppControlRule.ask:
        return Icons.notifications_active_rounded;
      case AppControlRule.timeLimited:
        return Icons.timer_rounded;
      case AppControlRule.timeRestricted:
        return Icons.schedule_rounded;
      case AppControlRule.allow:
        return Icons.check_circle_rounded;
    }
  }
}