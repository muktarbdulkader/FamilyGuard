import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// Login and Registration screen featuring a curved hero illustration header,
/// pill-shaped form inputs, and full [AppColors] theme support while preserving
/// all existing authentication logic.
class LoginScreen extends ConsumerStatefulWidget {
  final bool initialTabIsSignUp;
  final UserRole? selectedRole;

  const LoginScreen({
    super.key,
    this.initialTabIsSignUp = false,
    this.selectedRole,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Sign In Controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  // Sign Up Controllers
  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();

  bool _isSignInPasswordVisible = false;
  bool _isSignUpPasswordVisible = false;
  bool _isSignUpConfirmPasswordVisible = false;
  bool _rememberMe = true;

  bool get _isRegister => _tabController.index == 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIsSignUp ? 1 : 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    _tabController.animateTo(index);
    ref.read(authNotifierProvider.notifier).clearError();
  }

  /// Handle Sign In
  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    final success = await authNotifier.signIn(
      email: email,
      password: password,
    );

    if (success && mounted) {
      final colors = ref.read(appColorsProvider);
      final user = ref.read(authNotifierProvider).user;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Welcome back, ${user?.displayName ?? 'Family Member'}!',
                ),
              ),
            ],
          ),
          backgroundColor: colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      if (user == null || user.role == UserRole.none) {
        context.go(AppRoutes.roleSelection);
      } else if (user.role == UserRole.parent) {
        context.go(AppRoutes.parentHome);
      } else if (user.role == UserRole.child) {
        context.go(AppRoutes.childHome);
      }
    }
  }

  /// Handle Sign Up / Register
  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final name = _signUpNameController.text.trim();
    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text;

    final success = await authNotifier.register(
      email: email,
      password: password,
      displayName: name,
    );

    if (success && mounted) {
      final colors = ref.read(appColorsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Family space created! Welcome, $name.')),
            ],
          ),
          backgroundColor: colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      context.go(AppRoutes.roleSelection);
    }
  }

  /// Handle Google Sign In / Registration
  Future<void> _handleGoogleSignIn() async {
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final user = await authNotifier.signInWithGoogle();

    if (user != null && mounted) {
      final colors = ref.read(appColorsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Welcome, ${user.displayName}!')),
            ],
          ),
          backgroundColor: colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      if (user.role == UserRole.none) {
        context.go(AppRoutes.roleSelection);
      } else if (user.role == UserRole.parent) {
        context.go(AppRoutes.parentHome);
      } else if (user.role == UserRole.child) {
        context.go(AppRoutes.childHome);
      }
    }
  }

  /// Handle Password Reset
  Future<void> _handlePasswordReset() async {
    final emailController = TextEditingController(
      text: _signInEmailController.text.trim(),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ref.watch(appColorsProvider);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'We\'ll send a recovery link to your email',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: _inputDecoration(
                    hint: 'parent@example.com',
                    icon: Icons.alternate_email_rounded,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 20),
                _buildGradientButton(
                  label: 'Send Reset Link',
                  icon: Icons.send_rounded,
                  isLoading: false,
                  colors: colors,
                  onPressed: () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Please enter a valid email address',
                          ),
                          backgroundColor: colors.error,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await ref
                        .read(authNotifierProvider.notifier)
                        .resetPassword(email);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Reset link sent to $email'),
                          backgroundColor: colors.success,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final colors = ref.watch(appColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Curved Wave Hero Header ────────────────────────────────
                _buildCurvedHeroHeader(colors),

                // ── Brand Header ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              color: colors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppConstants.appName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: colors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegister
                            ? 'Join us to keep your family safe'
                            : 'Keep Your Family Safe & Connected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Error alert banner
                      if (authState.errorMessage != null) ...[
                        _buildErrorBanner(authState.errorMessage!, colors),
                        const SizedBox(height: 16),
                      ],

                      // Animated Form Switch
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _isRegister
                            ? _buildSignUpForm(authState, colors)
                            : _buildSignInForm(authState, colors),
                      ),

                      const SizedBox(height: 18),
                      _buildTrustFooter(colors),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top curved wave hero with Family Care illustration and floating shield badge.
  Widget _buildCurvedHeroHeader(AppColors colors) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 215 + topPadding * 0.5,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Wave-clipped illustration + gradient overlay
          ClipPath(
            clipper: _HeroWaveClipper(),
            child: Container(
              height: 195 + topPadding * 0.5,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primary, colors.accent],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/family_care.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  // Subtle theme-colored gradient scrim so illustration blends cleanly
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.primary.withValues(alpha: 0.28),
                          colors.accent.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top bar (Back button on Register or when poppable)
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isRegister || context.canPop())
                  Material(
                    color: colors.surface.withValues(alpha: 0.88),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (_isRegister) {
                          _switchTab(0);
                        } else if (context.canPop()) {
                          context.pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 34),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isRegister ? 'Register' : 'Sign In',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Overlapping center Shield Emblem
          Positioned(
            bottom: 0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primary, colors.accent],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: colors.background, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.1),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sign In Form
  Widget _buildSignInForm(AuthState authState, AppColors colors) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
          TextFormField(
            controller: _signInEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Email Address',
              icon: Icons.email_outlined,
              colors: colors,
            ),
            validator: _validateEmail,
            onChanged: (_) =>
                ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 12),

          // Password
          TextFormField(
            controller: _signInPasswordController,
            obscureText: !_isSignInPasswordVisible,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              colors: colors,
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignInPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _isSignInPasswordVisible = !_isSignInPasswordVisible,
                ),
              ),
            ),
            validator: (val) => (val == null || val.isEmpty)
                ? 'Please enter your password'
                : null,
            onChanged: (_) =>
                ref.read(authNotifierProvider.notifier).clearError(),
            onFieldSubmitted: (_) => _handleSignIn(),
          ),
          const SizedBox(height: 10),

          // Remember Me + Forgot Password?
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: colors.primary,
                        side: BorderSide(color: colors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        onChanged: (val) =>
                            setState(() => _rememberMe = val ?? true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remember Me',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: authState.isLoading ? null : _handlePasswordReset,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Primary Login Pill Button
          _buildGradientButton(
            label: 'Login',
            icon: Icons.login_rounded,
            isLoading: authState.isLoading,
            colors: colors,
            onPressed: _handleSignIn,
          ),

          _buildDivider(colors, text: 'Or continue with'),

          // Google Sign In Button
          _buildGoogleSignInButton(
            colors,
            isLoading: authState.isLoading,
            label: 'Continue with Google',
          ),
          const SizedBox(height: 14),

          // Bottom "Create New Account >" Pill
          _buildSwitchModePill(
            colors: colors,
            icon: Icons.person_add_alt_1_rounded,
            label: 'Create New Account',
            onTap: () => _switchTab(1),
          ),
        ],
      ),
    );
  }

  /// Sign Up Form
  Widget _buildSignUpForm(AuthState authState, AppColors colors) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full Name
          TextFormField(
            controller: _signUpNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Full Name',
              icon: Icons.person_outline_rounded,
              colors: colors,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
            onChanged: (_) =>
                ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 12),

          // Email
          TextFormField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Email Address',
              icon: Icons.email_outlined,
              colors: colors,
            ),
            validator: _validateEmail,
            onChanged: (_) =>
                ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 12),

          // Password
          TextFormField(
            controller: _signUpPasswordController,
            obscureText: !_isSignUpPasswordVisible,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Password (min 6 characters)',
              icon: Icons.lock_outline_rounded,
              colors: colors,
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignUpPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _isSignUpPasswordVisible = !_isSignUpPasswordVisible,
                ),
              ),
            ),
            validator: _validatePassword,
            onChanged: (_) =>
                ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 12),

          // Confirm Password
          TextFormField(
            controller: _signUpConfirmPasswordController,
            obscureText: !_isSignUpConfirmPasswordVisible,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Confirm Password',
              icon: Icons.lock_reset_rounded,
              colors: colors,
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignUpConfirmPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _isSignUpConfirmPasswordVisible =
                      !_isSignUpConfirmPasswordVisible,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _signUpPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            onChanged: (_) =>
                ref.read(authNotifierProvider.notifier).clearError(),
            onFieldSubmitted: (_) => _handleSignUp(),
          ),
          const SizedBox(height: 18),

          // Create Account Pill Button
          _buildGradientButton(
            label: 'Create Account',
            icon: Icons.person_add_alt_1_rounded,
            isLoading: authState.isLoading,
            colors: colors,
            onPressed: _handleSignUp,
          ),

          _buildDivider(colors, text: 'Or sign up with'),

          // Google Sign Up Button
          _buildGoogleSignInButton(
            colors,
            isLoading: authState.isLoading,
            label: 'Sign up with Google',
          ),
          const SizedBox(height: 16),

          // Switch to Login
          Center(
            child: GestureDetector(
              onTap: () => _switchTab(0),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Login',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required AppColors colors,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [colors.primary, colors.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider(AppColors colors, {required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.border)),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton(
    AppColors colors, {
    required bool isLoading,
    required String label,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: colors.border, width: 1.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: isLoading ? null : _handleGoogleSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchModePill({
    required AppColors colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: colors.border, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required AppColors colors,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: colors.primary),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 36),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: colors.error, width: 1.8),
      ),
    );
  }

  Widget _buildTrustFooter(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_rounded, color: colors.success, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'End-to-End Encrypted • 100% Family Safe • Zero Ads',
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Smooth curved wave clipper for the top illustration banner.
class _HeroWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 32);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 22,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 44,
      size.width,
      size.height - 16,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
