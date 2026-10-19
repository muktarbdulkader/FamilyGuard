import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/educational_material_model.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/services/education_service.dart';
import '../widgets/material_detail_sheet.dart';
import '../widgets/upload_material_sheet.dart';
import '../../../../l10n/app_localizations.dart';

class ParentEducationScreen extends ConsumerStatefulWidget {
  const ParentEducationScreen({super.key});

  @override
  ConsumerState<ParentEducationScreen> createState() =>
      _ParentEducationScreenState();
}

class _ParentEducationScreenState extends ConsumerState<ParentEducationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSubject = 'All';
  String _selectedType = 'All';
  String _selectedChildId = 'All';
  String _selectedStatus = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserDataProvider);
    final selectedFamily = ref.watch(selectedFamilyProvider);
    final childrenAsync = ref.watch(familyChildrenProvider);

    final user = userAsync.value;
    final familyId = selectedFamily?.id ?? user?.familyId ?? '';
    final children = childrenAsync.value ?? [];

    final materialsAsync = familyId.isNotEmpty
        ? ref.watch(familyEducationalMaterialsProvider(familyId))
        : const AsyncValue<List<EducationalMaterial>>.data([]);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.educationCenter,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              l10n.manageLearningMaterials,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
            onPressed: () {
              if (familyId.isNotEmpty) {
                ref.invalidate(familyEducationalMaterialsProvider(familyId));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUploadSheet(
          context,
          familyId,
          user?.uid ?? '',
          user?.displayName ?? 'Parent',
        ),
        icon: const Icon(Icons.add),
        label: Text(
          l10n.uploadMaterial,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: materialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Failed to load materials',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(
                    familyEducationalMaterialsProvider(familyId),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (allMaterials) {
          final filtered = _filterMaterials(allMaterials);

          return CustomScrollView(
            slivers: [
              // Statistics Overview
              SliverToBoxAdapter(child: _buildStatsHeader(theme, allMaterials)),

              // Search Bar & Filter Controls
              SliverToBoxAdapter(child: _buildFilterSection(theme, children)),

              // Active Filters indicator
              if (_hasActiveFilters)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Showing ${filtered.length} of ${allMaterials.length} materials',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _resetFilters,
                          child: const Text(
                            'Clear Filters',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Materials List or Empty State
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    theme,
                    allMaterials.isEmpty,
                    familyId,
                    user?.uid ?? '',
                    user?.displayName ?? 'Parent',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final material = filtered[index];
                      return _buildMaterialCard(
                        theme,
                        material,
                        familyId,
                        children,
                      );
                    }, childCount: filtered.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedSubject != 'All' ||
      _selectedType != 'All' ||
      _selectedChildId != 'All' ||
      _selectedStatus != 'All';

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSubject = 'All';
      _selectedType = 'All';
      _selectedChildId = 'All';
      _selectedStatus = 'All';
    });
  }

  void _openUploadSheet(
    BuildContext context,
    String familyId,
    String parentId,
    String parentName,
  ) {
    if (familyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a family first')),
      );
      return;
    }
    UploadMaterialSheet.show(
      context,
      familyId: familyId,
      parentId: parentId,
      parentName: parentName,
    );
  }

  List<EducationalMaterial> _filterMaterials(List<EducationalMaterial> list) {
    return list.where((m) {
      // Search text
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = m.title.toLowerCase().contains(q);
        final matchesDesc = m.description.toLowerCase().contains(q);
        final matchesSubject = m.subject.toLowerCase().contains(q);
        final matchesGrade = m.gradeLevel.toLowerCase().contains(q);
        if (!matchesTitle && !matchesDesc && !matchesSubject && !matchesGrade) {
          return false;
        }
      }

      // Subject filter
      if (_selectedSubject != 'All' && m.subject != _selectedSubject) {
        return false;
      }

      // Type filter
      if (_selectedType != 'All' && m.type.badgeLabel != _selectedType) {
        return false;
      }

      // Child filter
      if (_selectedChildId != 'All' &&
          !m.assignedChildIds.contains(_selectedChildId)) {
        return false;
      }

      // Status filter
      if (_selectedStatus != 'All') {
        if (_selectedStatus == 'Completed' && m.completionRate < 1.0) {
          return false;
        }
        if (_selectedStatus == 'In Progress' &&
            (m.completionRate == 0 || m.completionRate >= 1.0)) {
          return false;
        }
        if (_selectedStatus == 'Pending' && m.completionRate > 0) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildStatsHeader(
    ThemeData theme,
    List<EducationalMaterial> materials,
  ) {
    final total = materials.length;
    final totalAssignments = materials.fold<int>(
      0,
      (sum, m) => sum + m.assignedChildIds.length,
    );
    final completedAssignments = materials.fold<int>(
      0,
      (sum, m) =>
          sum +
          m.childProgress.values
              .where((p) => p.status == LearningStatus.completed)
              .length,
    );
    final overallRate = totalAssignments > 0
        ? (completedAssignments / totalAssignments * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.7),
            theme.colorScheme.tertiaryContainer.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Learning Overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  theme,
                  label: 'Materials',
                  value: '$total',
                  icon: Icons.library_books_outlined,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: _buildStatItem(
                  theme,
                  label: 'Assigned',
                  value: '$totalAssignments',
                  icon: Icons.people_outline,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: _buildStatItem(
                  theme,
                  label: 'Completed',
                  value: '$overallRate%',
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(ThemeData theme, List<ChildModel> children) {
    const subjects = [
      'All',
      'Mathematics',
      'Science',
      'English & Language Arts',
      'Social Studies & History',
      'Computer Science & Tech',
      'Art & Music',
      'General & Other',
    ];
    const types = [
      'All',
      'PDF',
      'Document',
      'Presentation',
      'Video',
      'Image',
      'URL',
    ];
    const statuses = ['All', 'Pending', 'In Progress', 'Completed'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search TextField
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by title, subject, grade...',
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
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(
                0.4,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
          const SizedBox(height: 10),

          // Horizontal scroll of Subject Filter Chips
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
          const SizedBox(height: 6),

          // File Type & Child Select Dropdowns / Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type Filter Chips
                ...types.map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: type == 'All'
                          ? null
                          : Icon(_typeIconForLabel(type), size: 14),
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          _selectedType = val ? type : 'All';
                        });
                      },
                    ),
                  );
                }),

                if (children.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  // Child Filter Menu
                  PopupMenuButton<String>(
                    initialValue: _selectedChildId,
                    onSelected: (val) {
                      setState(() {
                        _selectedChildId = val;
                      });
                    },
                    child: Chip(
                      avatar: const Icon(Icons.face, size: 16),
                      label: Text(
                        _selectedChildId == 'All'
                            ? 'All Children'
                            : (children
                                  .firstWhere(
                                    (c) => c.id == _selectedChildId,
                                    orElse: () => children.first,
                                  )
                                  .displayName),
                      ),
                      deleteIcon: _selectedChildId != 'All'
                          ? const Icon(Icons.close, size: 14)
                          : null,
                      onDeleted: _selectedChildId != 'All'
                          ? () => setState(() => _selectedChildId = 'All')
                          : null,
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'All',
                        child: Text('All Children'),
                      ),
                      ...children.map(
                        (c) => PopupMenuItem(
                          value: c.id,
                          child: Text(c.displayName),
                        ),
                      ),
                    ],
                  ),
                ],

                // Status Filter Menu
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  initialValue: _selectedStatus,
                  onSelected: (val) {
                    setState(() {
                      _selectedStatus = val;
                    });
                  },
                  child: Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      _selectedStatus == 'All'
                          ? 'Status: All'
                          : _selectedStatus,
                    ),
                    deleteIcon: _selectedStatus != 'All'
                        ? const Icon(Icons.close, size: 14)
                        : null,
                    onDeleted: _selectedStatus != 'All'
                        ? () => setState(() => _selectedStatus = 'All')
                        : null,
                  ),
                  itemBuilder: (ctx) => statuses
                      .map((s) => PopupMenuItem(value: s, child: Text(s)))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(
    ThemeData theme,
    EducationalMaterial material,
    String familyId,
    List<ChildModel> children,
  ) {
    final completionPercent = (material.completionRate * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => MaterialDetailSheet.show(
          context,
          material: material,
          familyId: familyId,
          children: children,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Icon, Title, Type, Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _colorForType(
                        theme,
                        material.type,
                      ).withOpacity(0.15),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                material.gradeLevel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                  const Icon(Icons.chevron_right, color: Colors.grey),
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

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Bottom Progress Bar & Details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          children: [
                            Text(
                              '${material.assignedChildIds.length} assigned',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(' • '),
                            Text(
                              '$completionPercent% completed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: completionPercent == 100
                                    ? Colors.green
                                    : (completionPercent > 0
                                          ? Colors.blue
                                          : Colors.orange),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: material.completionRate,
                            minHeight: 5,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completionPercent == 100
                                  ? Colors.green
                                  : (completionPercent > 0
                                        ? Colors.blue
                                        : Colors.orange),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (material.dueDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: material.isOverdue
                              ? Colors.red
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d').format(material.dueDate!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: material.isOverdue
                                ? Colors.red
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    bool isTotalEmpty,
    String familyId,
    String parentId,
    String parentName,
  ) {
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
                isTotalEmpty
                    ? Icons.school_outlined
                    : Icons.search_off_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTotalEmpty
                  ? 'No Educational Materials Yet'
                  : 'No Matching Materials',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTotalEmpty
                  ? 'Upload educational PDFs, documents, presentations, videos, and links to assign to your children.'
                  : 'Try adjusting your search query or removing some filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (isTotalEmpty)
              FilledButton.icon(
                onPressed: () =>
                    _openUploadSheet(context, familyId, parentId, parentName),
                icon: const Icon(Icons.add),
                label: const Text('Upload First Material'),
              )
            else
              FilledButton.tonal(
                onPressed: _resetFilters,
                child: const Text('Reset All Filters'),
              ),
          ],
        ),
      ),
    );
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

  IconData _typeIconForLabel(String label) {
    switch (label) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'Document':
        return Icons.description;
      case 'Presentation':
        return Icons.slideshow;
      case 'Video':
        return Icons.video_library;
      case 'Image':
        return Icons.image;
      case 'URL':
        return Icons.language;
      default:
        return Icons.insert_drive_file;
    }
  }
}
