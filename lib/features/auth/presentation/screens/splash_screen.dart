import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_icons.dart';

/// Professional splash screen with animated FamilyGuard branding
/// Features custom app logo, smooth transitions, and automatic navigation
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _fadeController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Setup animations
    _logoScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    ));

    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start splash sequence
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    // Haptic feedback for premium feel
    await HapticFeedback.lightImpact();
    
    // Animate logo entrance
    await _logoController.forward();
    
    // Brief pause, then animate text
    await Future.delayed(const Duration(milliseconds: 300));
    await _textController.forward();
    
    // Hold the splash screen for branding effect
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Fade out and navigate
    await _fadeController.forward();
    
    if (mounted) {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoController,
          _textController,
          _fadeController,
        ]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeOutAnimation.value,
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.9),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    
                    // Animated App Logo
                    Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Opacity(
                        opacity: _logoOpacityAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Icon(
                            AppIcons.shield, // Professional family safety icon
                            size: 70,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Animated App Name and Tagline
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: Opacity(
                        opacity: _textOpacityAnimation.value,
                        child: Column(
                          children: [
                            // App Name
                            Text(
                              AppConstants.appName,
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // App Tagline
                            Text(
                              AppConstants.appTagline,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 3),
                    
                    // Loading indicator
                    Opacity(
                      opacity: _textOpacityAnimation.value,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 40),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
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
}