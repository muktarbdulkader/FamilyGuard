import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';

/// Professional role selection screen for Parent and Child roles
/// Features elegant card-based role selection with detailed descriptions and FamilyGuard branding
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  /// Handle role selection
  Future<void> _handleRoleSelection(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
  ) async {
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.updateRole(role);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Role set as ${role == UserRole.parent ? 'Parent' : 'Child'}! Setting up dashboard...',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (role == UserRole.parent) {
        context.go(AppRoutes.parentHome);
      } else {
        context.go(AppRoutes.childHome);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final currentUser = authState.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC), const Color(0xFFEDE9FE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // Header badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 6),
                            Text(
                              'Setup Your Profile',
                              style: TextStyle(
                                color: const Color(0xFF4F46E5),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Welcome Text
                    Text(
                      'Welcome to ${AppConstants.appName}, ${currentUser?.displayName ?? 'Family Member'}!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select how this device will be used in your family setup',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Parent Role Card
                    _RoleOptionCard(
                      title: 'I\'m a Parent',
                      subtitle: 'Monitor activity, manage screen-time rules, review app requests, and safeguard devices.',
                      features: const ['Manage Family Rules', 'Screen-Time Limits', 'App Approval Requests', 'Location & Geofencing'],
                      icon: AppIcons.parent,
                      gradientColors: [AppTheme.parentPrimary, AppTheme.parentAccent],
                      isLoading: authState.isLoading,
                      onTap: () => _handleRoleSelection(context, ref, UserRole.parent),
                    ),

                    const SizedBox(height: 20),

                    // Child Role Card
                    _RoleOptionCard(
                      title: 'This is a Child\'s Device',
                      subtitle: 'Connect this device to your family group with smart guard protection and safe usage limits.',
                      features: const ['Protected App Monitoring', 'Request App Unblocks', 'Daily Usage Statistics', 'Safe Family Pairing'],
                      icon: AppIcons.child,
                      gradientColors: [AppTheme.childPrimary, AppTheme.childAccent],
                      isLoading: authState.isLoading,
                      onTap: () => _handleRoleSelection(context, ref, UserRole.child),
                    ),

                    const SizedBox(height: 24),

                    // Error message
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Sign out option
                    Center(
                      child: TextButton.icon(
                        onPressed: authState.isLoading ? null : () {
                          ref.read(authNotifierProvider.notifier).signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF64748B)),
                        label: const Text(
                          'Switch Account or Sign Out',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> features;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isLoading;
  final VoidCallback onTap;

  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.icon,
    required this.gradientColors,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradientColors.first.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors.first.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to configure this role',
                            style: TextStyle(
                              color: gradientColors.first,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: gradientColors.first,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: features.map((feat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: gradientColors.first.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: gradientColors.first),
                          const SizedBox(width: 4),
                          Text(
                            feat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}