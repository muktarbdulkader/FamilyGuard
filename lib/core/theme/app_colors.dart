import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

/// Centralized, single module containing all color definitions for FamilyGuard.
/// Instead of hardcoding hex colors across multiple files, every widget and
/// screen references this single source of truth.
class AppColors {
  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ── Static constants for const expressions ─────────────────────────
  static const Color darkNavyBg = Color(0xFF0C1829);
  static const Color darkNavyCard = Color(0xFF132238);
  static const Color darkNavySurfaceHighlight = Color(0xFF14243B);
  static const Color darkNavyBorder = Color(0xFF1E3554);
  static const Color tealAccent = Color(0xFF2DD4BF);
  static const Color heroForestTeal = Color(0xFF063D39);
  static const Color heroForestBorder = Color(0xFF0D5E57);
  static const Color metricDarkBg = Color(0xFF04201D);
  static const Color textMutedDark = Color(0xFF8BA0B8);

  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightPrimary = Color(0xFF4F46E5);

  final bool isDark;

  // Background & Surfaces
  final Color background;
  final Color surface;
  final Color surfaceHighlight;
  final Color border;

  // Accents
  final Color primary;
  final Color accent;
  final Color heroBg;
  final Color heroBorder;
  final Color metricBg;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Semantic Status
  final Color error;
  final Color success;
  final Color warning;
  final Color info;

  const AppColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceHighlight,
    required this.border,
    required this.primary,
    required this.accent,
    required this.heroBg,
    required this.heroBorder,
    required this.metricBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
  });

  /// Unified Dark Navy Palette (Default)
  static const dark = AppColors(
    isDark: true,
    background: darkNavyBg,
    surface: darkNavyCard,
    surfaceHighlight: darkNavySurfaceHighlight,
    border: darkNavyBorder,
    primary: tealAccent,
    accent: Color(0xFF38BDF8),
    heroBg: heroForestTeal,
    heroBorder: heroForestBorder,
    metricBg: metricDarkBg,
    textPrimary: Colors.white,
    textSecondary: textMutedDark,
    textMuted: Color(0xFF475569),
    error: Color(0xFFEF4444),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF38BDF8),
  );

  /// Unified Light Palette
  static const light = AppColors(
    isDark: false,
    background: lightBg,
    surface: lightCard,
    surfaceHighlight: Color(0xFFF1F5F9),
    border: lightBorder,
    primary: lightPrimary,
    accent: Color(0xFF7C3AED),
    heroBg: Color(0xFFEEF2FF),
    heroBorder: Color(0xFFC7D2FE),
    metricBg: Color(0xFFE0E7FF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    error: Color(0xFFEF4444),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF3B82F6),
  );
}

/// Global provider for application colors.
/// Any widget can watch this provider:
/// `final colors = ref.watch(appColorsProvider);`
/// When the theme toggles, all widgets listening to this provider update in sync!
final appColorsProvider = Provider<AppColors>((ref) {
  final mode = ref.watch(themeModeProvider);
  return mode == ThemeMode.light ? AppColors.light : AppColors.dark;
});
