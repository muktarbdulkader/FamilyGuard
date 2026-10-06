import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/models/app_info.dart';

class AppRuleEditorSheet extends ConsumerStatefulWidget {
  final AppWithUsage appWithUsage;
  final String familyId;
  final String childId;

  const AppRuleEditorSheet({
    Key? key,
    required this.appWithUsage,
    required this.familyId,
    required this.childId,
  }) : super(key: key);

  @override
  ConsumerState<AppRuleEditorSheet> createState() => _AppRuleEditorSheetState();
}

class _AppRuleEditorSheetState extends ConsumerState<AppRuleEditorSheet> {
  late AppRuleType _selectedRuleType;
  int _dailyLimitMinutes = 60;
  TimeOfDay _allowedStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _allowedEndTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRuleType = widget.appWithUsage.rule?.type ?? AppRuleType.allowed;
    if (widget.appWithUsage.rule?.dailyLimitMinutes != null) {
      _dailyLimitMinutes = widget.appWithUsage.rule!.dailyLimitMinutes!;
    }
    if (widget.appWithUsage.rule?.allowedStartTime != null) {
      _allowedStartTime = widget.appWithUsage.rule!.allowedStartTime!;
    }
    if (widget.appWithUsage.rule?.allowedEndTime != null) {
      _allowedEndTime = widget.appWithUsage.rule!.allowedEndTime!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              if (widget.appWithUsage.app.icon != null)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      widget.appWithUsage.app.icon!,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.android,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.appWithUsage.app.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.appWithUsage.app.packageName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Rule Type Selection
          Text(
            'Rule Type',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          ...AppRuleType.values.map((ruleType) => _buildRuleTypeOption(ruleType)),
          
          const SizedBox(height: 24),
          
          // Rule-specific settings
          if (_selectedRuleType == AppRuleType.timeLimit) ...[
            _buildTimeLimitSettings(),
            const SizedBox(height: 24),
          ],
          
          if (_selectedRuleType == AppRuleType.timeWindow) ...[
            _buildTimeWindowSettings(),
            const SizedBox(height: 24),
          ],
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Rule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleTypeOption(AppRuleType ruleType) {
    final isSelected = _selectedRuleType == ruleType;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedRuleType = ruleType),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          ),
          child: Row(
            children: [
              Icon(
                _getRuleTypeIcon(ruleType),
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getRuleTypeName(ruleType),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                      ),
                    ),
                    Text(
                      _getRuleTypeDescription(ruleType),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLimitSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Time Limit',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(_dailyLimitMinutes / 60).floor()}h ${_dailyLimitMinutes % 60}m'),
                  Text('${_dailyLimitMinutes} minutes'),
                ],
              ),
              const SizedBox(height: 16),
              Slider(
                value: _dailyLimitMinutes.toDouble(),
                min: 5,
                max: 480, // 8 hours
                divisions: 95,
                onChanged: (value) => setState(() => _dailyLimitMinutes = value.round()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeWindowSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Allowed Time Window',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectStartTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _allowedStartTime.format(context),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectEndTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _allowedEndTime.format(context),
                              style: const TextStyle(fontSize: 16),
                            ),
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
      ],
    );
  }

  IconData _getRuleTypeIcon(AppRuleType ruleType) {
    switch (ruleType) {
      case AppRuleType.allowed:
        return Icons.check_circle;
      case AppRuleType.blocked:
        return Icons.block;
      case AppRuleType.askParent:
        return Icons.help;
      case AppRuleType.timeLimit:
        return Icons.timer;
      case AppRuleType.timeWindow:
        return Icons.schedule;
    }
  }

  String _getRuleTypeName(AppRuleType ruleType) {
    switch (ruleType) {
      case AppRuleType.allowed:
        return 'Always Allowed';
      case AppRuleType.blocked:
        return 'Always Blocked';
      case AppRuleType.askParent:
        return 'Ask Parent';
      case AppRuleType.timeLimit:
        return 'Daily Time Limit';
      case AppRuleType.timeWindow:
        return 'Time Window';
    }
  }

  String _getRuleTypeDescription(AppRuleType ruleType) {
    switch (ruleType) {
      case AppRuleType.allowed:
        return 'App can be used without restrictions';
      case AppRuleType.blocked:
        return 'App is completely blocked';
      case AppRuleType.askParent:
        return 'Child must ask permission to use this app';
      case AppRuleType.timeLimit:
        return 'App usage limited to specified daily time';
      case AppRuleType.timeWindow:
        return 'App only available during specified hours';
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _allowedStartTime,
    );
    if (picked != null) {
      setState(() => _allowedStartTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _allowedEndTime,
    );
    if (picked != null) {
      setState(() => _allowedEndTime = picked);
    }
  }

  Future<void> _saveRule() async {
    setState(() => _isLoading = true);

    try {
      final appRule = AppRule(
        appPackageName: widget.appWithUsage.app.packageName,
        type: _selectedRuleType,
        dailyLimitMinutes: _selectedRuleType == AppRuleType.timeLimit ? _dailyLimitMinutes : null,
        allowedStartTime: _selectedRuleType == AppRuleType.timeWindow ? _allowedStartTime : null,
        allowedEndTime: _selectedRuleType == AppRuleType.timeWindow ? _allowedEndTime : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(appRuleServiceProvider).updateAppRule(
        familyId: widget.familyId,
        childId: widget.childId,
        appRule: appRule,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rule updated for ${widget.appWithUsage.app.appName}'),
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}