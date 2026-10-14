import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/app_info.dart';
import '../../../../core/models/family_model.dart';
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
  // FIX 1: controller so the clear (X) button really clears the text field.
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  _AppFilter _activeFilter = _AppFilter.all;
  bool _hideSystemApps = false;

  // FIX 6: cache decoded icons so base64Decode is not run on every rebuild.
  final Map<String, Uint8List> _iconCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _quickSetRule(AppInfo app, AppControlRule newRule) async {
    final familyId = _resolveFamilyId();
    final childId = _resolveChildId();
    if (familyId.isEmpty || childId.isEmpty) {
      _showError('Cannot update rule: Family or child not selected.');
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
      _showError('Failed to update rule: $e');
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

  /// Batch actions only ever target user-installed apps.
  /// FIX 3: system apps (dialer, settings, launcher...) are never touched,
  /// so a parent can't accidentally lock the child's phone.
  Future<void> _batchApplyRule(
      List<AppInfo> apps, AppControlRule targetRule) async {
    final familyId = _resolveFamilyId();
    final childId = _resolveChildId();

    // FIX 4: tell the parent instead of failing silently.
    if (familyId.isEmpty || childId.isEmpty) {
      _showError('Cannot update apps: Family or child not selected.');
      return;
    }

    final targetApps = apps.where((a) => !a.isSystemApp).toList();

    if (targetApps.isEmpty) {
      _showError('No user apps to update.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply to ${targetApps.length} Apps?'),
        content: Text(
          'Are you sure you want to set all ${targetApps.length} user apps '
          'to ${_getRuleLabel(targetRule)}? System apps are not affected.',
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
      _showError('Batch update failed: $e');
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
                    Text('Set All User Apps to Ask/Notify'),
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
                    Text('Allow All User Apps'),
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
                  // FIX 7: invalidate instead of an unused ref.refresh result.
                  onPressed: () => ref.invalidate(
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
          final timedCount = allApps
              .where((a) =>
                  a.rule == AppControlRule.timeLimited ||
                  a.rule == AppControlRule.timeRestricted)
              .length;

          return Column(
            children: [
              // Header Summary Metrics
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    // FIX 2: five chips (incl. Timed) in a horizontal scroller.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                          const SizedBox(width: 8),
                          _buildMetricChip(
                            label: 'Timed',
                            count: timedCount,
                            color: const Color(0xFF2563EB),
                            isSelected: _activeFilter == _AppFilter.timeLimited,
                            onTap: () => setState(
                                () => _activeFilter = _AppFilter.timeLimited),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search apps or package name...',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
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
                          ref.invalidate(
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
    return SizedBox(
      width: 88,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
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

  /// Returns decoded icon bytes from cache, decoding only once per app.
  Uint8List? _getIconBytes(AppInfo app) {
    final cached = _iconCache[app.packageName];
    if (cached != null) return cached;

    final data = app.iconBase64;
    if (data == null || data.isEmpty) return null;

    try {
      final bytes = base64Decode(data);
      _iconCache[app.packageName] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Widget _buildAppIcon(AppInfo app) {
    final bytes = _getIconBytes(app);
    if (bytes == null) return _buildFallbackIcon(app);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
          gaplessPlayback: true, // avoids flicker when the list rebuilds
          errorBuilder: (_, __, ___) => _buildFallbackIcon(app),
        ),
      ),
    );
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
          color: isBlocked
              ? Colors.red.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
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
                            color: ruleColor.withValues(alpha: 0.12),
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
                  _buildRuleButton(
                    label: 'Block',
                    icon: Icons.block_rounded,
                    isActive: isBlocked,
                    activeColor: Colors.red[600]!,
                    textColor: Colors.red[700]!,
                    borderColor: Colors.red[200]!,
                    onPressed: () => _quickSetRule(app, AppControlRule.block),
                  ),
                  const SizedBox(width: 8),
                  _buildRuleButton(
                    label: 'Notify',
                    icon: Icons.notifications_active_rounded,
                    isActive: isAsk,
                    activeColor: Colors.amber[700]!,
                    textColor: Colors.amber[900]!,
                    borderColor: Colors.amber[200]!,
                    onPressed: () => _quickSetRule(app, AppControlRule.ask),
                  ),
                  const SizedBox(width: 8),
                  _buildRuleButton(
                    label: 'Allow',
                    icon: Icons.check_circle_rounded,
                    isActive: isAllowed,
                    activeColor: Colors.green[600]!,
                    textColor: Colors.green[700]!,
                    borderColor: Colors.green[200]!,
                    onPressed: () => _quickSetRule(app, AppControlRule.allow),
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

  /// One reusable quick-action button (replaces three near-identical blocks).
  Widget _buildRuleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          foregroundColor: isActive ? Colors.white : textColor,
          backgroundColor: isActive ? activeColor : Colors.transparent,
          side: BorderSide(color: isActive ? activeColor : borderColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                  _searchController.clear();
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