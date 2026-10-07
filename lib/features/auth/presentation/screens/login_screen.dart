import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';

/// Professional login screen with role-based theming and FamilyGuard branding
/// Features secure authentication with smooth UX and role-specific flows
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

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
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
      final user = ref.read(authNotifierProvider).user;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user?.displayName ?? 'User'}!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created successfully! Welcome, $name.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Direct navigation straight into role selection
      context.go(AppRoutes.roleSelection);
    }
  }

  /// Handle Password Reset
  Future<void> _handlePasswordReset() async {
    final email = _signInEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address to reset password.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.resetPassword(email);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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

  /// Get role-specific color for theming
  Color _getRoleColor() {
    if (widget.selectedRole == null) return AppTheme.primaryColor;
    return widget.selectedRole == UserRole.parent
        ? AppTheme.parentPrimary
        : AppTheme.childPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC), const Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    
                    // App Brand Header
                    _buildHeader(theme, isDark),
                    
                    const SizedBox(height: 28),

                    // Card Container
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Tab Selector
                          _buildTabSelector(isDark),
                          
                          const SizedBox(height: 20),

                          // Error alert
                          if (authState.errorMessage != null) ...[
                            _buildErrorBanner(authState.errorMessage!),
                            const SizedBox(height: 16),
                          ],

                          // Form Content based on tab
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _tabController.index == 0
                                ? _buildSignInForm(authState)
                                : _buildSignUpForm(authState),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Privacy notice
                    Text(
                      AppConstants.appDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.4,
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

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Professional App Logo using our AppLogo widget
        AppLogo(
          size: 80,
          showBackground: true,
        ),
        const SizedBox(height: 16),
        
        // Use our app constants for branding
        Text(
          AppConstants.appName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppConstants.appTagline,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // Role indicator if selected
        if (widget.selectedRole != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.selectedRole == UserRole.parent ? AppIcons.parent : AppIcons.child,
                  size: 16,
                  color: _getRoleColor(),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.selectedRole!.displayName} Account',
                  style: TextStyle(
                    color: _getRoleColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabSelector(bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: const Color(0xFF4F46E5),
        unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Sign In'),
          Tab(text: 'Create Account'),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInForm(AuthState authState) {
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
            decoration: _inputDecoration(
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.alternate_email_rounded,
            ),
            validator: _validateEmail,
            onChanged: (_) => ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _signInPasswordController,
            obscureText: !_isSignInPasswordVisible,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignInPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _isSignInPasswordVisible = !_isSignInPasswordVisible),
              ),
            ),
            validator: (val) => (val == null || val.isEmpty) ? 'Please enter your password' : null,
            onChanged: (_) => ref.read(authNotifierProvider.notifier).clearError(),
            onFieldSubmitted: (_) => _handleSignIn(),
          ),
          const SizedBox(height: 8),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: authState.isLoading ? null : _handlePasswordReset,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          _buildActionButton(
            label: 'Sign In',
            isLoading: authState.isLoading,
            onPressed: _handleSignIn,
          ),
          
          const SizedBox(height: 16),

          // Quick Switch
          Center(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(1);
                ref.read(authNotifierProvider.notifier).clearError();
              },
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  children: [
                    TextSpan(text: 'Don\'t have an account? '),
                    TextSpan(
                      text: 'Create one',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.bold,
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

  Widget _buildSignUpForm(AuthState authState) {
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
            decoration: _inputDecoration(
              label: 'Full Name',
              hint: 'e.g., Alex Johnson',
              icon: Icons.person_outline_rounded,
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
            onChanged: (_) => ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 14),

          // Email
          TextFormField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Email address',
              hint: 'you@example.com',
              icon: Icons.alternate_email_rounded,
            ),
            validator: _validateEmail,
            onChanged: (_) => ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 14),

          // Password
          TextFormField(
            controller: _signUpPasswordController,
            obscureText: !_isSignUpPasswordVisible,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Password',
              hint: 'At least 6 characters',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignUpPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _isSignUpPasswordVisible = !_isSignUpPasswordVisible),
              ),
            ),
            validator: _validatePassword,
            onChanged: (_) => ref.read(authNotifierProvider.notifier).clearError(),
          ),
          const SizedBox(height: 14),

          // Confirm Password
          TextFormField(
            controller: _signUpConfirmPasswordController,
            obscureText: !_isSignUpConfirmPasswordVisible,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              icon: Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _isSignUpConfirmPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _isSignUpConfirmPasswordVisible = !_isSignUpConfirmPasswordVisible),
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
            onChanged: (_) => ref.read(authNotifierProvider.notifier).clearError(),
            onFieldSubmitted: (_) => _handleSignUp(),
          ),
          const SizedBox(height: 20),

          // Submit Button
          _buildActionButton(
            label: 'Create Account & Continue',
            isLoading: authState.isLoading,
            onPressed: _handleSignUp,
          ),
          
          const SizedBox(height: 16),

          // Quick Switch
          Center(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(0);
                ref.read(authNotifierProvider.notifier).clearError();
              },
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  children: [
                    TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.bold,
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

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    final roleColor = _getRoleColor();
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [roleColor, roleColor.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: roleColor.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}