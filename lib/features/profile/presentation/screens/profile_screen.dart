import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/family_bottom_navigation.dart';
import '../../../../l10n/app_localizations.dart';

/// Professional, pixel-matched Profile and Account Management Screen
/// Matches the FamilyGuard dark navy & teal branding.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AppColors get _colors => AppColors.of(context);
  Color get _bgDark => _colors.background;
  Color get _cardBg => _colors.surface;
  static const Color _cardBorder = AppColors.darkNavyBorder;
  static const Color _tealAccent = AppColors.tealAccent;

  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _notificationsEnabled =
              prefs.getBool('notifications_enabled') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserDataProvider);
    final user = userAsync.value;
    final isParent = user?.isParent ?? true;

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: userAsync.when(
          loading: () => Center(
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
                    'Failed to load profile',
                    style: TextStyle(
                      color: _colors.textPrimary,
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
          data: (userData) {
            final currentUser =
                userData ?? ref.watch(authNotifierProvider).user;
            return Stack(
              children: [
                // Scrollable Profile Content
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Top App Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  context.go(
                                    isParent
                                        ? AppRoutes.parentHome
                                        : AppRoutes.childHome,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _colors.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _cardBorder),
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: _colors.textPrimary,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                l10n.profileSettings,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _colors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 1. Profile Header Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: _buildProfileHeaderCard(l10n, currentUser),
                      ),
                    ),

                    // 2. Personal Information Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: _buildPersonalInfoSection(l10n, currentUser),
                      ),
                    ),

                    // 3. Family / Role Section (For Parent: Children overview & pairing)
                    if (isParent)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: _buildFamilyManagementSection(
                            l10n,
                            currentUser,
                          ),
                        ),
                      ),

                    // 4. Security Section (Change Password, Reset Password)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: _buildSecuritySection(l10n, currentUser),
                      ),
                    ),

                    // 5. Account Settings (Notifications, Theme, Language, Legal)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: _buildAccountSettingsSection(l10n),
                      ),
                    ),

                    // 6. Account Actions (Sign Out, Delete Account)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: _buildAccountActionsSection(l10n),
                      ),
                    ),

                    // Bottom spacing for the floating navigation bar
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                ),

                // Floating Bottom Navigation Bar (Profile selected)
                Positioned(
                  bottom: 16,
                  left: 14,
                  right: 14,
                  child: FamilyBottomNavigation(
                    isParent: isParent,
                    selected: FamilyNavDestination.profile,
                    familyId: currentUser?.familyId,
                    childId: currentUser?.uid,
                    childName: currentUser?.displayName,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Profile Header Card ───────────────────────────────────────────
  Widget _buildProfileHeaderCard(AppLocalizations l10n, UserModel? user) {
    final displayName = user?.displayName.trim() ?? '';
    final email = user?.email.trim() ?? '';
    final resolvedDisplayName = displayName.isNotEmpty
        ? displayName
        : 'Family Member';
    final resolvedEmail = email.isNotEmpty ? email : 'No email provided';
    final initial = resolvedDisplayName[0].toUpperCase();
    final isParent = user?.isParent ?? true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with Edit Badge
          Stack(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: _tealAccent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _tealAccent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Color(0xFF042421),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: () => _showEditProfileSheet(l10n, user),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _colors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: _tealAccent, width: 1.5),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: _tealAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // User Details & Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resolvedDisplayName,
                        style: TextStyle(
                          color: _colors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isParent
                            ? _tealAccent.withOpacity(0.15)
                            : const Color(0xFF8B5CF6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isParent
                              ? _tealAccent.withOpacity(0.4)
                              : const Color(0xFF8B5CF6),
                        ),
                      ),
                      child: Text(
                        isParent
                            ? l10n.parent.toUpperCase()
                            : l10n.child.toUpperCase(),
                        style: TextStyle(
                          color: isParent
                              ? _tealAccent
                              : const Color(0xFFA78BFA),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  resolvedEmail,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Edit Profile Button
                InkWell(
                  onTap: () => _showEditProfileSheet(l10n, user),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _colors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: _tealAccent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.editProfile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _tealAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Personal Information Section ──────────────────────────────────
  Widget _buildPersonalInfoSection(AppLocalizations l10n, UserModel? user) {
    final displayName = user?.displayName.trim() ?? '';
    final email = user?.email.trim() ?? '';
    final phoneNumber = user?.phoneNumber?.trim() ?? '';
    final phone = phoneNumber.isNotEmpty ? phoneNumber : l10n.noResults;

    return _buildSectionCard(
      title: l10n.personalInfo,
      icon: Icons.person_outline_rounded,
      children: [
        _buildInfoRow(
          label: l10n.fullName,
          value: displayName.isNotEmpty ? displayName : l10n.noResults,
          icon: Icons.badge_outlined,
          onTap: () => _showEditProfileSheet(l10n, user),
        ),
        const Divider(color: Color(0xFF1E3554), height: 20),
        _buildInfoRow(
          label: l10n.emailAddress,
          value: email.isNotEmpty ? email : l10n.noResults,
          icon: Icons.mail_outline_rounded,
          isVerified: true,
        ),
        const Divider(color: Color(0xFF1E3554), height: 20),
        _buildInfoRow(
          label: l10n.phoneNumber,
          value: phone,
          icon: Icons.phone_outlined,
          onTap: () => _showEditProfileSheet(l10n, user),
        ),
      ],
    );
  }

  // ── Family Management Section (Parent Only) ───────────────────────
  Widget _buildFamilyManagementSection(AppLocalizations l10n, UserModel? user) {
    final childrenList = ref.watch(familyChildrenProvider).value ?? [];

    return _buildSectionCard(
      title: l10n.family,
      icon: Icons.family_restroom_rounded,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.children,
                  style: TextStyle(
                    color: _colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${childrenList.length} ${l10n.children} ${l10n.protected}',
                  style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.familySetup),
              icon: Icon(Icons.qr_code_rounded, size: 16),
              label: Text(l10n.pairChildDevice),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tealAccent,
                foregroundColor: const Color(0xFF042421),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Security Section ──────────────────────────────────────────────
  Widget _buildSecuritySection(AppLocalizations l10n, UserModel? user) {
    return _buildSectionCard(
      title: l10n.security,
      icon: Icons.security_rounded,
      children: [
        _buildActionTile(
          icon: Icons.lock_outline_rounded,
          title: l10n.changePassword,
          subtitle: l10n.changePasswordDescription,
          onTap: () => _showChangePasswordDialog(l10n, user?.email ?? ''),
        ),
        const Divider(color: Color(0xFF1E3554), height: 16),
        _buildActionTile(
          icon: Icons.lock_reset_rounded,
          title: l10n.resetPassword,
          subtitle: 'Send password recovery link to your inbox',
          onTap: () => _handleResetPassword(l10n, user?.email ?? ''),
        ),
      ],
    );
  }

  // ── Account Settings Section ──────────────────────────────────────
  Widget _buildAccountSettingsSection(AppLocalizations l10n) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLanguage = ref.watch(currentLanguageProvider);

    return _buildSectionCard(
      title: l10n.accountSettings,
      icon: Icons.tune_rounded,
      children: [
        // Push Notifications Toggle
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: _tealAccent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pushNotifications,
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Receive safety and request alerts',
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _notificationsEnabled,
              activeColor: _tealAccent,
              activeTrackColor: const Color(0xFF0D5E57),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: const Color(0xFF1E3554),
              onChanged: _toggleNotifications,
            ),
          ],
        ),
        const Divider(color: Color(0xFF1E3554), height: 20),

        // Theme Mode Toggle
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: _tealAccent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appearance,
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isDark ? l10n.darkMode : l10n.lightMode,
                    style: TextStyle(
                      color: _colors.textSecondary,
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
        const Divider(color: Color(0xFF1E3554), height: 20),

        // Language
        _buildActionTile(
          icon: Icons.language_rounded,
          title: l10n.language,
          subtitle: '${currentLanguage.nativeName}  ${currentLanguage.flag}',
          onTap: () => context.push(AppRoutes.languageSettings),
        ),
        const Divider(color: Color(0xFF1E3554), height: 16),

        // Privacy Policy
        _buildActionTile(
          icon: Icons.privacy_tip_outlined,
          title: l10n.privacyPolicy,
          subtitle: l10n.privacyPolicySubtitle,
          onTap: () => _showPrivacyPolicyModal(l10n),
        ),
        const Divider(color: Color(0xFF1E3554), height: 16),

        // Terms and Conditions
        _buildActionTile(
          icon: Icons.description_outlined,
          title: l10n.termsOfService,
          subtitle: l10n.termsOfServiceSubtitle,
          onTap: () => _showTermsModal(l10n),
        ),
        const Divider(color: Color(0xFF1E3554), height: 20),

        // App Version
        const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
            SizedBox(width: 8),
            Text(
              'FamilyGuard v1.2.0 (Build 42) · Up to date',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Account Actions Section (Sign Out, Delete) ────────────────────
  Widget _buildAccountActionsSection(AppLocalizations l10n) {
    return _buildSectionCard(
      title: l10n.accountActions,
      icon: Icons.manage_accounts_outlined,
      children: [
        // Sign Out Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showSignOutConfirmDialog(l10n),
            icon: Icon(Icons.logout_rounded, size: 18),
            label: Text(l10n.signOut),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3554),
              foregroundColor: _colors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Delete Account Button (Secure)
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _showDeleteAccountDialog(l10n),
            icon: Icon(
              Icons.delete_forever_rounded,
              size: 18,
              color: Color(0xFFEF4444),
            ),
            label: Text(
              l10n.deleteAccount,
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Reusable Section Card ─────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _tealAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    bool isVerified = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(icon, color: _tealAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _tealAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: _tealAccent,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: _tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF64748B),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(icon, color: _tealAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_ios_rounded
                  : Icons.arrow_forward_ios_rounded,
              size: 14,
              color: const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modals & Dialogs ──────────────────────────────────────────────

  /// Edit Personal Information (Name, Phone)
  void _showEditProfileSheet(AppLocalizations l10n, UserModel? user) {
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final phoneController = TextEditingController(
      text: user?.phoneNumber ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Color(0xFF1E3554), width: 1.5),
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(
                      l10n.editProfile,
                      style: TextStyle(
                        color: _colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your role and family link cannot be changed here.',
                      style: TextStyle(
                        color: _colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Name Field
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: _colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: l10n.fullName,
                        labelStyle: TextStyle(color: _colors.textSecondary),
                        filled: true,
                        fillColor: _colors.surfaceHighlight,
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: _tealAccent,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _tealAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l10n.fieldRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Phone Field
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: _colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: l10n.phoneNumber,
                        labelStyle: TextStyle(color: _colors.textSecondary),
                        filled: true,
                        fillColor: _colors.surfaceHighlight,
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: _tealAccent,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _tealAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _colors.textSecondary,
                              side: const BorderSide(color: _cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (formKey.currentState?.validate() !=
                                        true) {
                                      return;
                                    }
                                    setSheetState(() => isSaving = true);

                                    final success = await ref
                                        .read(authNotifierProvider.notifier)
                                        .updateProfile(
                                          displayName: nameController.text
                                              .trim(),
                                          phoneNumber: phoneController.text
                                              .trim(),
                                        );

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? l10n.profileUpdated
                                                  : (ref
                                                            .read(
                                                              authNotifierProvider,
                                                            )
                                                            .errorMessage ??
                                                        'Failed to update profile'),
                                            ),
                                            backgroundColor: success
                                                ? const Color(0xFF0E3835)
                                                : const Color(0xFFDC2626),
                                          ),
                                        );
                                        if (success) {
                                          ref.invalidate(
                                            currentUserDataProvider,
                                          );
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tealAccent,
                              foregroundColor: const Color(0xFF042421),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSaving
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF042421),
                                    ),
                                  )
                                : Text(
                                    l10n.save,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Change Password Dialog
  void _showChangePasswordDialog(AppLocalizations l10n, String email) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(dialogCtx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Color(0xFF1E3554), width: 1.5),
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Text(
                      l10n.changePassword,
                      style: TextStyle(
                        color: _colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.changePasswordDescription,
                      style: TextStyle(
                        color: _colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Current Password
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      style: TextStyle(color: _colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: l10n.currentPassword,
                        labelStyle: TextStyle(color: _colors.textSecondary),
                        filled: true,
                        fillColor: _colors.surfaceHighlight,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: _tealAccent,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _tealAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return l10n.currentPasswordRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // New Password
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: TextStyle(color: _colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: l10n.newPassword,
                        labelStyle: TextStyle(color: _colors.textSecondary),
                        filled: true,
                        fillColor: _colors.surfaceHighlight,
                        prefixIcon: Icon(Icons.lock_reset, color: _tealAccent),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _tealAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 6) {
                          return l10n.passwordMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Confirm Password
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: TextStyle(color: _colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: l10n.confirmNewPassword,
                        labelStyle: TextStyle(color: _colors.textSecondary),
                        filled: true,
                        fillColor: _colors.surfaceHighlight,
                        prefixIcon: Icon(
                          Icons.check_circle_outline,
                          color: _tealAccent,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _tealAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val != newPasswordController.text) {
                          return l10n.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _colors.textSecondary,
                              side: const BorderSide(color: _cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (formKey.currentState?.validate() !=
                                        true) {
                                      return;
                                    }
                                    setDialogState(() => isSaving = true);

                                    final success = await ref
                                        .read(authNotifierProvider.notifier)
                                        .changePassword(
                                          currentPassword:
                                              currentPasswordController.text,
                                          newPassword:
                                              newPasswordController.text,
                                        );

                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? l10n.passwordChanged
                                                  : (ref
                                                            .read(
                                                              authNotifierProvider,
                                                            )
                                                            .errorMessage ??
                                                        'Failed to change password'),
                                            ),
                                            backgroundColor: success
                                                ? const Color(0xFF0E3835)
                                                : const Color(0xFFDC2626),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tealAccent,
                              foregroundColor: const Color(0xFF042421),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF042421),
                                    ),
                                  )
                                : Text(
                                    l10n.saveNewPassword,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Reset Password via Email
  Future<void> _handleResetPassword(AppLocalizations l10n, String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email address associated with this account.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.resetPassword,
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Send a password reset email to $email?',
          style: TextStyle(color: _colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: _colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealAccent,
              foregroundColor: const Color(0xFF042421),
            ),
            child: Text(l10n.send),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${l10n.passwordResetSent} to $email. Please check your inbox.'
                  : (ref.read(authNotifierProvider).errorMessage ??
                        'Failed to send reset email'),
            ),
            backgroundColor: success
                ? const Color(0xFF0E3835)
                : const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  /// Privacy Policy Modal
  void _showPrivacyPolicyModal(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF1E3554), width: 1.5),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
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
              Text(
                l10n.privacyPolicy,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Last updated: October 2026\n\n'
                '1. Commitment to Family Safety\n'
                'FamilyGuard prioritizes child privacy and safety. We only collect location and app usage data when explicitly authorized by parents and required for safety services.\n\n'
                '2. Data Encryption\n'
                'All sensitive telemetry, passwords, and pairing tokens are encrypted in transit using industry-standard protocols. Passwords are never stored directly in Firestore.\n\n'
                '3. Parental Controls\n'
                'Parents maintain full authority to remove linked child devices, revoke monitoring permissions, or request data deletion at any time.\n\n'
                '4. Contact Us\n'
                'For privacy concerns or inquiries, reach out to our team at support@familyguard.app.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Terms of Service Modal
  void _showTermsModal(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF1E3554), width: 1.5),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
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
              Text(
                l10n.termsOfService,
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Acceptance of Terms\n'
                'By using FamilyGuard, you agree to comply with all child safety regulations and local laws regarding parental monitoring.\n\n'
                '2. Account Security\n'
                'You are responsible for maintaining the confidentiality of your parent credentials and pairing codes.\n\n'
                '3. Permitted Usage\n'
                'FamilyGuard is intended solely for parents and legal guardians to protect their minor dependents.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sign Out Confirmation Dialog
  void _showSignOutConfirmDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.signOutConfirmTitle,
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.signOutConfirmMessage,
          style: TextStyle(color: _colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: _colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (mounted) {
                context.go(AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: _colors.textPrimary,
            ),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
  }

  /// Delete Account Securely with Password Confirmation
  void _showDeleteAccountDialog(AppLocalizations l10n) {
    final passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: _colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.deleteAccountConfirmTitle,
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deleteAccountConfirmMessage,
                style: TextStyle(color: _colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(color: _colors.textPrimary),
                decoration: InputDecoration(
                  labelText: l10n.password,
                  labelStyle: TextStyle(color: _colors.textSecondary),
                  filled: true,
                  fillColor: _colors.surfaceHighlight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: _colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) return;
                      setDialogState(() => isDeleting = true);

                      final success = await ref
                          .read(authNotifierProvider.notifier)
                          .deleteAccountWithPassword(passwordController.text);

                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        if (success && mounted) {
                          context.go(AppRoutes.login);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ref.read(authNotifierProvider).errorMessage ??
                                    'Failed to delete account. Check password.',
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: _colors.textPrimary,
              ),
              child: isDeleting
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: _colors.textPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(l10n.delete),
            ),
          ],
        ),
      ),
    );
  }
}
