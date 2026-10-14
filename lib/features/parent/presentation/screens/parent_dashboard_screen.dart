import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/models/family_model.dart';
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
  bool _autoSelectDone = false;

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

  /// Auto-select first family + first child so tabs are immediately usable
  void _maybeAutoSelect(
    List<FamilyModel> families,
    FamilyModel? selectedFamily,
    List<ChildModel> children,
    ChildModel? selectedChild,
  ) {
    if (_autoSelectDone) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectedFamily == null && families.isNotEmpty) {
        ref.read(selectedFamilyProvider.notifier).state = families.first;
      }
      if (selectedChild == null && children.isNotEmpty) {
        ref.read(selectedChildProvider.notifier).state = children.first;
      }
      _autoSelectDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(userFamiliesProvider);
    final selectedFamily = ref.watch(selectedFamilyProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final childrenAsync = ref.watch(familyChildrenProvider);

    // Auto-select first family and child on load
    familiesAsync.whenData((families) {
      childrenAsync.whenData((children) {
        _maybeAutoSelect(families, selectedFamily, children, selectedChild);
      });
    });

    final effectiveFamilyId = selectedFamily?.id ?? '';
    final effectiveChildId = selectedChild?.id ?? '';
    final hasSelection = effectiveFamilyId.isNotEmpty && effectiveChildId.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
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
                      Icon(Icons.family_restroom, size: 28, color: Colors.blue[600]),
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

                  // Child Selector (always show when family available)
                  if (selectedFamily != null)
                    childrenAsync.when(
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
                        return ChildSelector(
                          children: children,
                          selectedChild: selectedChild ?? children.first,
                          onChildSelected: (child) {
                            ref.read(selectedChildProvider.notifier).state = child;
                          },
                        );
                      },
                    ),
                ],
              ),
            ),

            // ── Tab Bar — always visible ──────────────────────────
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

            // ── Tab Views ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Apps Tab
                  hasSelection
                      ? ParentAppManagementScreen(
                          childId: effectiveChildId,
                          familyId: effectiveFamilyId,
                        )
                      : _buildNoSelectionPrompt(
                          icon: Icons.apps_rounded,
                          color: Colors.blue,
                          title: 'Select a Child to Manage Apps',
                          subtitle:
                              'Choose a family and child above to see installed apps and set rules.',
                        ),

                  // Usage Tab
                  hasSelection
                      ? _buildUsageTab()
                      : _buildNoSelectionPrompt(
                          icon: Icons.bar_chart_rounded,
                          color: Colors.green,
                          title: 'Select a Child to View Usage',
                          subtitle:
                              'Choose a child above to view their screen time reports.',
                        ),

                  // Location Tab
                  _buildLocationTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generic "no child selected" prompt shown inside tabs
  Widget _buildNoSelectionPrompt({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 52, color: color),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.familySetup),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Pair a Child Device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildUsageTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_rounded, size: 64, color: Colors.blue[600]),
                const SizedBox(height: 16),
                const Text(
                  'Real-Time App Usage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usage monitoring is active for this child device.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.rule_rounded),
                  label: const Text('Manage App Rules'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded, size: 64, color: Colors.orange[600]),
                const SizedBox(height: 16),
                const Text(
                  'Family GPS & Safe Zones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'View live map tracking and configure safe zone geofences.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.parentLocation),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Open Live Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parent Controls Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded, color: Color(0xFF4F46E5)),
                title: const Text('Notification Preferences'),
                subtitle: const Text('Alerts for requests, new apps, and limits'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/notifications');
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_rounded, color: Color(0xFF10B981)),
                title: const Text('Pair New Device'),
                subtitle: const Text('Generate 6-digit code or QR for child'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.familySetup);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFD97706)),
                title: const Text('Switch Role'),
                subtitle: const Text('Change account mode to child companion'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.roleSelection);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFamilyDialog() {
    context.push(AppRoutes.familySetup);
  }

  void _showInviteChildDialog() {
    context.push(AppRoutes.familySetup);
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
