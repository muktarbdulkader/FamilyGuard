import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/educational_material_model.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/services/education_service.dart';
import '../../../../l10n/app_localizations.dart';
import 'material_viewer_screen.dart';

class ChildEducationScreen extends ConsumerStatefulWidget {
  final String? familyId;
  final String? childId;
  final String? childName;

  const ChildEducationScreen({
    super.key,
    this.familyId,
    this.childId,
    this.childName,
  });

  @override
  ConsumerState<ChildEducationScreen> createState() => _ChildEducationScreenState();
}

class _ChildEducationScreenState extends ConsumerState<ChildEducationScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedSubject = 'All';

  final List<String> _statusTabs = ['All', 'Pending', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserDataProvider).value;

    final familyId = widget.familyId ?? user?.familyId ?? '';
    final childId = widget.childId ?? user?.uid ?? '';
    final childName = widget.childName ?? user?.displayName ?? 'Student';

    if (familyId.isEmpty || childId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.myLearning)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No family account linked. Please verify your account setup.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final materialsAsync = ref.watch(
      childEducationalMaterialsProvider((familyId: familyId, childId: childId)),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.myLearning,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Hello, $childName • Ready to study?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: l10n.all),
            const Tab(text: 'To Do'),
            const Tab(text: 'In Progress'),
            Tab(text: l10n.done),
          ],
        ),
      ),
      body: materialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load learning materials',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(
                    childEducationalMaterialsProvider((familyId: familyId, childId: childId)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (materials) {
          final subjects = _extractSubjects(materials);
          final filtered = _filterMaterials(materials, childId);

          final completedCount = materials.where((m) => m.isCompletedBy(childId)).length;
          final totalCount = materials.length;

          return CustomScrollView(
            slivers: [
              // Hero Progress Header
              SliverToBoxAdapter(
                child: _buildProgressBanner(theme, completedCount, totalCount),
              ),

              // Search & Subject Filter Bar
              SliverToBoxAdapter(
                child: _buildSearchAndFilterBar(theme, subjects),
              ),

              // Empty or List
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(theme, materials.isEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final material = filtered[index];
                        return _buildMaterialCard(theme, material, familyId, childId, childName);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<String> _extractSubjects(List<EducationalMaterial> list) {
    final set = <String>{'All'};
    for (final m in list) {
      if (m.subject.isNotEmpty) {
        set.add(m.subject);
      }
    }
    return set.toList();
  }

  List<EducationalMaterial> _filterMaterials(List<EducationalMaterial> list, String childId) {
    final currentTab = _tabController.index; // 0: All, 1: Pending, 2: In Progress, 3: Completed

    return list.where((m) {
      final status = m.statusFor(childId);

      // Status Tab filter
      if (currentTab == 1 && status != LearningStatus.pending) return false;
      if (currentTab == 2 && status != LearningStatus.inProgress) return false;
      if (currentTab == 3 && status != LearningStatus.completed) return false;

      // Subject filter
      if (_selectedSubject != 'All' && m.subject != _selectedSubject) return false;

      // Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = m.title.toLowerCase().contains(q);
        final matchesDesc = m.description.toLowerCase().contains(q);
        final matchesSubject = m.subject.toLowerCase().contains(q);
        if (!matchesTitle && !matchesDesc && !matchesSubject) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildProgressBanner(ThemeData theme, int completed, int total) {
    final progress = total > 0 ? (completed / total) : 0.0;
    final percent = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Journey',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$completed of $total lessons completed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$percent%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(ThemeData theme, List<String> subjects) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search lessons or subjects...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
          if (subjects.length > 2) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subjects.map((sub) {
                  final isSelected = _selectedSubject == sub;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(sub),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          _selectedSubject = val ? sub : 'All';
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialCard(
    ThemeData theme,
    EducationalMaterial material,
    String familyId,
    String childId,
    String childName,
  ) {
    final status = material.statusFor(childId);
    final isCompleted = status == LearningStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompleted
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => MaterialViewerScreen(
                material: material,
                familyId: familyId,
                childId: childId,
                childName: childName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type icon, title, completion checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _colorForType(theme, material.type).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForType(material.type),
                      color: _colorForType(theme, material.type),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                material.subject,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                material.type.badgeLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isCompleted ? Colors.green : theme.colorScheme.outline,
                      size: 26,
                    ),
                    tooltip: isCompleted ? 'Completed' : 'Mark as completed',
                    onPressed: () => _toggleQuickComplete(material, familyId, childId, childName),
                  ),
                ],
              ),

              if (material.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  material.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              if (material.instructions != null && material.instructions!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          material.instructions!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Bottom status & Action Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (material.dueDate != null) ...[
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: material.isOverdue && !isCompleted ? Colors.red : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d').format(material.dueDate!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: material.isOverdue && !isCompleted ? Colors.red : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Open Lesson →',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleQuickComplete(
    EducationalMaterial material,
    String familyId,
    String childId,
    String childName,
  ) async {
    final isCompleted = material.isCompletedBy(childId);
    final nextStatus = isCompleted ? LearningStatus.inProgress : LearningStatus.completed;

    try {
      await ref.read(educationServiceProvider).updateChildProgress(
            familyId: familyId,
            materialId: material.id,
            childId: childId,
            childName: childName,
            status: nextStatus,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: nextStatus == LearningStatus.completed ? Colors.green : Colors.blue,
            content: Text(
              nextStatus == LearningStatus.completed
                  ? '🎉 Nice work! Lesson completed.'
                  : 'Lesson marked as in progress.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState(ThemeData theme, bool isTotalEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTotalEmpty ? Icons.auto_stories : Icons.filter_alt_off,
                size: 52,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isTotalEmpty ? 'No Lessons Assigned Yet' : 'No Matching Lessons Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isTotalEmpty
                  ? 'Your parent will assign educational materials, videos, and study tasks here.'
                  : 'Try selecting a different tab or removing your search filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(LearningStatus status) {
    switch (status) {
      case LearningStatus.pending:
        return Colors.orange;
      case LearningStatus.inProgress:
        return Colors.blue;
      case LearningStatus.completed:
        return Colors.green;
    }
  }

  IconData _iconForType(EduFileType type) {
    switch (type) {
      case EduFileType.pdf:
        return Icons.picture_as_pdf;
      case EduFileType.doc:
        return Icons.description;
      case EduFileType.presentation:
        return Icons.slideshow;
      case EduFileType.video:
        return Icons.video_library;
      case EduFileType.image:
        return Icons.image;
      case EduFileType.url:
        return Icons.language;
    }
  }

  Color _colorForType(ThemeData theme, EduFileType type) {
    switch (type) {
      case EduFileType.pdf:
        return Colors.red;
      case EduFileType.doc:
        return Colors.blue;
      case EduFileType.presentation:
        return Colors.orange;
      case EduFileType.video:
        return Colors.purple;
      case EduFileType.image:
        return Colors.teal;
      case EduFileType.url:
        return theme.colorScheme.primary;
    }
  }
}
