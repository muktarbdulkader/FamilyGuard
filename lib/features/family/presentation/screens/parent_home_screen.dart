import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/user_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_service.dart';

/// Parent home screen - Dashboard for managing children's devices
/// Shows family status, child devices, and quick actions
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(currentUserDataProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                ),
                onTap: () {
                  AuthService().signOut();
                  context.go(AppRoutes.login);
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
        data: (user) => _buildDashboard(context, ref, user),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${user?.displayName ?? 'Parent'}!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.hasFamily == true
                        ? 'Your family is connected and protected.'
                        : 'Set up your family to start monitoring.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Connected Children section
          if (user?.hasFamily == true) ...[
            Text(
              'Connected Children',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildChildrenList(context, user?.familyId),
            const SizedBox(height: 24),
          ],
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _QuickActionCard(
                icon: Icons.family_restroom,
                title: 'Family Setup',
                subtitle: 'Add children to your family',
                color: Colors.blue,
                onTap: () => context.push('/family-setup'),
              ),
              _QuickActionCard(
                icon: Icons.apps,
                title: 'App Rules',
                subtitle: 'Manage app permissions',
                color: Colors.green,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select a child from the list above to manage their apps'),
                    ),
                  );
                },
              ),
              _QuickActionCard(
                icon: Icons.location_on,
                title: 'Location',
                subtitle: 'Track child location',
                color: Colors.orange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location tracking will be implemented in Prompt 9'),
                    ),
                  );
                },
              ),
              _QuickActionCard(
                icon: Icons.notifications,
                title: 'Requests',
                subtitle: 'Manage app requests',
                color: Colors.red,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('App requests will be implemented in Prompt 8'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenList(BuildContext context, String? familyId) {
    if (familyId == null) return const SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('familyId', isEqualTo: familyId)
          .where('role', isEqualTo: AppConstants.childRole)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading children: ${snapshot.error}'),
            ),
          );
        }

        final children = snapshot.data?.docs ?? [];
        
        if (children.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.child_care, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No children connected yet'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.push('/family-setup'),
                    child: const Text('Add Child'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: children.map((doc) {
            final childData = doc.data() as Map<String, dynamic>;
            final childName = childData['displayName'] ?? 'Child';
            final childEmail = childData['email'] ?? '';
            final lastSeen = childData['lastSeen'] as Timestamp?;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    childName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  childName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(childEmail),
                    if (lastSeen != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last seen: ${_formatLastSeen(lastSeen.toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const ListTile(
                        leading: Icon(Icons.apps),
                        title: Text('Manage Apps'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        context.push('/parent-apps/${doc.id}/$childName');
                      },
                    ),
                    PopupMenuItem(
                      child: const ListTile(
                        leading: Icon(Icons.location_on),
                        title: Text('View Location'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location tracking coming in Prompt 9'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  context.push('/parent-apps/${doc.id}/$childName');
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 5) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

/// Quick action card widget for the dashboard
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}