import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';

import 'dart:async';
import '../../../../core/services/app_scanner_service.dart';
import '../../../../core/services/monitoring_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/education_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../child/presentation/screens/child_education_screen.dart';

/// Pixel-matched Child Companion Home Screen
/// Matches the exact sleek dark teal & slate styling:
/// - Squircle teal shield icon
/// - Forest teal "You are safe right now" hero card
/// - Learning & Protection cards with [Apps | Location | Lessons / Ask Parent] buttons
/// - Bottom navigation bar with [Home | Apps | Lessons | Health | Setup]
/// - Clean layout with zero duplicate icons
class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  bool _hasTriggeredSync = false;
  bool _hasUsageStats = true;
  bool _hasOverlay = true;
  bool _hasLocationPermission = true;
  final _permissionService = PermissionService();

  static const Color _bgDark = AppColors.darkNavyBg;
  static const Color _cardBg = AppColors.darkNavyCard;
  static const Color _cardBorder = AppColors.darkNavyBorder;
  static const Color _tealAccent = AppColors.tealAccent;
  static const Color _heroBg = AppColors.heroForestTeal;
  static const Color _heroBorder = AppColors.heroForestBorder;
  static const Color _metricBg = AppColors.metricDarkBg;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final usage = await _permissionService.hasUsageStatsPermission();
    final overlay = await _permissionService.hasOverlayPermission();
    final locInfo = await LocationService().checkLocationPermission();
    if (mounted) {
      setState(() {
        _hasUsageStats = usage;
        _hasOverlay = overlay;
        _hasLocationPermission = locInfo.canShareLocation;
      });
    }
  }

  void _triggerBackgroundSync(dynamic user) {
    if (_hasTriggeredSync || user == null || user.hasFamily != true) return;
    _hasTriggeredSync = true;

    final familyId = user.familyId as String?;
    final childId = user.uid as String?;
    final childName = (user.displayName as String?) ?? (user.name as String?) ?? 'Child';
    if (familyId == null || childId == null) return;

    NotificationService.instance.startChildNotificationListener(childId);

    unawaited(() async {
      try {
        final scanner = AppScannerService();
        final apps = await scanner.scanInstalledApps();
        await scanner.uploadAppsToFirestore(
          familyId: familyId,
          childId: childId,
          apps: apps,
        );
        await MonitoringService().startMonitoring(
          familyId: familyId,
          childId: childId,
          childName: childName,
          appRules: [],
        );
        await LocationService().startChildSharing(
          familyId: familyId,
          childId: childId,
          childName: childName,
        );
      } catch (e) {
        debugPrint('Auto sync in ChildHomeScreen error: $e');
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userData = ref.watch(currentUserDataProvider);

    userData.whenData((user) => _triggerBackgroundSync(user));

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: userData.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _tealAccent, strokeWidth: 3),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                  const SizedBox(height: 12),
                  Text(l10n.errorLoadingDashboard, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(currentUserDataProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealAccent,
                      foregroundColor: const Color(0xFF0C1829),
                    ),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
          data: (user) => Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Top App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // Squircle teal shield
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _tealAccent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.shield_outlined,
                                      color: Color(0xFF062B28),
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.appName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${l10n.welcomeMessage} ${user?.displayName ?? 'Friend'}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
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
                          // Settings & Sign Out button
                          InkWell(
                            onTap: () => _showSettingsSheet(context, ref, user, l10n),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF14243B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _cardBorder),
                              ),
                              child: const Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Missing Permission Alert Banner (if any)
                  if (!_hasUsageStats || !_hasOverlay || !_hasLocationPermission)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              if (!_hasUsageStats) {
                                await _permissionService.openUsageStatsSettings();
                              } else if (!_hasOverlay) {
                                await _permissionService.openOverlaySettings();
                              } else if (!_hasLocationPermission) {
                                await LocationService().requestLocationPermission();
                              }
                              await Future.delayed(const Duration(milliseconds: 800));
                              await _checkPermissions();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFB45309), Color(0xFFD97706)],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Protection Setup Needed',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          !_hasUsageStats
                                              ? 'Tap to grant Usage Access for screen limits.'
                                              : !_hasOverlay
                                                  ? 'Tap to enable "Display over other apps".'
                                                  : 'Tap to enable Location sharing for parents.',
                                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 3. Hero Card: "Your device is safe right now"
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: _heroBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _heroBorder, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.allProtectionsOn,
                              style: const TextStyle(
                                color: _tealAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.childSafe,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Metrics row
                            Row(
                              children: [
                                _buildMetricBox(l10n.limits, 'Balanced'),
                                const SizedBox(width: 10),
                                _buildMetricBox(l10n.lessons, 'Active'),
                                const SizedBox(width: 10),
                                _buildMetricBox(l10n.role, user?.hasFamily == true ? 'Linked' : 'Pair Code'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Learning Header & Card
                  if (user?.hasFamily == true && user?.familyId != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.myLearning,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildEducationCard(context, user!.familyId!, user.uid, user.displayName),
                          ],
                        ),
                      ),
                    ),

                  // 5. My Device & Protection Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.myProtection,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (user?.hasFamily != true)
                            InkWell(
                              onTap: () => context.push(AppRoutes.familyJoin),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Text(
                                  '+ Join family',
                                  style: TextStyle(
                                    color: _tealAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 6. Child Status Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildChildDeviceCard(context, user),
                    ),
                  ),

                  // Bottom padding for the floating navigation bar
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),

              // Floating Bottom Navigation Bar
              Positioned(
                bottom: 16,
                left: 18,
                right: 18,
                child: _buildChildFloatingBottomBar(context, user, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Metric Box in Hero Card ─────────────────────────────────────────
  Widget _buildMetricBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _metricBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF093530)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF86A5A1),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Education Card ─────────────────────────────────────────────────
  Widget _buildEducationCard(BuildContext context, String familyId, String childId, String childName) {
    final materialsAsync = ref.watch(
      childEducationalMaterialsProvider((familyId: familyId, childId: childId)),
    );

    final pendingCount = materialsAsync.when(
      data: (materials) => materials.where((m) => !m.isCompletedBy(childId)).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _tealAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.school_rounded, color: Color(0xFF042421), size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Study & Lessons',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$pendingCount NEW',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount lesson${pendingCount != 1 ? 's' : ''} assigned by your parents.'
                          : 'Explore study videos, notes, and lessons.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF8BA0B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Solid teal Lessons action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildEducationScreen(
                    familyId: familyId,
                    childId: childId,
                    childName: childName,
                  ),
                ),
              ),
              icon: const Icon(Icons.school_outlined, size: 18, color: Color(0xFF042421)),
              label: const Text(
                'Open Lessons',
                style: TextStyle(
                  color: Color(0xFF042421),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tealAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Child Device Card ──────────────────────────────────────────────
  Widget _buildChildDeviceCard(BuildContext context, dynamic user) {
    final childName = user?.displayName ?? 'Child';
    final initial = childName.isNotEmpty ? childName[0].toUpperCase() : 'C';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar squircle with status dot
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _tealAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF042421),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: _cardBg, width: 2.2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email != null && user.email.isNotEmpty ? user.email : 'This Device',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8BA0B8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: _tealAccent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Protected · online',
                          style: TextStyle(
                            color: _tealAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Three action buttons
          Row(
            children: [
              // Apps button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.apps_rounded,
                  label: 'Apps',
                  isSolid: false,
                  onTap: () => context.push(AppRoutes.childApps),
                ),
              ),
              const SizedBox(width: 10),
              // Health button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Health',
                  isSolid: false,
                  onTap: () => context.push(AppRoutes.childStatus),
                ),
              ),
              const SizedBox(width: 10),
              // Setup / Permissions (Solid teal)
              Expanded(
                child: _buildActionButton(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Setup',
                  isSolid: true,
                  onTap: () => context.push(AppRoutes.childPermissions),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isSolid,
    required VoidCallback onTap,
  }) {
    if (isSolid) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: const Color(0xFF042421)),
        label: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF042421),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _tealAccent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF0E1A2C),
          side: const BorderSide(color: Color(0xFF223A5B)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  // ── Floating Bottom Navigation Bar for Child ────────────────────────
  Widget _buildChildFloatingBottomBar(BuildContext context, dynamic user, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1424),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E3554)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Home (Selected)
          _buildNavPill(
            icon: Icons.home_outlined,
            label: l10n.home,
            isSelected: true,
            onTap: () {},
          ),
          // Apps
          _buildNavPill(
            icon: Icons.grid_view_rounded,
            label: l10n.apps,
            isSelected: false,
            onTap: () => context.push(AppRoutes.childApps),
          ),
          // Lessons
          _buildNavPill(
            icon: Icons.school_outlined,
            label: l10n.lessons,
            isSelected: false,
            onTap: () {
              if (user?.familyId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildEducationScreen(
                      familyId: user!.familyId!,
                      childId: user.uid,
                      childName: user.displayName ?? 'Me',
                    ),
                  ),
                );
              }
            },
          ),
          // Health
          _buildNavPill(
            icon: Icons.health_and_safety_outlined,
            label: l10n.health,
            isSelected: false,
            onTap: () => context.push(AppRoutes.childStatus),
          ),
          // Permissions / Setup
          _buildNavPill(
            icon: Icons.shield_outlined,
            label: l10n.setup,
            isSelected: false,
            onTap: () => context.push(AppRoutes.childPermissions),
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    if (isSelected) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E3835),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _tealAccent, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: _tealAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF475569), size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showMonitoringInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _cardBorder),
        ),
        title: Row(
          children: const [
            Icon(Icons.shield_rounded, color: _tealAccent),
            SizedBox(width: 10),
            Text('About Smart Guard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'FamilyGuard keeps your device balanced and safe:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text('• Helps balance study, apps, and rest time', style: TextStyle(color: Color(0xFF94A3B8))),
            SizedBox(height: 6),
            Text('• Allows you to request extra time or unlock apps from parents', style: TextStyle(color: Color(0xFF94A3B8))),
            SizedBox(height: 6),
            Text('• Connects with parents for safety and emergency protection', style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealAccent,
              foregroundColor: const Color(0xFF042421),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  // ── Unified Settings & Sign Out Modal Sheet for Child ──────────────
  void _showSettingsSheet(BuildContext context, WidgetRef ref, dynamic user, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1E33),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF1E3554), width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334B6E),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Profile row
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _tealAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      (user?.displayName != null && user!.displayName.isNotEmpty)
                          ? user.displayName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        color: Color(0xFF042421),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName != null && user!.displayName.isNotEmpty
                            ? user.displayName
                            : 'Child Companion',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email != null && user!.email.isNotEmpty
                            ? user.email
                            : 'Protected Child Device',
                        style: const TextStyle(
                          color: Color(0xFF8BA0B8),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tealAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _tealAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    l10n.child.toUpperCase(),
                    style: const TextStyle(
                      color: _tealAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1E3554)),
            const SizedBox(height: 8),
            // Setting items
            _buildSettingsTile(
              icon: Icons.person_outline_rounded,
              title: l10n.myProfile,
              subtitle: l10n.settingsProfileSubtitle,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.profile);
              },
            ),
            _buildSettingsTile(
              icon: Icons.qr_code_scanner_rounded,
              title: l10n.familyGroup,
              subtitle: user?.hasFamily == true ? l10n.familyGroupConnected : l10n.familyGroupScanPrompt,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.familyJoin);
              },
            ),
            _buildSettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              title: l10n.devicePermissions,
              subtitle: l10n.settingsDevicePermissionsSubtitle,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.childPermissions);
              },
            ),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: l10n.aboutSmartGuard,
              subtitle: l10n.aboutSmartGuardSubtitle,
              onTap: () {
                Navigator.pop(context);
                _showMonitoringInfo(context);
              },
            ),
            _buildSettingsTile(
              icon: Icons.swap_horiz_rounded,
              title: l10n.switchRole,
              subtitle: l10n.settingsSwitchRoleSubtitle,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.roleSelection);
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final currentLang = ref.watch(currentLanguageProvider);
                return _buildSettingsTile(
                  icon: Icons.language_rounded,
                  title: l10n.language,
                  subtitle: '${currentLang.nativeName}  ${currentLang.flag}',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.languageSettings);
                  },
                );
              },
            ),
            // Theme / Color Mode Toggle
            Consumer(
              builder: (context, ref, _) {
                final currentMode = ref.watch(themeModeProvider);
                final isDark = currentMode == ThemeMode.dark;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14243B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _tealAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: _tealAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dark Navy Palette',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isDark ? 'Unified Dark Navy across all pages' : 'Light theme enabled',
                              style: const TextStyle(
                                color: Color(0xFF8BA0B8),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isDark,
                        activeColor: _tealAccent,
                        activeTrackColor: const Color(0xFF0D5E57),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: const Color(0xFF1E3554),
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).toggleTheme();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go(AppRoutes.login);
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF14243B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(icon, color: _tealAccent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8BA0B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_ios_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: const Color(0xFF475569),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}