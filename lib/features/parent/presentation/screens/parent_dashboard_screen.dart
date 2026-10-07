import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/family_provider.dart';
import '../widgets/family_selector.dart';
import '../widgets/child_selector.dart';
import '../../../apps/presentation/screens/parent_app_management_screen.dart';

/// Main parent dashboard screen with family and child selection
/// Professional UI for managing parental controls
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(userFamiliesProvider);
    final selectedFamily = ref.watch(selectedFamilyProvider);
    final selectedChild = ref.watch(selectedChildProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header with family and child selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Icon(
                        Icons.family_restroom,
                        size: 28,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Family Controls',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            Text(
                              'Parental Control Dashboard',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showSettings(),
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Family Selector
                  familiesAsync.when(
                    loading: () => const _LoadingSelector(title: 'Loading families...'),
                    error: (error, stack) => _ErrorSelector(
                      title: 'Error loading families',
                      error: error.toString(),
                    ),
                    data: (families) {
                      if (families.isEmpty) {
                        return _EmptyStateSelector(
                          title: 'No families found',
                          subtitle: 'Create a family to start managing parental controls',
                          onAction: () => _showCreateFamilyDialog(),
                          actionLabel: 'Create Family',
                        );
                      }
                      
                      // Auto-select first family if none selected
                      if (selectedFamily == null && families.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ref.read(selectedFamilyProvider.notifier).state = families.first;
                        });
                      }
                      
                      return FamilySelector(
                        families: families,
                        selectedFamily: selectedFamily ?? families.first,
                        onFamilySelected: (family) {
                          ref.read(selectedFamilyProvider.notifier).state = family;
                          ref.read(selectedChildProvider.notifier).state = null;
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Child Selector
                  if (selectedFamily != null || familiesAsync.value?.isNotEmpty == true) ...[
                    Consumer(
                      builder: (context, ref, child) {
                        final childrenAsync = ref.watch(familyChildrenProvider);
                        
                        return childrenAsync.when(
                          loading: () => const _LoadingSelector(title: 'Loading children...'),
                          error: (error, stack) => _ErrorSelector(
                            title: 'Error loading children',
                            error: error.toString(),
                          ),
                          data: (children) {
                            if (children.isEmpty) {
                              return _EmptyStateSelector(
                                title: 'No children in this family',
                                subtitle: 'Invite children to join this family',
                                onAction: () => _showInviteChildDialog(),
                                actionLabel: 'Invite Child',
                              );
                            }
                            
                            // Auto-select first child if none selected
                            if (selectedChild == null && children.isNotEmpty) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(selectedChildProvider.notifier).state = children.first;
                              });
                            }
                            
                            return ChildSelector(
                              children: children,
                              selectedChild: selectedChild ?? children.first,
                              onChildSelected: (child) {
                                ref.read(selectedChildProvider.notifier).state = child;
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            
            // Tab Bar
            if (selectedFamily != null && selectedChild != null) ...[
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue[700],
                  tabs: const [
                    Tab(text: 'Apps', icon: Icon(Icons.apps_outlined, size: 20)),
                    Tab(text: 'Usage', icon: Icon(Icons.bar_chart_outlined, size: 20)),
                    Tab(text: 'Location', icon: Icon(Icons.location_on_outlined, size: 20)),
                  ],
                ),
              ),
              
              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Apps Tab
                    ParentAppManagementScreen(
                      childId: selectedChild.id,
                      familyId: selectedFamily.id,
                    ),
                    
                    // Usage Tab
                    _buildUsageTab(),
                    
                    // Location Tab
                    _buildLocationTab(),
                  ],
                ),
              ),
            ] else ...[
              // Welcome state
              Expanded(
                child: _buildWelcomeState(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 88,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to Family Guardian',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select a family and child above to start managing parental controls',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _FeatureCard(
              icon: Icons.apps,
              title: 'App Management',
              description: 'Control which apps your children can use and set time limits',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.schedule,
              title: 'Screen Time',
              description: 'Monitor usage and set healthy screen time boundaries',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.location_on,
              title: 'Location Safety',
              description: 'Keep track of your children\'s location for safety',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Usage Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Location Tracking',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    // TODO: Implement settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings coming soon')),
    );
  }

  void _showCreateFamilyDialog() {
    // TODO: Implement create family dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create family coming soon')),
    );
  }

  void _showInviteChildDialog() {
    // TODO: Implement invite child dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite child coming soon')),
    );
  }
}

// Helper widgets
class _LoadingSelector extends StatelessWidget {
  final String title;

  const _LoadingSelector({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
    );
  }
}

class _ErrorSelector extends StatelessWidget {
  final String title;
  final String error;

  const _ErrorSelector({
    required this.title,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                Text(
                  error,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[600],
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

class _EmptyStateSelector extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAction;
  final String actionLabel;

  const _EmptyStateSelector({
    required this.title,
    required this.subtitle,
    required this.onAction,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
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