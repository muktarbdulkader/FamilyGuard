import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/models/educational_material_model.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/services/education_service.dart';

class UploadMaterialSheet extends ConsumerStatefulWidget {
  final String familyId;
  final String parentId;
  final String parentName;
  final EducationalMaterial? existingMaterial;
  final String? initialChildId;

  const UploadMaterialSheet({
    super.key,
    required this.familyId,
    required this.parentId,
    required this.parentName,
    this.existingMaterial,
    this.initialChildId,
  });

  static Future<void> show(
    BuildContext context, {
    required String familyId,
    required String parentId,
    required String parentName,
    EducationalMaterial? existingMaterial,
    String? initialChildId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UploadMaterialSheet(
        familyId: familyId,
        parentId: parentId,
        parentName: parentName,
        existingMaterial: existingMaterial,
        initialChildId: initialChildId,
      ),
    );
  }

  @override
  ConsumerState<UploadMaterialSheet> createState() =>
      _UploadMaterialSheetState();
}

class _UploadMaterialSheetState extends ConsumerState<UploadMaterialSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _urlController;
  late final TextEditingController _instructionsController;

  bool _isUrlMode = false;
  PlatformFile? _selectedFile;
  String _selectedSubject = 'Mathematics';
  String _selectedGrade = 'All Grades';
  DateTime? _selectedDueDate;
  final Set<String> _selectedChildIds = {};

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _statusMessage = '';

  static const List<String> _subjects = [
    'Mathematics',
    'Science',
    'English & Literature',
    'History',
    'Coding & Tech',
    'Art & Music',
    'Geography',
    'General',
  ];

  static const List<String> _gradeLevels = [
    'All Grades',
    'Grade 1 - 3 (Elementary)',
    'Grade 4 - 6 (Intermediate)',
    'Grade 7 - 8 (Middle School)',
    'Grade 9 - 12 (High School)',
  ];

  @override
  void initState() {
    super.initState();
    final mat = widget.existingMaterial;
    _titleController = TextEditingController(text: mat?.title ?? '');
    _descController = TextEditingController(text: mat?.description ?? '');
    _urlController = TextEditingController(
      text: mat?.materialType == EduFileType.url ? mat?.fileUrl : '',
    );
    _instructionsController = TextEditingController(
      text: mat?.instructions ?? '',
    );
    if (mat != null) {
      _selectedSubject = mat.subject;
      _selectedGrade = mat.gradeLevel;
      _selectedDueDate = mat.dueDate;
      _selectedChildIds.addAll(mat.assignedChildIds);
      _isUrlMode = mat.materialType == EduFileType.url;
    } else if (widget.initialChildId != null &&
        widget.initialChildId!.isNotEmpty) {
      _selectedChildIds.add(widget.initialChildId!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _urlController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'mp4',
          'jpg',
          'jpeg',
          'png',
        ],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          _isUrlMode = false;
          if (_titleController.text.trim().isEmpty) {
            final baseName = file.name.split('.').first;
            _titleController.text = baseName.replaceAll('_', ' ');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDueDate != null
            ? TimeOfDay.fromDateTime(_selectedDueDate!)
            : const TimeOfDay(hour: 18, minute: 0),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveMaterial(List<ChildModel> children) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isUrlMode &&
        _selectedFile == null &&
        widget.existingMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file to upload or enter a link.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isUrlMode && _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an educational URL.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedChildIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one child to assign this material to.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _statusMessage = 'Preparing material...';
    });

    try {
      final educationService = ref.read(educationServiceProvider);
      final materialId = widget.existingMaterial?.id ?? const Uuid().v4();

      String fileUrl = widget.existingMaterial?.fileUrl ?? '';
      String? storagePath = widget.existingMaterial?.storagePath;
      String? fileName = widget.existingMaterial?.fileName;
      int? fileSizeBytes = widget.existingMaterial?.fileSizeBytes;
      EduFileType matType;

      if (_isUrlMode) {
        fileUrl = _urlController.text.trim();
        matType = EduFileType.url;
      } else if (_selectedFile != null) {
        setState(() {
          _statusMessage = 'Uploading ${_selectedFile!.name} to cloud...';
        });

        final uploadResult = await educationService.uploadMaterialFile(
          familyId: widget.familyId,
          materialId: materialId,
          file: _selectedFile!,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );

        fileUrl = uploadResult.downloadUrl;
        storagePath = uploadResult.storagePath;
        fileName = uploadResult.fileName;
        fileSizeBytes = uploadResult.fileSizeBytes;
        matType = EduFileType.fromExtension(_selectedFile!.extension);
      } else {
        matType = widget.existingMaterial!.materialType;
      }

      setState(() {
        _statusMessage = 'Saving assignment...';
        _uploadProgress = 0.95;
      });

      // Map child names
      final childNames = <String, String>{};
      for (final child in children) {
        if (_selectedChildIds.contains(child.id)) {
          childNames[child.id] = child.displayName;
        }
      }

      final now = DateTime.now();
      final material = EducationalMaterial(
        id: materialId,
        familyId: widget.familyId,
        parentId: widget.parentId,
        parentName: widget.parentName,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        subject: _selectedSubject,
        gradeLevel: _selectedGrade,
        materialType: matType,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
        storagePath: storagePath,
        instructions: _instructionsController.text.trim().isNotEmpty
            ? _instructionsController.text.trim()
            : null,
        dueDate: _selectedDueDate,
        assignedChildIds: _selectedChildIds.toList(),
        assignedChildNames: childNames,
        createdAt: widget.existingMaterial?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.existingMaterial != null) {
        await educationService.updateMaterial(material);
      } else {
        await educationService.createMaterial(material);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingMaterial != null
                  ? 'Updated "${material.title}" successfully!'
                  : 'Assigned "${material.title}" to ${_selectedChildIds.length} child(ren)!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(familyChildrenProvider);
    final isEditing = widget.existingMaterial != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sheet Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Color(0xFF4F46E5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit Educational Material'
                                : 'Upload Educational Material',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Assign study content & lessons to your children',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Material Source Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isUploading
                              ? null
                              : () => setState(() => _isUrlMode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isUrlMode
                                  ? (isDark
                                        ? const Color(0xFF334155)
                                        : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_isUrlMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file_rounded,
                                  size: 16,
                                  color: Color(0xFF4F46E5),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'File from Device',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isUploading
                              ? null
                              : () => setState(() => _isUrlMode = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isUrlMode
                                  ? (isDark
                                        ? const Color(0xFF334155)
                                        : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _isUrlMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 16,
                                  color: Color(0xFF7C3AED),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Educational Link',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // File Picker / URL Box
                if (!_isUrlMode)
                  GestureDetector(
                    onTap: _isUploading ? null : _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedFile != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4F46E5).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedFile != null
                                ? Icons.check_circle_rounded
                                : Icons.cloud_upload_outlined,
                            size: 38,
                            color: _selectedFile != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF4F46E5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFile != null
                                ? _selectedFile!.name
                                : (widget.existingMaterial?.fileName ??
                                      'Tap to pick PDF, DOC, PPT, MP4, or Images'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedFile != null
                                ? '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Tap to replace'
                                : 'Supports PDF, Word, PowerPoint, MP4 Video, and Images',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Educational URL *',
                      hintText:
                          'https://youtube.com/watch?... or khanacademy.org/...',
                      prefixIcon: const Icon(
                        Icons.link_rounded,
                        color: Color(0xFF7C3AED),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      if (_isUrlMode && (v == null || v.trim().isEmpty)) {
                        return 'Please enter a valid link';
                      }
                      if (_isUrlMode && !v!.trim().startsWith('http')) {
                        return 'URL must start with http:// or https://';
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Material Title *',
                    hintText: 'e.g. Fractions & Decimals Chapter 3',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a title'
                      : null,
                ),
                const SizedBox(height: 14),

                // Keep dropdowns full-width so the decorator always has room
                // for its selected value, even on narrow devices.
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  selectedItemBuilder: (context) => _subjects
                      .map(
                        (subject) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  items: _subjects
                      .map(
                        (subject) => DropdownMenuItem(
                          value: subject,
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSubject = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedGrade,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Grade Level',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  selectedItemBuilder: (context) => _gradeLevels
                      .map(
                        (grade) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            grade,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  items: _gradeLevels
                      .map(
                        (grade) => DropdownMenuItem(
                          value: grade,
                          child: Text(
                            grade,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedGrade = value);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief summary of what this material covers...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Learning Instructions
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Learning Instructions (Optional)',
                    hintText:
                        'e.g. Watch video first, then complete practice sheet.',
                    prefixIcon: const Icon(
                      Icons.tips_and_updates_rounded,
                      color: Color(0xFFF59E0B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Due Date selector
                InkWell(
                  onTap: _selectDueDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Due Date (Optional)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _selectedDueDate != null
                                    ? DateFormat(
                                        'EEE, MMM d, yyyy • h:mm a',
                                      ).format(_selectedDueDate!)
                                    : 'No deadline set (study at own pace)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedDueDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _selectedDueDate = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Assign to Children
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assign to Children *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    childrenAsync.maybeWhen(
                      data: (children) => TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedChildIds.length == children.length) {
                              _selectedChildIds.clear();
                            } else {
                              _selectedChildIds.addAll(
                                children.map((c) => c.id),
                              );
                            }
                          });
                        },
                        child: Text(
                          _selectedChildIds.length ==
                                  childrenAsync.value?.length
                              ? 'Deselect All'
                              : 'Select All',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Children Chips
                childrenAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Error loading children: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                  data: (children) {
                    if (children.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No children linked to your family yet.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: children.map((child) {
                        final isSelected = _selectedChildIds.contains(child.id);
                        return FilterChip(
                          selected: isSelected,
                          avatar: CircleAvatar(
                            backgroundColor: isSelected
                                ? Colors.white
                                : const Color(0xFF4F46E5),
                            child: Text(
                              child.displayName.isNotEmpty
                                  ? child.displayName[0].toUpperCase()
                                  : 'C',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          label: Text(child.displayName),
                          selectedColor: const Color(0xFF4F46E5),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedChildIds.add(child.id);
                              } else {
                                _selectedChildIds.remove(child.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Upload Progress Bar
                if (_isUploading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF4F46E5),
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isUploading
                        ? null
                        : () => _saveMaterial(childrenAsync.value ?? []),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isUploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Saving Material...'),
                            ],
                          )
                        : Text(
                            isEditing
                                ? 'Save Changes'
                                : 'Assign to ${_selectedChildIds.length} Child(ren)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
