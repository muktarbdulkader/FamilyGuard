import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/auth_service.dart';

/// Child home screen - Status interface for monitored devices
/// Shows monitoring status, permissions, and parent contact options
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(currentUserDataProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Guardian'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: () => context.push('/child-status'),
            tooltip: 'Monitoring Status',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('About Monitoring'),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () => _showMonitoringInfo(context),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) {
                    context.go(AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: userData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              ElevatedButton(
                onPressed: () => ref.refresh(currentUserDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monitoring status card
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            color: Colors.orange[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parental Controls Active',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your device is being monitored for your safety',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.orange[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Welcome message
              Text(
                'Hi ${user?.displayName ?? 'there'}!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.hasFamily == true 
                    ? 'You\'re connected to your family. Your parents can help keep you safe online.'
                    : 'Ask your parent to add you to the family to get started.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Status items
              Expanded(
                child: ListView(
                  children: [
                    _StatusItem(
                      icon: Icons.security,
                      title: 'Device Permissions',
                      subtitle: 'Set up monitoring permissions',
                      status: 'Setup Required',
                      statusColor: Colors.orange,
                      onTap: () {
                        context.push('/child-permissions');
                      },
                    ),
                    
                    _StatusItem(
                      icon: Icons.apps,
                      title: 'App Permissions',
                      subtitle: 'Some apps may be blocked or time-limited',
                      status: 'Active',
                      statusColor: Colors.green,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('App monitoring will be implemented in Prompt 5'),
                          ),
                        );
                      },
                    ),
                    
                    _StatusItem(
                      icon: Icons.location_on,
                      title: 'Location Sharing',
                      subtitle: 'Your location helps keep you safe',
                      status: 'Enabled',
                      statusColor: Colors.blue,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location sharing will be implemented in Prompt 9'),
                          ),
                        );
                      },
                    ),
                    
                    _StatusItem(
                      icon: Icons.schedule,
                      title: 'Screen Time',
                      subtitle: 'Time limits help maintain balance',
                      status: 'Monitored',
                      statusColor: Colors.orange,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Screen time tracking will be implemented in Prompt 7'),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Help section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need Help?',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'If you need access to a blocked app or have questions about the monitoring, talk to your parents.',
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                context.push('/family-join');
                              },
                              icon: const Icon(Icons.family_restroom),
                              label: const Text('Join Family'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Show monitoring information dialog
  void _showMonitoringInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.orange),
            SizedBox(width: 8),
            Text('About Monitoring'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app helps your parents keep you safe by:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('• Monitoring which apps you use'),
            Text('• Setting time limits on certain apps'),
            Text('• Sharing your location with family'),
            Text('• Blocking inappropriate content'),
            SizedBox(height: 12),
            Text(
              'All monitoring is transparent - you\'ll always know what\'s being tracked. If you have questions or concerns, talk to your parents.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Status item widget
class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  const _StatusItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: statusColor),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}