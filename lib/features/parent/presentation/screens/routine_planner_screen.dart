import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/family_model.dart';
import '../../../../core/models/routine_model.dart';
import '../../../../core/services/routine_service.dart';

final _routinePlannerChildrenProvider =
    StreamProvider.family<List<ChildModel>, String>((ref, familyId) {
      if (familyId.isEmpty) return Stream.value([]);
      final firestore = FirebaseFirestore.instance;
      return firestore
          .collection('families')
          .doc(familyId)
          .snapshots()
          .asyncMap((familySnapshot) async {
            if (!familySnapshot.exists) return <ChildModel>[];
            final childIds = FamilyModel.fromFirestore(
              familySnapshot,
            ).childrenIds;
            final childSnapshots = await Future.wait(
              childIds.map(
                (childId) => firestore.collection('users').doc(childId).get(),
              ),
            );
            return childSnapshots
                .where(
                  (snapshot) =>
                      snapshot.exists &&
                      snapshot.data()?['familyId'] == familyId &&
                      snapshot.data()?['role'] == 'child',
                )
                .map(ChildModel.fromFirestore)
                .toList();
          });
    });

class RoutinePlannerScreen extends ConsumerStatefulWidget {
  final String familyId;

  const RoutinePlannerScreen({super.key, required this.familyId});

  @override
  ConsumerState<RoutinePlannerScreen> createState() =>
      _RoutinePlannerScreenState();
}

class _RoutinePlannerScreenState extends ConsumerState<RoutinePlannerScreen> {
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(
      _routinePlannerChildrenProvider(widget.familyId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Routine planner')),
      floatingActionButton: childrenAsync.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => _editRoutine(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add routine'),
            )
          : null,
      body: widget.familyId.isEmpty
          ? const Center(child: Text('Select a family to plan routines.'))
          : childrenAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _LoadError(
                message: 'Could not load family children: $error',
                onRetry: () => ref.invalidate(
                  _routinePlannerChildrenProvider(widget.familyId),
                ),
              ),
              data: (children) {
                if (children.isEmpty) {
                  return const Center(
                    child: Text('Pair a child device to create routines.'),
                  );
                }
                final selectedChild = children.firstWhere(
                  (child) => child.id == _selectedChildId,
                  orElse: () => children.first,
                );
                final routinesAsync = ref.watch(
                  childRoutinesProvider((
                    familyId: widget.familyId,
                    childId: selectedChild.id,
                  )),
                );
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: DropdownButtonFormField<String>(
                        value: selectedChild.id,
                        decoration: const InputDecoration(
                          labelText: 'Child',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final child in children)
                            DropdownMenuItem(
                              value: child.id,
                              child: Text(child.displayName),
                            ),
                        ],
                        onChanged: (id) {
                          if (id != null) {
                            setState(() => _selectedChildId = id);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: routinesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => _LoadError(
                          message: 'Could not load routines: $error',
                          onRetry: () => ref.invalidate(
                            childRoutinesProvider((
                              familyId: widget.familyId,
                              childId: selectedChild.id,
                            )),
                          ),
                        ),
                        data: (routines) => routines.isEmpty
                            ? _EmptyRoutines(
                                onCreate: () => _editRoutine(context, null),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  96,
                                ),
                                itemCount: routines.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final routine = routines[index];
                                  return _RoutineCard(
                                    routine: routine,
                                    onEdit: () =>
                                        _editRoutine(context, routine),
                                    onToggle: (active) => _toggleRoutine(
                                      context,
                                      routine,
                                      active,
                                    ),
                                    onDelete: () =>
                                        _deleteRoutine(context, routine),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _editRoutine(
    BuildContext context,
    RoutineModel? existing,
  ) async {
    final children = ref
        .read(_routinePlannerChildrenProvider(widget.familyId))
        .valueOrNull;
    if (children == null || children.isEmpty) return;
    final child = children.firstWhere(
      (item) => item.id == _selectedChildId,
      orElse: () => children.first,
    );
    final result = await showDialog<RoutineModel>(
      context: context,
      builder: (_) => _RoutineEditorDialog(
        familyId: widget.familyId,
        childId: child.id,
        existing: existing,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final service = ref.read(routineServiceProvider);
      if (existing == null) {
        await service.createRoutine(familyId: widget.familyId, routine: result);
      } else {
        await service.updateRoutine(familyId: widget.familyId, routine: result);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save routine: $error')),
        );
      }
    }
  }

  Future<void> _toggleRoutine(
    BuildContext context,
    RoutineModel routine,
    bool active,
  ) async {
    try {
      await ref
          .read(routineServiceProvider)
          .toggleRoutine(
            familyId: widget.familyId,
            routineId: routine.id,
            isActive: active,
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update routine: $error')),
        );
      }
    }
  }

  Future<void> _deleteRoutine(
    BuildContext context,
    RoutineModel routine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text('Delete "${routine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(routineServiceProvider)
          .deleteRoutine(familyId: widget.familyId, routineId: routine.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete routine: $error')),
        );
      }
    }
  }
}

class _RoutineCard extends StatelessWidget {
  final RoutineModel routine;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: routine.templateType.color.withOpacity(0.15),
                child: Icon(
                  routine.templateType.icon,
                  color: routine.templateType.color,
                ),
              ),
              title: Text(
                routine.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${MaterialLocalizations.of(context).formatTimeOfDay(routine.startTime)} – ${MaterialLocalizations.of(context).formatTimeOfDay(routine.endTime)}',
              ),
              trailing: Switch(value: routine.isActive, onChanged: onToggle),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 5,
                children: [
                  for (final day in routine.daysOfWeek)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(_weekdayName(day)),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (routine.description?.isNotEmpty == true)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    routine.description!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            if (routine.allowedCategories.isNotEmpty ||
                routine.blockedCategories.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [
                      if (routine.allowedCategories.isNotEmpty)
                        'Allowed: ${routine.allowedCategories.join(', ')}',
                      if (routine.blockedCategories.isNotEmpty)
                        'Blocked: ${routine.blockedCategories.join(', ')}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _weekdayName(int day) =>
    const {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    }[day] ??
    '';

class _EmptyRoutines extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyRoutines({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('No routines planned for this child.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create first routine'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineEditorDialog extends StatefulWidget {
  final String familyId;
  final String childId;
  final RoutineModel? existing;

  const _RoutineEditorDialog({
    required this.familyId,
    required this.childId,
    this.existing,
  });

  @override
  State<_RoutineEditorDialog> createState() => _RoutineEditorDialogState();
}

class _RoutineEditorDialogState extends State<_RoutineEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _allowedController;
  late final TextEditingController _blockedController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late RoutineTemplate _template;
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    final routine = widget.existing;
    _nameController = TextEditingController(text: routine?.name ?? '');
    _descriptionController = TextEditingController(
      text: routine?.description ?? '',
    );
    _allowedController = TextEditingController(
      text: routine?.allowedCategories.join(', ') ?? '',
    );
    _blockedController = TextEditingController(
      text: routine?.blockedCategories.join(', ') ?? '',
    );
    _startTime = routine?.startTime ?? const TimeOfDay(hour: 16, minute: 0);
    _endTime = routine?.endTime ?? const TimeOfDay(hour: 17, minute: 0);
    _template = routine?.templateType ?? RoutineTemplate.study;
    _days = Set<int>.from(routine?.daysOfWeek ?? [1, 2, 3, 4, 5]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _allowedController.dispose();
    _blockedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add routine' : 'Edit routine'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Routine name'),
              autofocus: true,
            ),
            DropdownButtonFormField<RoutineTemplate>(
              value: _template,
              decoration: const InputDecoration(labelText: 'Template'),
              items: [
                for (final template in RoutineTemplate.values)
                  DropdownMenuItem(
                    value: template,
                    child: Text(template.displayName),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _template = value);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: _timeButton(
                    label: 'Starts',
                    value: _startTime,
                    onChanged: (time) => setState(() => _startTime = time),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeButton(
                    label: 'Ends',
                    value: _endTime,
                    onChanged: (time) => setState(() => _endTime = time),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Repeat on'),
            Wrap(
              spacing: 4,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_weekdayName(day)),
                    selected: _days.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _days.add(day);
                        } else {
                          _days.remove(day);
                        }
                      });
                    },
                  ),
              ],
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            TextField(
              controller: _allowedController,
              decoration: const InputDecoration(
                labelText: 'Allowed categories (comma separated)',
              ),
            ),
            TextField(
              controller: _blockedController,
              decoration: const InputDecoration(
                labelText: 'Blocked categories (comma separated)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _timeButton({
    required String label,
    required TimeOfDay value,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return OutlinedButton(
      onPressed: () async {
        final time = await showTimePicker(context: context, initialTime: value);
        if (time != null) onChanged(time);
      },
      child: Text(
        '$label · ${MaterialLocalizations.of(context).formatTimeOfDay(value)}',
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a name and choose at least one day.'),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final previous = widget.existing;
    Navigator.pop(
      context,
      RoutineModel(
        id: previous?.id ?? '',
        familyId: widget.familyId,
        childId: widget.childId,
        name: name,
        templateType: _template,
        startTime: _startTime,
        endTime: _endTime,
        daysOfWeek: _days.toList()..sort(),
        isActive: previous?.isActive ?? true,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        allowedCategories: _splitCategories(_allowedController.text),
        blockedCategories: _splitCategories(_blockedController.text),
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  List<String> _splitCategories(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
