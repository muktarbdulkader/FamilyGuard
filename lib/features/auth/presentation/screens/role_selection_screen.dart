import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/auth_service.dart';

/// Role selection screen shown after initial registration
/// Allows user to choose between Parent and Child roles
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;
  String? _errorMessage;

  /// Set user role and navigate to appropriate home screen
  Future<void> _setRole(String role) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedRole = role;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.setUserRole(user.uid, role);

      // Navigate based on role
      if (mounted) {
        if (role == AppConstants.parentRole) {
          context.go(AppRoutes.parentHome);
        } else {
          context.go(AppRoutes.childHome);
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _selectedRole = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to set role. Please try again.';
        _selectedRole = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Show role explanation dialog
  void _showRoleInfo(String role) {
    String title;
    String description;
    IconData icon;
    Color color;

    if (role == AppConstants.parentRole) {
      title = 'Parent Account';
      description = '''
• Monitor your child's device usage
• Set app permissions and time limits  
• Track location and create safe zones
• Approve or deny app requests
• View usage reports and activity
• Manage family settings
      ''';
      icon = Icons.supervisor_account;
      color = Colors.blue;
    } else {
      title = 'Child Account';
      description = '''
• Your device will be monitored for safety
• Parents can see which apps you use
• Some apps may be blocked or time-limited
• You can request permission for blocked apps
• Location sharing keeps you safe
• All monitoring is transparent
      ''';
      icon = Icons.child_care;
      color = Colors.orange;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This account type includes:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(description.trim()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _setRole(role);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text('Choose $title'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Redirect if user is not authenticated
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Choose Your Role',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select whether you are a parent monitoring devices or a child whose device will be monitored.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Role selection cards
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Parent role card
                    Expanded(
                      child: _RoleCard(
                        role: AppConstants.parentRole,
                        title: 'I am a Parent',
                        subtitle: 'Monitor and manage children\'s devices',
                        icon: Icons.supervisor_account,
                        color: Colors.blue,
                        isSelected: _selectedRole == AppConstants.parentRole,
                        isLoading: _isLoading && _selectedRole == AppConstants.parentRole,
                        onTap: () => _showRoleInfo(AppConstants.parentRole),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Child role card
                    Expanded(
                      child: _RoleCard(
                        role: AppConstants.childRole,
                        title: 'I am a Child',
                        subtitle: 'This device will be monitored by parents',
                        icon: Icons.child_care,
                        color: Colors.orange,
                        isSelected: _selectedRole == AppConstants.childRole,
                        isLoading: _isLoading && _selectedRole == AppConstants.childRole,
                        onTap: () => _showRoleInfo(AppConstants.childRole),
                      ),
                    ),
                  ],
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Logout option
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: TextButton.icon(
                  onPressed: _isLoading ? null : () async {
                    await ref.read(authServiceProvider).signOut();
                    if (mounted) {
                      context.go(AppRoutes.login);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Role selection card widget
class _RoleCard extends StatelessWidget {
  final String role;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 8 : 2,
      shadowColor: isSelected ? color.withValues(alpha: 0.3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                CircularProgressIndicator(color: color)
              else
                Icon(
                  icon,
                  size: 48,
                  color: color,
                ),
              
              const SizedBox(height: 16),
              
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : null,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tap to learn more',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}