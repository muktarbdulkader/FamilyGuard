import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_study_app/features/chat/presentation/widgets/chat_home_card.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/family_bottom_navigation.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// Pixel-matched Parent Home Screen
/// Matches the exact sleek dark teal & slate styling:
/// - Squircle teal shield icon
/// - Forest teal "Your family is safe right now" hero card
/// - Children cards with bright avatar, status line, and [Rules | Location | Lessons] buttons
/// - Bottom navigation bar with [Home | Control | Location | Requests | Alerts]
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  static const Color _tealAccent = AppColors.tealAccent;
  static const Color _cardBorder = AppColors.darkNavyBorder;

  AppColors _colors(BuildContext context) => AppColors.of(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userData = ref.watch(currentUserDataProvider);
    final familyId =
        userData.value?.familyId ??
        ref.watch(selectedFamilyProvider)?.id ??
        ref.watch(userFamiliesProvider).value?.firstOrNull?.id;

    if (familyId != null && familyId.isNotEmpty) {
      NotificationService.instance.startParentNotificationListener(familyId);
    }

    return Scaffold(
      backgroundColor: _colors(context).background,
      body: SafeArea(
        child: userData.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: _tealAccent,
              strokeWidth: 3,
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.errorLoadingDashboard,
                    style: TextStyle(
                      color: _colors(context).textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
              // Scrollable Content
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
                                // Teal Squircle with Shield
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.appName,
                                        style: TextStyle(
                                          color: _colors(context).textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user?.displayName != null &&
                                                user!.displayName.isNotEmpty
                                            ? '${l10n.welcomeMessage} ${user.displayName}'
                                            : '${l10n.welcomeMessage} ${l10n.parent}',
                                        style: TextStyle(
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Notification Bell
                              InkWell(
                                onTap: () => context.push('/notifications'),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _colors(context).surfaceHighlight,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _cardBorder),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_outlined,
                                        color: _colors(context).textPrimary,
                                        size: 22,
                                      ),
                                      if (ref.watch(
                                            unreadNotificationCountProvider,
                                          ) >
                                          0)
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEF4444),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Settings & Sign Out Button
                              InkWell(
                                onTap: () =>
                                    _showSettingsSheet(context, ref, user),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _colors(context).surfaceHighlight,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _cardBorder),
                                  ),
                                  child: Icon(
                                    Icons.settings_outlined,
                                    color: _colors(context).textPrimary,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Hero Card: "Your family is safe right now"
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: _colors(context).heroBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _colors(context).heroBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.allProtectionsOn,
                              style: TextStyle(
                                color: _tealAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.familySafeNow,
                              style: TextStyle(
                                color: _colors(context).textPrimary,
                                fontSize: 23,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Metrics row
                            Row(
                              children: [
                                _buildMetricBox(
                                  context,
                                  l10n.limits,
                                  l10n.enforced,
                                ),
                                const SizedBox(width: 10),
                                _buildMetricBox(context, l10n.gps, l10n.live),
                                const SizedBox(width: 10),
                                _buildMetricBox(
                                  context,
                                  l10n.approvals,
                                  l10n.instant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: const ChatHomeCard(),
                    ),
                  ),

                  // 3. Children Header with "+ Add child"
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.children,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _colors(context).textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Flexible(
                            child: InkWell(
                              onTap: () => context.push(AppRoutes.familySetup),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: _tealAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        l10n.addChild,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          color: _tealAccent,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Children Cards List
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildChildrenList(context, familyId),
                    ),
                  ),

                  // Bottom padding to leave room for the floating bottom navigation bar
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // Floating Bottom Navigation Bar
              Positioned(
                bottom: 16,
                left: 14,
                right: 14,
                child: const FamilyBottomNavigation(
                  isParent: true,
                  selected: FamilyNavDestination.home,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Metric Box in Hero Card ─────────────────────────────────────────
  Widget _buildMetricBox(BuildContext context, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: _colors(context).metricBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF093530)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF86A5A1),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _colors(context).textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Children Cards ─────────────────────────────────────────────────
  Widget _buildChildrenList(BuildContext context, String? familyId) {
    final l10n = AppLocalizations.of(context);
    if (familyId == null || familyId.isEmpty) {
      return _buildEmptyChildPlaceholder(context);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('familyId', isEqualTo: familyId)
          .where('role', isEqualTo: AppConstants.childRole)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(
                color: _tealAccent,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final children = snapshot.data?.docs ?? [];
        if (children.isEmpty) {
          return _buildEmptyChildPlaceholder(context);
        }

        return Column(
          children: children.map((doc) {
            final childData = doc.data() as Map<String, dynamic>;
            final child = ChildModel.fromFirestore(doc);
            final childName =
                childData['displayName'] ?? childData['name'] ?? l10n.child;
            final childEmail = childData['email'] ?? '';
            final childId = doc.id;
            final initial = childName.isNotEmpty
                ? childName[0].toUpperCase()
                : 'C';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _colors(context).surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                children: [
                  // Child Header Info
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
                                style: TextStyle(
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
                                border: Border.all(
                                  color: _colors(context).surface,
                                  width: 2.2,
                                ),
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
                              style: TextStyle(
                                color: _colors(context).textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              childEmail.isNotEmpty
                                  ? childEmail
                                  : l10n.protectedDevice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _colors(context).textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            StreamBuilder<int>(
                              stream: Stream<int>.periodic(
                                const Duration(minutes: 1),
                                (tick) => tick,
                              ),
                              builder: (context, _) {
                                final online = child.isOnline;
                                final lastSeenText = child.lastSeen == null
                                    ? 'Never connected'
                                    : 'Last seen ${_formatPresenceAge(child.lastSeen!)}';
                                return Row(
                                  children: [
                                    Icon(
                                      online
                                          ? Icons.shield_outlined
                                          : Icons.wifi_off_rounded,
                                      size: 13,
                                      color: online
                                          ? _tealAccent
                                          : const Color(0xFFF87171),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        online
                                            ? '${l10n.protected} · ${l10n.online}'
                                            : '${l10n.offline} · $lastSeenText',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: online
                                              ? _tealAccent
                                              : const Color(0xFFF87171),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
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
                      // Rules button
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.tune_rounded,
                          label: l10n.rules,
                          isSolid: false,
                          onTap: () =>
                              context.push('/parent-apps/$childId/$childName'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Location button
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.location_on_outlined,
                          label: l10n.location,
                          isSolid: false,
                          onTap: () => context.push(AppRoutes.parentLocation),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Lessons button (Solid teal)
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          icon: Icons.school_outlined,
                          label: l10n.lessons,
                          isSolid: true,
                          onTap: () => context.push(AppRoutes.parentEducation),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatPresenceAge(DateTime lastSeen) {
    final age = DateTime.now().difference(lastSeen);
    if (age.isNegative || age.inSeconds < 45) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) return '${age.inHours} hr ago';
    return '${age.inDays} days ago';
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSolid,
    required VoidCallback onTap,
  }) {
    final foregroundColor = isSolid
        ? const Color(0xFF042421)
        : _colors(context).textPrimary;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: foregroundColor),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (isSolid) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _tealAccent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: content,
      );
    } else {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF0E1A2C),
          side: const BorderSide(color: Color(0xFF223A5B)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: content,
      );
    }
  }

  Widget _buildEmptyChildPlaceholder(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _colors(context).surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _tealAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.group_add_rounded, size: 36, color: _tealAccent),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.noChildrenConnectedYet,
            style: TextStyle(
              color: _colors(context).textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noChildrenDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _colors(context).textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.familySetup),
            icon: Icon(Icons.qr_code_rounded, size: 18),
            label: Text(l10n.pairChildDevice),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealAccent,
              foregroundColor: const Color(0xFF042421),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Unified Settings & Sign Out Modal Sheet ────────────────────────
  void _showSettingsSheet(BuildContext context, WidgetRef ref, dynamic user) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        decoration: BoxDecoration(
          color: _colors(context).surface,
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
                      (user?.displayName != null &&
                              user!.displayName.isNotEmpty)
                          ? user.displayName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
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
                        user?.displayName != null &&
                                user!.displayName.isNotEmpty
                            ? user.displayName
                            : l10n.parentAccount,
                        style: TextStyle(
                          color: _colors(context).textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email != null && user!.email.isNotEmpty
                            ? user.email
                            : l10n.protectedParentPortal,
                        style: TextStyle(
                          color: _colors(context).textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _tealAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _tealAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    l10n.parent.toUpperCase(),
                    style: TextStyle(
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
              context: context,
              icon: Icons.person_outline_rounded,
              title: l10n.myProfile,
              subtitle: l10n.settingsProfileSubtitle,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.profile);
              },
            ),
            _buildSettingsTile(
              context: context,
              icon: Icons.qr_code_scanner_rounded,
              title: l10n.pairChildDevice,
              subtitle: l10n.settingsPairSubtitle,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.familySetup);
              },
            ),
            _buildSettingsTile(
              context: context,
              icon: Icons.swap_horiz_rounded,
              title: l10n.switchRole,
              subtitle: l10n.settingsSwitchRoleSubtitle,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.roleSelection);
              },
            ),
            _buildSettingsTile(
              context: context,
              icon: Icons.admin_panel_settings_outlined,
              title: l10n.devicePermissions,
              subtitle: l10n.settingsDevicePermissionsSubtitle,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.childPermissions);
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final currentLang = ref.watch(currentLanguageProvider);
                return _buildSettingsTile(
                  context: context,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _colors(context).surfaceHighlight,
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
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: _tealAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.darkNavyPalette,
                              style: TextStyle(
                                color: _colors(context).textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isDark
                                  ? l10n.darkNavyDescription
                                  : l10n.lightThemeEnabled,
                              style: TextStyle(
                                color: _colors(context).textSecondary,
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
                icon: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: _colors(context).textPrimary,
                ),
                label: Text(
                  l10n.signOut,
                  style: TextStyle(
                    color: _colors(context).textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: _colors(context).textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
    required BuildContext context,
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
                color: _colors(context).surfaceHighlight,
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
                    style: TextStyle(
                      color: _colors(context).textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _colors(context).textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) => Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_back_ios_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF475569),
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
