import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/models/app_info.dart';
import '../../../../core/models/family_model.dart';
import '../../parent/presentation/widgets/app_rule_editor_sheet.dart';
import '../../parent/presentation/widgets/app_usage_indicator.dart';
import '../../parent/presentation/widgets/app_search_bar.dart';

/// Professional parent screen for managing child app rules and viewing usage
/// Real-time sync with Firestore for immediate rule enforcement on child devices
class ParentAppManagementScreen extends ConsumerStatefulWidget {
  final String childId;
  final String childName;
  final String familyId;

  const ParentAppManagementScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.familyId,
  });

  @override
  ConsumerState<ParentAppManagementScreen> createState() => _ParentAppManagementScreenState();
}

class _ParentAppManagementScreenState extends ConsumerState<ParentAppManagementScreen> {
  String _searchQuery = '';
  AppControlRule? _filterRule;
  bool _showOnlyBlocked = false;
  bool _showOnlyLimited = false;

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(childAppsProvider(widget.childId));
    final usageAsync = ref.watch(childAppUsageProvider(widget.childId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Search and Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                AppSearchBar(
                  onSearchChanged: (query) {
                    setState(() {
                      _searchQuery = query.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Apps'),
                        selected: _filterRule == null && !_showOnlyBlocked && !_showOnlyLimited,
                        onSelected: (_) {
                          setState(() {
                            _filterRule = null;
                            _showOnlyBlocked = false;
                            _showOnlyLimited = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Blocked'),
                        selected: _showOnlyBlocked,
                        selectedColor: Colors.red[100],
                        onSelected: (_) {
                          setState(() {
                            _showOnlyBlocked = !_showOnlyBlocked;
                            _filterRule = null;
                            _showOnlyLimited = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Time Limited'),
                        selected: _showOnlyLimited,
                        selectedColor: Colors.orange[100],
                        onSelected: (_) {
                          setState(() {
                            _showOnlyLimited = !_showOnlyLimited;
                            _filterRule = null;
                            _showOnlyBlocked = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...AppControlRule.values.map((rule) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(rule.displayName),
                          selected: _filterRule == rule,
                          selectedColor: _getRuleColor(rule).withOpacity(0.2),
                          onSelected: (_) {
                            setState(() {
                              _filterRule = _filterRule == rule ? null : rule;
                              _showOnlyBlocked = false;
                              _showOnlyLimited = false;
                            });
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Apps list
          Expanded(
            child: appsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error.toString()),
              data: (apps) => usageAsync.when(
                loading: () => _buildAppsList(apps, {}),
                error: (error, stack) => _buildAppsList(apps, {}),
                data: (usageMap) => _buildAppsList(apps, usageMap),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsList(List<AppInfo> apps, Map<String, AppUsageModel> usageMap) {
    // Apply filters
    final filteredApps = apps.where((app) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        if (!app.name.toLowerCase().contains(_searchQuery) &&
            !app.packageName.toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }
      
      // Rule filters
      if (_showOnlyBlocked && app.rule != AppControlRule.block) {
        return false;
      }
      
      if (_showOnlyLimited && app.rule != AppControlRule.timeLimited) {
        return false;
      }
      
      if (_filterRule != null && app.rule != _filterRule) {
        return false;
      }
      
      return true;
    }).toList();

    if (filteredApps.isEmpty) {
      return _buildEmptyState();
    }

    // Sort apps: blocked first, then by name
    filteredApps.sort((a, b) {
      if (a.rule == AppControlRule.block && b.rule != AppControlRule.block) {
        return -1;
      }
      if (b.rule == AppControlRule.block && a.rule != AppControlRule.block) {
        return 1;
      }
      return a.name.compareTo(b.name);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        final app = filteredApps[index];
        final usage = usageMap[app.packageName];
        final appWithUsage = AppWithUsage(app: app, usage: usage);
        
        return _AppListItem(
          appWithUsage: appWithUsage,
          onTap: () => _showAppRuleEditor(appWithUsage),
        );
      },
    );
  }
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading apps',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(childAppsProvider(widget.childId));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No apps found' : 'No apps available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'Try adjusting your search or filters'
                  : 'Ask ${widget.childName} to scan for apps on their device',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

/// Individual app list item widget
class _AppListItem extends StatelessWidget {
  final AppWithUsage appWithUsage;
  final VoidCallback onTap;

  const _AppListItem({
    required this.appWithUsage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final app = appWithUsage.app;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // App icon
              _buildAppIcon(),
              const SizedBox(width: 16),
              
              // App info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.packageName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Rule and usage info
                    Row(
                      children: [
                        // Rule badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: appWithUsage.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: appWithUsage.statusColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            appWithUsage.statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: appWithUsage.statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Usage info
                        Expanded(
                          child: Text(
                            appWithUsage.usageStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Usage indicator for time-limited apps
                    if (app.rule == AppControlRule.timeLimited && app.dailyLimitMinutes != null) ...[
                      const SizedBox(height: 8),
                      // AppUsageIndicator will be implemented separately
                      LinearProgressIndicator(
                        value: appWithUsage.usagePercentage,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          appWithUsage.isOverLimit ? Colors.red : Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Chevron icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    if (appWithUsage.app.iconBase64 != null) {
      try {
        final iconBytes = base64Decode(appWithUsage.app.iconBase64!);
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.memory(
              iconBytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (e) {
        // Fall through to default icon
      }
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Icon(
        Icons.android,
        color: Colors.blue[600],
        size: 28,
      ),
    );
  }

  void _showAppRuleEditor(AppWithUsage appWithUsage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => AppRuleEditorSheet(
          appWithUsage: appWithUsage,
          familyId: widget.familyId,
          childId: widget.childId,
        ),
      ),
    );
  }

  Color _getRuleColor(AppControlRule rule) {
    switch (rule) {
      case AppControlRule.allow:
        return Colors.green;
      case AppControlRule.block:
        return Colors.red;
      case AppControlRule.ask:
        return Colors.blue;
      case AppControlRule.timeLimited:
        return Colors.orange;
      case AppControlRule.timeRestricted:
        return Colors.purple;
    }
  }
}