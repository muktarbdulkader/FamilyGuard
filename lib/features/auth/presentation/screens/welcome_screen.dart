import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_routes.dart';

/// Modern, responsive welcome screen for FamilyGuard
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0B0F19), const Color(0xFF111827), const Color(0xFF0F172A)]
                : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC), const Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                    maxWidth: 520,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Content
                          Column(
                            children: [
                              const SizedBox(height: 12),

                              // App Logo Badge with Glow
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.35 : 0.2),
                                      blurRadius: 28,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const AppLogo(size: 88, showBackground: false),
                              ),

                              const SizedBox(height: 16),

                              // App Title
                              Text(
                                AppConstants.appName,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 6),

                              // Tagline badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Safe • Connected • Together',
                                  style: TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Description
                              Text(
                                'A smarter, safer digital environment for your children and family peace of mind.',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 24),

                              // Feature Highlights List
                              _buildFeatureTile(
                                context: context,
                                isDark: isDark,
                                icon: Icons.shield_rounded,
                                iconColor: const Color(0xFF10B981),
                                title: 'Live Device Protection',
                                subtitle: 'Instant app blocking and safe web limits',
                              ),
                              const SizedBox(height: 10),
                              _buildFeatureTile(
                                context: context,
                                isDark: isDark,
                                icon: Icons.location_on_rounded,
                                iconColor: const Color(0xFF3B82F6),
                                title: 'Real-Time Location',
                                subtitle: 'Know where your family is with safe zones',
                              ),
                              const SizedBox(height: 10),
                              _buildFeatureTile(
                                context: context,
                                isDark: isDark,
                                icon: Icons.timer_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                title: 'Smart Screen Time',
                                subtitle: 'Schedule healthy daily device habits',
                              ),
                            ],
                          ),

                          // Bottom Actions
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Get Started Button
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5).withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => context.push(AppRoutes.roleSelection),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Get Started',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded, size: 20),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Sign In Button
                                OutlinedButton(
                                  onPressed: () => context.push(AppRoutes.login),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'I Already Have an Account',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Terms and Privacy
                                Text(
                                  'By continuing, you agree to our Terms & Privacy Policy',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.7) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}