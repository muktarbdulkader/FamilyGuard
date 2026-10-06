import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/app_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';

/// Parent screen for managing child app rules and viewing usage
/// Real-time sync with Firestore for immediate rule enforcement
class ParentAppManagementScreen extends ConsumerStatefulWidget {
  final String childId;
  final String childName;

  const ParentAppManagementScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  ConsumerState<ParentAppManagementScreen> createState() => _ParentAppManagementScreenState();
}

class _ParentAppManagementScreenState extends ConsumerState<ParentAppManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AppRule? _filterRule;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Stream of child's apps from Firestore
  Stream<List<AppModel>> _getChildAppsStream() {
    final userData = ref.read(currentUserDataProvider).value;
    if (userData?.familyId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection(AppConstants.familiesCollection)
        .doc(userData!.familyId)
        .collection(AppConstants.childrenSubcollection)
        .doc(widget.childId)
        .collection(AppConstants.appsSubcollection)
        .orderBy('appName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppModel.fromFirestore(doc))
          .where((app) {
            // Apply search filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!app.appName.toLowerCase().contains(query) &&
                  !app.packageName.toLowerCase().contains(query)) {
                return false;
              }
            }
            
            // Apply rule filter
            if (_filterRule != null && app.rule != _filterRule) {
              return false;
            }
            
            return true;
          })
          .toList();
    });
  }

  /// Update app rule in Firestore
  Future<void> _updateAppRule(AppModel app, AppRule newRule) async {
    final userData = ref.read(currentUserDataProvider).value;
    if (userData?.familyId == null) return;

    try {
      final appDoc = FirebaseFirestore.instance
          .collection(AppConstants.familiesCollection)
          .doc(userData!.familyId)
          .collection(AppConstants.childrenSubcollection)
          .doc(widget.childId)
          .collection(AppConstants.appsSubcollection)
          .doc(app.packageName);

      await appDoc.update({
        'rule': newRule.toString(),
        'lastUpdated': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated ${app.appName} rule to ${newRule.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update rule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Set time limit for app
  Future<void> _setTimeLimit(AppModel app, int minutes) async {
    final userData = ref.read(currentUserDataProvider).value;
    if (userData?.familyId == null) return;

    try {
      final appDoc = FirebaseFirestore.instance
          .collection(AppConstants.familiesCollection)
          .doc(userData!.familyId)
          .collection(AppConstants.childrenSubcollection)
          .doc(widget.childId)
          .collection(AppConstants.appsSubcollection)
          .doc(app.packageName);

      await appDoc.update({
        'rule': AppRule.timeLimit.toString(),
        'dailyLimitMinutes': minutes,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set time limit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Set time window for app
  Future<void> _setTimeWindow(AppModel app, TimeWindow timeWindow) async {
    final userData = ref.read(currentUserDataProvider).value;
    if (userData?.familyId == null) return;

    try {
      final appDoc = FirebaseFirestore.instance
          .collection(AppConstants.familiesCollection)
          .doc(userData!.familyId)
          .collection(AppConstants.childrenSubcollection)
          .doc(widget.childId)
          .collection(AppConstants.appsSubcollection)
          .doc(app.packageName);

      await appDoc.update({
        'rule': AppRule.timeWindow.toString(),
        'allowedTimeWindow': timeWindow.toMap(),
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set time window: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get app icon widget
  Widget _buildAppIcon(AppModel app) {
    if (app.iconBase64 != null) {
      try {
        final iconBytes = base64Decode(app.iconBase64!);
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              iconBytes,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (e) {
        // Fall through to default icon
      }
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Icon(Icons.android, color: Colors.grey),
    );
  }

  /// Get rule color
  Color _getRuleColor(AppRule rule) {
    switch (rule) {
      case AppRule.allowed:
        return Colors.green;
      case AppRule.blocked:
        return Colors.red;
      case AppRule.timeLimit:
        return Colors.orange;
      case AppRule.askParent:
        return Colors.blue;
      case AppRule.timeWindow:
        return Colors.purple;
    }
  }

  /// Show app rule bottom sheet
  void _showAppRuleSheet(AppModel app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AppRuleSheet(
        app: app,
        onRuleChanged: _updateAppRule,
        onTimeLimitSet: _setTimeLimit,
        onTimeWindowSet: _setTimeWindow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName}\'s Apps'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _filterRule == null,
                      onSelected: (_) {
                        setState(() {
                          _filterRule = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ...AppRule.values.map((rule) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(rule.displayName),
                        selected: _filterRule == rule,
                        selectedColor: _getRuleColor(rule).withValues(alpha: 0.2),
                        onSelected: (_) {
                          setState(() {
                            _filterRule = _filterRule == rule ? null : rule;
                          });
                        },
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<AppModel>>(
        stream: _getChildAppsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final apps = snapshot.data ?? [];
          
          if (apps.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apps, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No apps found'),
                  SizedBox(height: 8),
                  Text(
                    'Ask your child to open the app and scan for apps',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: _buildAppIcon(app),
                  title: Text(
                    app.appName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.packageName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRuleColor(app.rule).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              app.rule.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: _getRuleColor(app.rule),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (app.rule == AppRule.timeLimit) ...[
                            Text(
                              '${app.usedTodayMinutes}/${app.dailyLimitMinutes}min',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ] else if (app.rule == AppRule.timeWindow && app.allowedTimeWindow != null) ...[
                            Text(
                              app.allowedTimeWindow!.displayString,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAppRuleSheet(app),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom sheet for managing app rules
class _AppRuleSheet extends StatefulWidget {
  final AppModel app;
  final Function(AppModel, AppRule) onRuleChanged;
  final Function(AppModel, int) onTimeLimitSet;
  final Function(AppModel, TimeWindow) onTimeWindowSet;

  const _AppRuleSheet({
    required this.app,
    required this.onRuleChanged,
    required this.onTimeLimitSet,
    required this.onTimeWindowSet,
  });

  @override
  State<_AppRuleSheet> createState() => _AppRuleSheetState();
}

class _AppRuleSheetState extends State<_AppRuleSheet> {
  late AppRule _selectedRule;
  int _timeLimitMinutes = 60;
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedRule = widget.app.rule;
    _timeLimitMinutes = widget.app.dailyLimitMinutes > 0 
        ? widget.app.dailyLimitMinutes 
        : 60;
    
    if (widget.app.allowedTimeWindow != null) {
      _startTime = TimeOfDay(
        hour: widget.app.allowedTimeWindow!.startHour,
        minute: widget.app.allowedTimeWindow!.startMinute,
      );
      _endTime = TimeOfDay(
        hour: widget.app.allowedTimeWindow!.endHour,
        minute: widget.app.allowedTimeWindow!.endMinute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.android),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.app.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Used today: ${widget.app.usedTodayMinutes} minutes',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Rule options
          Text(
            'App Rule',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ...AppRule.values.map((rule) => RadioListTile<AppRule>(
            title: Text(rule.displayName),
            subtitle: Text(_getRuleDescription(rule)),
            value: rule,
            groupValue: _selectedRule,
            onChanged: (value) {
              setState(() {
                _selectedRule = value!;
              });
            },
          )),

          // Time limit settings
          if (_selectedRule == AppRule.timeLimit) ...[
            const SizedBox(height: 16),
            Text(
              'Daily Time Limit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _timeLimitMinutes.toDouble(),
                    min: 15,
                    max: 480, // 8 hours
                    divisions: 31,
                    label: '${_timeLimitMinutes} minutes',
                    onChanged: (value) {
                      setState(() {
                        _timeLimitMinutes = value.round();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_timeLimitMinutes}min',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],

          // Time window settings
          if (_selectedRule == AppRule.timeWindow) ...[
            const SizedBox(height: 16),
            Text(
              'Allowed Time Window',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text('Start Time'),
                          const SizedBox(height: 4),
                          Text(
                            _startTime.format(context),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() {
                          _endTime = time;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text('End Time'),
                          const SizedBox(height: 4),
                          Text(
                            _endTime.format(context),
                            style: const TextStyle(
                              fontSize: 18,
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
          ],

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedRule == AppRule.timeLimit) {
                      widget.onTimeLimitSet(widget.app, _timeLimitMinutes);
                    } else if (_selectedRule == AppRule.timeWindow) {
                      final timeWindow = TimeWindow(
                        startHour: _startTime.hour,
                        startMinute: _startTime.minute,
                        endHour: _endTime.hour,
                        endMinute: _endTime.minute,
                      );
                      widget.onTimeWindowSet(widget.app, timeWindow);
                    } else {
                      widget.onRuleChanged(widget.app, _selectedRule);
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRuleDescription(AppRule rule) {
    switch (rule) {
      case AppRule.allowed:
        return 'App can be used without restrictions';
      case AppRule.blocked:
        return 'App is completely blocked';
      case AppRule.timeLimit:
        return 'App has a daily time limit';
      case AppRule.askParent:
        return 'Child must ask permission before using';
      case AppRule.timeWindow:
        return 'App can only be used during specific hours';
    }
  }
}