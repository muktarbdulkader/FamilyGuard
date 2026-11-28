import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/app_scanner_service.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon_widget.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/family_bottom_navigation.dart';
import '../../../../l10n/app_localizations.dart';

/// Child-facing app-management screen.
/// Colours are fully driven by [AppColors] / [appColorsProvider] so dark-mode
/// and light-mode work automatically — identical to every other child screen.
class ChildAppsScreen extends ConsumerStatefulWidget {
  const ChildAppsScreen({super.key});

  @override
  ConsumerState<ChildAppsScreen> createState() => _ChildAppsScreenState();
}

class _ChildAppsScreenState extends ConsumerState<ChildAppsScreen>
    with SingleTickerProviderStateMixin {
  // ── services / state ───────────────────────────────────────────────────────
  final AppScannerService _scanner = AppScannerService();
  List<InstalledAppInfo> _all = [];
  List<InstalledAppInfo> _filtered = [];
  bool _isScanning = false;
  String? _errorMessage;
  Timer? _periodicTimer;

  // ── filter / search ────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  _AppFilter _activeFilter = _AppFilter.all;

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _boot();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _periodicTimer?.cancel();
    _scanner.stopAppInstallationMonitoring();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────
  Future<void> _boot() async {
    await _refresh();
    _startMonitoring();
  }

  Future<void> _refresh() async {
    final user = ref.read(currentUserDataProvider).value;
    if (user == null || !user.hasFamily) {
      setState(() => _errorMessage = 'Join a family first to see your apps.');
      return;
    }
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });
    try {
      final apps = await _scanner.scanInstalledApps();
      setState(() {
        _all = apps;
        _isScanning = false;
      });
      _applyFilter();
      unawaited(
        _scanner
            .uploadAppsToFirestore(
              familyId: user.familyId!,
              childId: user.uid,
              apps: apps,
            )
            .catchError((e) => debugPrint('Upload error: $e')),
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Could not read installed apps.\n${e.toString()}';
      });
    }
  }

  void _startMonitoring() {
    final user = ref.read(currentUserDataProvider).value;
    if (user == null || !user.hasFamily) return;
    _scanner
        .startAppInstallationMonitoring(
          familyId: user.familyId!,
          childId: user.uid,
        )
        .catchError((_) {});
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final u = ref.read(currentUserDataProvider).value;
      if (u == null || !u.hasFamily) return;
      final newApps = await _scanner
          .checkForNewApps(familyId: u.familyId!, childId: u.uid)
          .catchError((_) => <InstalledAppInfo>[]);
      if (newApps.isNotEmpty && mounted) {
        _showSnack('${newApps.length} new apps detected', AppColors.of(context).warning);
        await _refresh();
      }
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((a) {
        final matchSearch = q.isEmpty ||
            a.appName.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q);
        final matchFilter = switch (_activeFilter) {
          _AppFilter.all => true,
          _AppFilter.user => !a.isSystemApp,
          _AppFilter.system => a.isSystemApp,
        };
        return matchSearch && matchFilter;
      }).toList();
    });
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserDataProvider).value;
    final colors = ref.watch(appColorsProvider); // ← reactive to theme toggle
    final userCount = _filtered.where((a) => !a.isSystemApp).length;
    final sysCount = _filtered.where((a) => a.isSystemApp).length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(l10n, colors),
      body: Column(
        children: [
          _InfoBanner(colors: colors),
          _StatsRow(total: _all.length, user: userCount, system: sysCount, colors: colors),
          _SearchAndFilter(
            controller: _searchCtrl,
            active: _activeFilter,
            colors: colors,
            onFilterChanged: (f) {
              setState(() => _activeFilter = f);
              _applyFilter();
            },
          ),
          Expanded(child: _buildBody(colors)),
        ],
      ),
      floatingActionButton: _isScanning
          ? null
          : FloatingActionButton(
              onPressed: _refresh,
              backgroundColor: colors.primary,
              tooltip: l10n.refresh,
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
      bottomNavigationBar: FamilyBottomNavigation(
        isParent: false,
        selected: FamilyNavDestination.apps,
        familyId: user?.familyId,
        childId: user?.uid,
        childName: user?.displayName,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n, AppColors colors) {
    // Gradient: same teal-to-indigo used on the child home screen in dark mode,
    // indigo-to-purple in light mode — matches app_colors.primary.
    final gradientStart = colors.isDark
        ? const Color(0xFF0D5E57)   // forest teal (dark)
        : const Color(0xFF4F46E5);  // indigo (light)
    final gradientEnd = colors.isDark
        ? AppColors.tealAccent       // bright teal (dark)
        : const Color(0xFF7C3AED);  // purple (light)

    return AppBar(
      backgroundColor: gradientStart,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.childHome),
      ),
      title: Text(
        l10n.apps,
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        if (_isScanning)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
            onPressed: _refresh,
          ),
      ],
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isScanning && _all.isEmpty) return _LoadingView(colors: colors);
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onRetry: _refresh, colors: colors);
    }
    if (_filtered.isEmpty && _all.isNotEmpty) return _EmptySearchView(colors: colors);
    if (_all.isEmpty) return _EmptyAppsView(onScan: _refresh, colors: colors);
    return _AppList(apps: _filtered, colors: colors, onTap: _showDetails);
  }

  void _showDetails(InstalledAppInfo app) {
    final colors = ref.read(appColorsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppDetailsSheet(app: app, colors: colors),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRIVATE CHILD WIDGETS — all receive [AppColors] so they never hardcode hex
// ════════════════════════════════════════════════════════════════════════════

enum _AppFilter { all, user, system }

// ── Info banner ──────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final AppColors colors;
  const _InfoBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.heroBg,
        border: Border(bottom: BorderSide(color: colors.heroBorder.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: colors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your parents can see and manage these apps',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total, user, system;
  final AppColors colors;
  const _StatsRow({
    required this.total,
    required this.user,
    required this.system,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _StatChip(label: 'Total', value: total, color: colors.primary),
          const SizedBox(width: 8),
          _StatChip(label: 'My Apps', value: user, color: colors.success),
          const SizedBox(width: 8),
          _StatChip(label: 'System', value: system, color: colors.textSecondary),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

// ── Search + filter bar ──────────────────────────────────────────────────────
class _SearchAndFilter extends StatelessWidget {
  final TextEditingController controller;
  final _AppFilter active;
  final AppColors colors;
  final ValueChanged<_AppFilter> onFilterChanged;

  const _SearchAndFilter({
    required this.controller,
    required this.active,
    required this.colors,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          // Search box
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search apps…',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.primary),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, v, __) => v.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18, color: colors.textSecondary),
                          onPressed: controller.clear,
                        )
                      : const SizedBox.shrink(),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Filter chips
          Row(
            children: _AppFilter.values.map((f) {
              final isActive = f == active;
              final label = switch (f) {
                _AppFilter.all => 'All',
                _AppFilter.user => 'My Apps',
                _AppFilter.system => 'System',
              };
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onFilterChanged(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? colors.primary : colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? colors.primary : colors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── App list ─────────────────────────────────────────────────────────────────
class _AppList extends StatelessWidget {
  final List<InstalledAppInfo> apps;
  final AppColors colors;
  final ValueChanged<InstalledAppInfo> onTap;

  const _AppList({required this.apps, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: apps.length,
      itemBuilder: (ctx, i) => _AppTile(app: apps[i], colors: colors, onTap: onTap),
    );
  }
}

// ── Single app tile ───────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final InstalledAppInfo app;
  final AppColors colors;
  final ValueChanged<InstalledAppInfo> onTap;

  const _AppTile({required this.app, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final installLabel =
        AppFormatters.formatRelativeTime(app.installTime, fallbackToDateTime: true);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(app),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _AppIconFromBytes(bytes: app.iconBytes, size: 50, colors: colors),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _Badge(
                            label: app.isSystemApp ? 'System' : 'App',
                            color: app.isSystemApp ? colors.textSecondary : colors.success,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'v${app.version}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: colors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.chevron_right_rounded, color: colors.border, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      installLabel,
                      style: TextStyle(fontSize: 10, color: colors.textMuted),
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

// ── Small badge chip ──────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Icon from raw Uint8List bytes (child device) with AppIconWidget fallback ──
class _AppIconFromBytes extends StatelessWidget {
  final dynamic bytes; // Uint8List? from InstalledAppInfo
  final double size;
  final AppColors colors;
  const _AppIconFromBytes({required this.bytes, required this.colors, this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => AppIconWidget(
        iconBase64: null,
        size: size,
        borderRadius: 10,
        fallbackColor: colors.primary,
        fallbackIcon: Icons.android_rounded,
      );
}

// ── Details bottom sheet ──────────────────────────────────────────────────────
class _AppDetailsSheet extends StatelessWidget {
  final InstalledAppInfo app;
  final AppColors colors;
  const _AppDetailsSheet({required this.app, required this.colors});

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // App header
          Row(
            children: [
              _AppIconFromBytes(bytes: app.iconBytes, size: 56, colors: colors),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.isSystemApp ? 'System App' : 'User App',
                      style: TextStyle(
                        fontSize: 12,
                        color: app.isSystemApp ? colors.textSecondary : colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 16),

          // Details rows
          _SheetDetailRow(
            icon: Icons.label_outline_rounded,
            label: 'Package',
            value: app.packageName,
            colors: colors,
          ),
          _SheetDetailRow(
            icon: Icons.info_outline_rounded,
            label: 'Version',
            value: 'v${app.version}',
            colors: colors,
          ),
          _SheetDetailRow(
            icon: Icons.download_rounded,
            label: 'Installed',
            value: fmt(app.installTime),
            colors: colors,
          ),
          _SheetDetailRow(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: fmt(app.lastUpdateTime),
            colors: colors,
          ),

          const SizedBox(height: 16),

          // Notice card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.heroBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.heroBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your parents control the rules for this app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Close
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppColors colors;
  const _SheetDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading / empty / error views ─────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  final AppColors colors;
  const _LoadingView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 20),
          Text(
            'Scanning your apps…',
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'This may take a moment',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppsView extends StatelessWidget {
  final VoidCallback onScan;
  final AppColors colors;
  const _EmptyAppsView({required this.onScan, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps_outage_rounded, size: 72, color: colors.border),
            const SizedBox(height: 16),
            Text(
              'No apps found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to scan your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Scan Now'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchView extends StatelessWidget {
  final AppColors colors;
  const _EmptySearchView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: colors.border),
          const SizedBox(height: 12),
          Text(
            'No apps match your search',
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppColors colors;
  const _ErrorView({required this.message, required this.onRetry, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: colors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
