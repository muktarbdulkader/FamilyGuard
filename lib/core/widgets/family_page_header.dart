import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../theme/app_colors.dart';

/// Reusable, attractive back button with bulletproof fallback navigation.
/// Never leaves the user stranded when `canPop()` is false (e.g. opened
/// directly from bottom navigation bar or deep link).
class FamilyBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String fallbackRoute;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final double size;

  const FamilyBackButton({
    super.key,
    this.onPressed,
    this.fallbackRoute = AppRoutes.parentHome,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final iconColor = color ?? colors.textPrimary;
    final bgColor = backgroundColor ??
        (colors.isDark ? const Color(0xFF132238) : const Color(0xFFF1F5F9));
    final borderCol = borderColor ??
        (colors.isDark ? const Color(0xFF1E3554) : const Color(0xFFE2E8F0));

    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Material(
        color: bgColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderCol, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            if (onPressed != null) {
              onPressed!();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallbackRoute);
            }
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(
                isRtl
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable top page header for Parental Controls and Family Guard pages.
/// Features:
/// - Reliable, attractive squircle back button with automatic fallback
/// - Gradient icon badge with glowing shadow
/// - Title and subtitle with theme contrast
/// - Trailing actions and status chips
class FamilyPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Color>? iconGradient;
  final Color? iconColor;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final String fallbackRoute;
  final EdgeInsetsGeometry padding;
  final Widget? bottom;

  const FamilyPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconGradient,
    this.iconColor,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.fallbackRoute = AppRoutes.parentHome,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = colors.isDark;

    final defaultGradient = isDark
        ? const [Color(0xFF063D39), Color(0xFF0D5E57)]
        : const [Color(0xFF4F46E5), Color(0xFF7C3AED)];

    final defaultIconColor =
        isDark ? const Color(0xFF2DD4BF) : Colors.white;

    final gradientColors = iconGradient ?? defaultGradient;
    final badgeIconColor = iconColor ?? defaultIconColor;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1829) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E3554) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBackButton) ...[
                FamilyBackButton(
                  onPressed: onBackPressed,
                  fallbackRoute: fallbackRoute,
                ),
                const SizedBox(width: 12),
              ],
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withOpacity(isDark ? 0.3 : 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 20,
                      color: badgeIconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ],
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 12),
            bottom!,
          ],
        ],
      ),
    );
  }
}

