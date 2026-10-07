import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Custom app icons and assets for FamilyGuard
class AppIcons {
  // App Logo and Branding
  static const IconData appLogo = Icons.family_restroom;
  static const IconData shield = Icons.shield;
  static const IconData security = Icons.security;
  
  // Role Icons
  static const IconData parent = Icons.supervisor_account;
  static const IconData child = Icons.child_care;
  static const IconData family = Icons.family_restroom;
  
  // Navigation Icons
  static const IconData home = Icons.home_rounded;
  static const IconData dashboard = Icons.dashboard_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData notifications = Icons.notifications_rounded;
  static const IconData profile = Icons.person_rounded;
  
  // Feature Icons
  static const IconData location = Icons.location_on_rounded;
  static const IconData apps = Icons.apps_rounded;
  static const IconData rules = Icons.rule_rounded;
  static const IconData analytics = Icons.analytics_rounded;
  static const IconData help = Icons.help_rounded;
  
  // Action Icons
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData save = Icons.save_rounded;
  static const IconData cancel = Icons.cancel_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData close = Icons.close_rounded;
  
  // Authentication Icons
  static const IconData login = Icons.login_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData register = Icons.person_add_rounded;
  static const IconData email = Icons.email_rounded;
  static const IconData password = Icons.lock_rounded;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;
  
  // Status Icons
  static const IconData success = Icons.check_circle_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData warning = Icons.warning_rounded;
  static const IconData info = Icons.info_rounded;
  
  // Connection Icons
  static const IconData connected = Icons.link_rounded;
  static const IconData disconnected = Icons.link_off_rounded;
  static const IconData sync = Icons.sync_rounded;
  static const IconData qrCode = Icons.qr_code_rounded;
  static const IconData qrScan = Icons.qr_code_scanner_rounded;
  
  // Time and Schedule Icons
  static const IconData time = Icons.access_time_rounded;
  static const IconData schedule = Icons.schedule_rounded;
  static const IconData bedtime = Icons.bedtime_rounded;
  static const IconData block = Icons.block_rounded;
  
  // Communication Icons
  static const IconData message = Icons.message_rounded;
  static const IconData request = Icons.request_page_rounded;
  static const IconData approval = Icons.approval_rounded;
  static const IconData chat = Icons.chat_rounded;
}

/// Custom app illustrations and graphics
class AppAssets {
  // Illustration paths (these would be actual asset files)
  static const String familyIllustration = 'assets/images/family_illustration.svg';
  static const String parentIllustration = 'assets/images/parent_illustration.svg';
  static const String childIllustration = 'assets/images/child_illustration.svg';
  static const String securityIllustration = 'assets/images/security_illustration.svg';
  static const String connectIllustration = 'assets/images/connect_illustration.svg';
  
  // App logo assets
  static const String appLogoSvg = 'assets/images/app_logo.svg';
  static const String appLogoPng = 'assets/images/app_logo.png';
  static const String appIconPng = 'assets/images/app_icon.png';
}

/// Custom widget for app logo
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showBackground;
  
  const AppLogo({
    super.key,
    this.size = 64,
    this.color,
    this.showBackground = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: showBackground ? [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                ),
              ),
              child: Icon(
                AppIcons.shield,
                size: size * 0.6,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Role-specific icon widget
class RoleIcon extends StatelessWidget {
  final UserRole role;
  final double size;
  final Color? color;
  
  const RoleIcon({
    super.key,
    required this.role,
    this.size = 32,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    IconData iconData;
    Color iconColor;
    
    switch (role) {
      case UserRole.parent:
        iconData = AppIcons.parent;
        iconColor = color ?? theme.colorScheme.primary;
        break;
      case UserRole.child:
        iconData = AppIcons.child;
        iconColor = color ?? theme.colorScheme.secondary;
        break;
      default:
        iconData = AppIcons.family;
        iconColor = color ?? theme.colorScheme.onSurface;
    }
    
    return Icon(
      iconData,
      size: size,
      color: iconColor,
    );
  }
}

/// Animated app logo for splash screen
class AnimatedAppLogo extends StatefulWidget {
  final double size;
  final Duration duration;
  final VoidCallback? onAnimationComplete;
  
  const AnimatedAppLogo({
    super.key,
    this.size = 120,
    this.duration = const Duration(milliseconds: 2000),
    this.onAnimationComplete,
  });
  
  @override
  State<AnimatedAppLogo> createState() => _AnimatedAppLogoState();
}

class _AnimatedAppLogoState extends State<AnimatedAppLogo>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: Duration(milliseconds: (widget.duration.inMilliseconds * 0.6).round()),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: (widget.duration.inMilliseconds * 0.4).round()),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _startAnimation();
  }
  
  void _startAnimation() async {
    await _fadeController.forward();
    await _scaleController.forward();
    
    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: AppLogo(
              size: widget.size,
              showBackground: true,
            ),
          ),
        );
      },
    );
  }
}