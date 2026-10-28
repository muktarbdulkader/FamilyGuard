import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_routes.dart';

/// Modern, animated welcome screen for FamilyGuard
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _buttonController;

  // Staggered entry animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _featuresSlide;
  late Animation<double> _featuresOpacity;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _buttonsOpacity;

  // Pulse for glow effect
  late Animation<double> _pulseAnim;

  // Button press scale
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Logo: 0–50%
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Title: 30–65%
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic),
    ));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.65, curve: Curves.easeIn),
      ),
    );

    // Feature tiles: 55–85%
    _featuresSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _featuresOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeIn),
      ),
    );

    // Buttons: 75–100%
    _buttonsSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _buttonsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _pulseAnim = _pulseController;

    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    HapticFeedback.lightImpact();
    await _buttonController.forward();
    await _buttonController.reverse();
    if (mounted) {
      context.push(AppRoutes.register);
    }
  }

  void _onSignIn() {
    HapticFeedback.selectionClick();
    context.push(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _mainController]),
      builder: (context, _) {
        final pulse = _pulseAnim.value;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D1A),
                  Color(0xFF111827),
                  Color(0xFF0F172A),
                ],
              ),
            ),
            child: Stack(
              children: [
                // ── Animated background glow orbs ──────────────────────────
                Positioned(
                  top: -80,
                  right: -60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4F46E5)
                          .withOpacity(0.12 + pulse * 0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 160,
                  left: -90,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE11D48)
                          .withOpacity(0.10 + pulse * 0.05),
                    ),
                  ),
                ),
                Positioned(
                  top: 260,
                  right: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF14B8A6)
                          .withOpacity(0.08 + pulse * 0.04),
                    ),
                  ),
                ),

                // ── Main scrollable content ─────────────────────────────────
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                            maxWidth: 520,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── TOP: Logo + title + features ──────────────
                              Column(
                                children: [
                                  const SizedBox(height: 16),

                                  // Logo with breathing aura
                                  ScaleTransition(
                                    scale: _logoScale,
                                    child: FadeTransition(
                                      opacity: _logoOpacity,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Outer breathing ring
                                          Container(
                                            width: 130 + pulse * 14,
                                            height: 130 + pulse * 14,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFF43F5E)
                                                    .withOpacity(
                                                        0.22 - pulse * 0.08),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          // Middle glow
                                          Container(
                                            width: 118,
                                            height: 118,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFF43F5E)
                                                      .withOpacity(0.38),
                                                  blurRadius: 32,
                                                  spreadRadius: 6,
                                                ),
                                                BoxShadow(
                                                  color: const Color(0xFF4F46E5)
                                                      .withOpacity(0.28),
                                                  blurRadius: 22,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Photo circle
                                          Container(
                                            width: 110,
                                            height: 110,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                width: 3.5,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: Image.asset(
                                                'assets/images/family_care.png',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const AppLogo(
                                                        size: 88,
                                                        showBackground: false),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // App name + tagline
                                  SlideTransition(
                                    position: _titleSlide,
                                    child: FadeTransition(
                                      opacity: _titleOpacity,
                                      child: Column(
                                        children: [
                                          // Protective badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.12),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.favorite_rounded,
                                                  color: Color(0xFFFB7185),
                                                  size: 13,
                                                ),
                                                SizedBox(width: 5),
                                                Text(
                                                  'FAMILY PROTECTION & CARE',
                                                  style: TextStyle(
                                                    color: Color(0xFFFFE4E6),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // App name
                                          const Text(
                                            AppConstants.appName,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 34,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.8,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          // Tagline badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4F46E5)
                                                  .withOpacity(0.18),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xFF4F46E5)
                                                    .withOpacity(0.4),
                                              ),
                                            ),
                                            child: const Text(
                                              'Safe • Connected • Together',
                                              style: TextStyle(
                                                color: Color(0xFFA5B4FC),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'A smarter, safer digital environment\nfor your children and family peace of mind.',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.65),
                                              fontSize: 13.5,
                                              height: 1.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Feature tiles
                                  SlideTransition(
                                    position: _featuresSlide,
                                    child: FadeTransition(
                                      opacity: _featuresOpacity,
                                      child: Column(
                                        children: [
                                          _buildFeatureTile(
                                            icon: Icons.shield_rounded,
                                            iconColor: const Color(0xFF10B981),
                                            title: 'Live Device Protection',
                                            subtitle:
                                                'Instant app blocking and safe web limits',
                                          ),
                                          const SizedBox(height: 10),
                                          _buildFeatureTile(
                                            icon: Icons.location_on_rounded,
                                            iconColor: const Color(0xFF3B82F6),
                                            title: 'Real-Time Location',
                                            subtitle:
                                                'Know where your family is with safe zones',
                                          ),
                                          const SizedBox(height: 10),
                                          _buildFeatureTile(
                                            icon: Icons.timer_rounded,
                                            iconColor: const Color(0xFF8B5CF6),
                                            title: 'Smart Screen Time',
                                            subtitle:
                                                'Schedule healthy daily device habits',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // ── BOTTOM: Buttons ───────────────────────────
                              SlideTransition(
                                position: _buttonsSlide,
                                child: FadeTransition(
                                  opacity: _buttonsOpacity,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 28, bottom: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Get Started — animated press scale
                                        ScaleTransition(
                                          scale: _buttonScale,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF4F46E5),
                                                  Color(0xFF7C3AED),
                                                  Color(0xFFE11D48),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFE11D48)
                                                      .withOpacity(
                                                          0.30 + pulse * 0.15),
                                                  blurRadius:
                                                      18 + pulse * 8,
                                                  offset: const Offset(0, 6),
                                                ),
                                                BoxShadow(
                                                  color: const Color(0xFF4F46E5)
                                                      .withOpacity(0.25),
                                                  blurRadius: 14,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: _onGetStarted,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 17),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Get Started',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 22),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 14),

                                        // Sign In
                                        OutlinedButton(
                                          onPressed: _onSignIn,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 15),
                                            side: BorderSide(
                                              color: Colors.white
                                                  .withOpacity(0.18),
                                              width: 1.5,
                                            ),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: const Text(
                                            'I Already Have an Account',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 18),

                                        // Terms
                                        Text(
                                          'By continuing, you agree to our Terms & Privacy Policy',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Colors.white.withOpacity(0.38),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.2),
            size: 18,
          ),
        ],
      ),
    );
  }
}