import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Default "About the App" page for FamilyGuard.
/// Uses [appColorsProvider] so light and dark themes adapt automatically.
class AboutAppScreen extends ConsumerWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'About ${AppConstants.appName}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          // ── Hero Brand Card ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Version 1.2.0 (Build 42)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Overview Section ────────────────────────────────────────────
          _AboutSectionCard(
            colors: colors,
            title: 'What is ${AppConstants.appName}?',
            icon: Icons.info_outline_rounded,
            child: Text(
              '${AppConstants.appDescription} Parents can guide healthy screen habits, '
              'approve app access in real time, share educational materials and quizzes, '
              'and stay aware of family safety without intrusive complexity.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Key Features ────────────────────────────────────────────────
          _AboutSectionCard(
            colors: colors,
            title: 'Core Features',
            icon: Icons.stars_rounded,
            child: Column(
              children: [
                _FeatureRow(
                  colors: colors,
                  icon: Icons.apps_rounded,
                  color: colors.primary,
                  title: 'Smart App Control',
                  subtitle:
                      'Block, allow, set daily time limits, or require parent approval for any app.',
                ),
                const SizedBox(height: 14),
                _FeatureRow(
                  colors: colors,
                  icon: Icons.timer_rounded,
                  color: colors.accent,
                  title: 'Screen Time & Routines',
                  subtitle:
                      'Schedule study, bedtime, and free-time routines with instant extra-time approvals.',
                ),
                const SizedBox(height: 14),
                _FeatureRow(
                  colors: colors,
                  icon: Icons.location_on_rounded,
                  color: colors.success,
                  title: 'Live Family Location',
                  subtitle:
                      'View real-time device check-ins and stay connected on the family map.',
                ),
                const SizedBox(height: 14),
                _FeatureRow(
                  colors: colors,
                  icon: Icons.school_rounded,
                  color: colors.warning,
                  title: 'Learning & Quiz Rewards',
                  subtitle:
                      'Share study materials and quizzes where children earn extra screen time.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Privacy & Safety ────────────────────────────────────────────
          _AboutSectionCard(
            colors: colors,
            title: 'Privacy & Child Safety',
            icon: Icons.verified_user_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your family data stays scoped strictly to your linked family group. '
                  'App usage, location, and request approvals are encrypted in transit '
                  'and accessible only to verified parents and guardians.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'support@familyguard.app',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 13,
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
    );
  }
}

class _AboutSectionCard extends StatelessWidget {
  final AppColors colors;
  final String title;
  final IconData icon;
  final Widget child;

  const _AboutSectionCard({
    required this.colors,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.colors,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
