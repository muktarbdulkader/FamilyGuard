import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/app_scanner_service.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/widgets/app_icon_widget.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/family_bottom_navigation.dart';
import '../../../../l10n/app_localizations.dart';

// ─── Brand colours (same as rest of app) ────────────────────────────────────
const _kPrimary = Color(0xFF4F46E5);
const _kPrimaryDark = Color(0xFF7C3AED);
const _kSurface = Color(0xFFEEF2FF);
const _kBorder = Color(0xFFC7D2FE);
const _kText = Color(0xFF3730A3);

/// Child-facing app-management screen.
/// Shows every installed app with its parent-set status badge and usage bar.
/// All logic is 100 % reused from [AppScannerService] + [AppIconWidget].
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

  // ── tabs ──────────────────────────────────────────────────────────────────
  late TabController _tabCtrl;

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(_applyFilter);
    _boot();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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

      // Fire-and-forget upload
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
        _showSnack('${newApps.length} new apps detected', Colors.orange);
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
    final userApps = _filtered.where((a) => !a.isSystemApp).length;
    final sysApps = _filtered.where((a) => a.isSystemApp).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: _buildAppBar(l10n),
      body: Column(
        children: [
          _InfoBanner(),
          _StatsRow(total: _all.length, user: userApps, system: sysApps),
          _SearchAndFilter(
            controller: _searchCtrl,
            active: _activeFilter,
            onFilterChanged: (f) {
              setState(() => _activeFilter = f);
              _applyFilter();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _isScanning
          ? null
          : FloatingActionButton(
              onPressed: _refresh,
              backgroundColor: _kPrimary,
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

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
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
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPrimary, _kPrimaryDark],
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

  Widget _buildBody() {
    if (_isScanning && _all.isEmpty) return _LoadingView();
    if (_errorMessage != null) return _ErrorView(message: _errorMessage!, onRetry: _refresh);
    if (_filtered.isEmpty && _all.isNotEmpty) return _EmptySearchView();
    if (_all.isEmpty) return _EmptyAppsView(onScan: _refresh);
    return _AppList(apps: _filtered, onTap: _showDetails);
  }

  // ── details sheet ─────────────────────────────────────────────────────────
  void _showDetails(InstalledAppInfo app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppDetailsSheet(app: app),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRIVATE CHILD WIDGETS  (all stateless, reuse AppIconWidget + AppFormatters)
// ════════════════════════════════════════════════════════════════════════════

enum _AppFilter { all, user, system }

// ── Info banner ──────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
          bottom: BorderSide(color: _kBorder.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: _kPrimary, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Your parents can see and manage these apps',
              style: TextStyle(
                color: _kText,
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
  const _StatsRow({required this.total, required this.user, required this.system});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _StatChip(label: 'Total', value: total, color: _kPrimary),
          const SizedBox(width: 8),
          _StatChip(label: 'Your apps', value: user, color: Colors.green.shade700),
          const SizedBox(width: 8),
          _StatChip(label: 'System', value: system, color: Colors.blueGrey),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14,
            ),
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
  final ValueChanged<_AppFilter> onFilterChanged;

  const _SearchAndFilter({
    required this.controller,
    required this.active,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search apps…',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _kPrimary),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, v, __) => v.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
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
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? _kPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? _kPrimary : _kBorder,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : _kText,
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
  final ValueChanged<InstalledAppInfo> onTap;

  const _AppList({required this.apps, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: apps.length,
      itemBuilder: (ctx, i) => _AppTile(app: apps[i], onTap: onTap),
    );
  }
}

// ── Single app tile ───────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final InstalledAppInfo app;
  final ValueChanged<InstalledAppInfo> onTap;

  const _AppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final installLabel =
        AppFormatters.formatRelativeTime(app.installTime, fallbackToDateTime: true);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(app),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // ── icon ──────────────────────────────────────────────────
                _AppIconFromBytes(bytes: app.iconBytes, size: 50),
                const SizedBox(width: 12),
                // ── text section ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (app.isSystemApp) ...[
                            _Badge(label: 'System', color: Colors.blueGrey),
                            const SizedBox(width: 6),
                          ] else ...[
                            _Badge(label: 'App', color: Colors.green.shade700),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              'v${app.version}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── meta ──────────────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                    const SizedBox(height: 4),
                    Text(
                      installLabel,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
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
        color: color.withOpacity(0.1),
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

// ── Icon from raw bytes (child device gives Uint8List, not base64 string) ────
class _AppIconFromBytes extends StatelessWidget {
  final dynamic bytes; // Uint8List? from InstalledAppInfo
  final double size;
  const _AppIconFromBytes({required this.bytes, this.size = 48});

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
        fallbackColor: _kPrimary,
        fallbackIcon: Icons.android_rounded,
      );
}

// ── Details bottom sheet ──────────────────────────────────────────────────────
class _AppDetailsSheet extends StatelessWidget {
  final InstalledAppInfo app;
  const _AppDetailsSheet({required this.app});

  @override
  Widget build(BuildContext context) {
    final installDate = app.installTime;
    final updateDate = app.lastUpdateTime;
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // App header
          Row(
            children: [
              _AppIconFromBytes(bytes: app.iconBytes, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.isSystemApp ? 'System App' : 'User App',
                      style: TextStyle(
                        fontSize: 12,
                        color: app.isSystemApp
                            ? Colors.blueGrey
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Details grid
          _DetailRow(icon: Icons.label_outline_rounded, label: 'Package', value: app.packageName),
          _DetailRow(icon: Icons.info_outline_rounded, label: 'Version', value: 'v${app.version}'),
          _DetailRow(icon: Icons.download_rounded, label: 'Installed', value: fmt(installDate)),
          _DetailRow(icon: Icons.update_rounded, label: 'Updated', value: fmt(updateDate)),

          const SizedBox(height: 20),

          // Notice card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: _kPrimary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your parents control the rules for this app.',
                    style: TextStyle(fontSize: 12, color: _kText, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Close button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _kPrimary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _kPrimary),
          SizedBox(height: 20),
          Text('Scanning your apps…', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'This may take a moment',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppsView extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyAppsView({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps_outage_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No apps found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to scan your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Scan Now'),
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No apps match your search', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
