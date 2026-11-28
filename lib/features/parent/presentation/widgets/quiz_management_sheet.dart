import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/educational_material_model.dart';
import '../../../../core/models/quiz_model.dart';
import '../../../../core/services/education_service.dart';
import '../../../../core/theme/app_colors.dart';

class QuizManagementSheet extends ConsumerWidget {
  final String familyId;
  final EducationalMaterial material;

  const QuizManagementSheet({
    super.key,
    required this.familyId,
    required this.material,
  });

  static Future<void> show(
    BuildContext context, {
    required String familyId,
    required EducationalMaterial material,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          QuizManagementSheet(familyId: familyId, material: material),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorsProvider);
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.quiz_rounded,
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lesson Quizzes',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            material.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.heroBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.heroBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Children earn bonus screen time automatically when they pass a quiz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<QuizModel>>(
                    stream: ref
                        .read(educationServiceProvider)
                        .getQuizzesStream(familyId, material.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load quizzes: ${snapshot.error}',
                            style: TextStyle(color: colors.error),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: colors.primary,
                          ),
                        );
                      }
                      final quizzes = snapshot.data!;
                      if (quizzes.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  size: 52,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No quizzes for this lesson yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create a short multiple-choice quiz to test understanding and reward your child.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: quizzes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final quiz = quizzes[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.quiz_outlined,
                                    color: colors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quiz.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _QuizMetaChip(
                                            label:
                                                '${quiz.questions.length} Qs',
                                            color: colors.info,
                                          ),
                                          _QuizMetaChip(
                                            label:
                                                'Pass ${quiz.passingScorePercent}%',
                                            color: colors.warning,
                                          ),
                                          _QuizMetaChip(
                                            label:
                                                '+${quiz.rewardExtraScreenTimeMinutes}m reward',
                                            color: colors.success,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete quiz',
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colors.error,
                                  ),
                                  onPressed: () =>
                                      _deleteQuiz(context, ref, quiz),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _createQuiz(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Create Quiz',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Future<void> _createQuiz(BuildContext context, WidgetRef ref) async {
    final quiz = await showModalBottomSheet<QuizModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QuizAuthoringSheet(),
    );
    if (quiz == null || !context.mounted) return;
    try {
      await ref
          .read(educationServiceProvider)
          .createQuiz(
            familyId: familyId,
            quiz: QuizModel(
              id: '',
              materialId: material.id,
              familyId: familyId,
              title: quiz.title,
              description: quiz.description,
              questions: quiz.questions,
              passingScorePercent: quiz.passingScorePercent,
              rewardExtraScreenTimeMinutes: quiz.rewardExtraScreenTimeMinutes,
              createdAt: DateTime.now(),
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quiz created!')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create quiz: $error')),
        );
      }
    }
  }

  Future<void> _deleteQuiz(
    BuildContext context,
    WidgetRef ref,
    QuizModel quiz,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete quiz?'),
        content: Text('Delete "${quiz.title}" and its private answer key?'),
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
    if (shouldDelete != true || !context.mounted) return;
    try {
      await ref
          .read(educationServiceProvider)
          .deleteQuiz(
            familyId: familyId,
            materialId: material.id,
            quizId: quiz.id,
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete quiz: $error')),
        );
      }
    }
  }
}

class _QuizMetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _QuizMetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _QuizAuthoringSheet extends ConsumerStatefulWidget {
  const _QuizAuthoringSheet();

  @override
  ConsumerState<_QuizAuthoringSheet> createState() =>
      _QuizAuthoringSheetState();
}

class _QuizAuthoringSheetState extends ConsumerState<_QuizAuthoringSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passingScoreController = TextEditingController(text: '70');
  final _rewardController = TextEditingController(text: '30');
  final List<_QuestionDraft> _questions = [_QuestionDraft()];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _passingScoreController.dispose();
    _rewardController.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorsProvider);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.86,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create Lesson Quiz',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Quiz title',
                            hintText: 'e.g., Chapter 1 Check',
                            border: OutlineInputBorder(),
                          ),
                          validator: _requiredText,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _passingScoreController,
                                decoration: const InputDecoration(
                                  labelText: 'Passing score (%)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    _boundedNumber(value, 0, 100),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _rewardController,
                                decoration: const InputDecoration(
                                  labelText: 'Reward minutes',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    _boundedNumber(value, 0, 240),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (
                          var index = 0;
                          index < _questions.length;
                          index++
                        )
                          _buildQuestionEditor(index, colors),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _questions.length >= 50
                              ? null
                              : () => setState(
                                  () => _questions.add(_QuestionDraft()),
                                ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add question'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _saveQuiz,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Quiz',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionEditor(int index, AppColors colors) {
    final draft = _questions[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (_questions.length > 1)
                IconButton(
                  tooltip: 'Remove question',
                  onPressed: () {
                    setState(() {
                      _questions.removeAt(index).dispose();
                    });
                  },
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    color: colors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: draft.question,
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: _requiredText,
          ),
          for (var option = 0; option < draft.options.length; option++) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: draft.options[option],
              decoration: InputDecoration(
                labelText: 'Option ${option + 1}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: _requiredText,
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: draft.correctOptionIndex,
            decoration: const InputDecoration(
              labelText: 'Correct option',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(
              draft.options.length,
              (option) => DropdownMenuItem(
                value: option,
                child: Text('Option ${option + 1}'),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => draft.correctOptionIndex = value);
              }
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: draft.explanation,
            decoration: const InputDecoration(
              labelText: 'Explanation (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _boundedNumber(String? value, int min, int max) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < min || number > max) {
      return 'Enter a value from $min to $max';
    }
    return null;
  }

  void _saveQuiz() {
    if (!_formKey.currentState!.validate()) return;
    final questions = <QuizQuestion>[];
    for (var index = 0; index < _questions.length; index++) {
      final draft = _questions[index];
      questions.add(
        QuizQuestion(
          id: '$index',
          questionText: draft.question.text.trim(),
          options: draft.options.map((option) => option.text.trim()).toList(),
          correctOptionIndex: draft.correctOptionIndex,
          explanation: draft.explanation.text.trim().isEmpty
              ? null
              : draft.explanation.text.trim(),
        ),
      );
    }
    Navigator.pop(
      context,
      QuizModel(
        id: '',
        materialId: '',
        familyId: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        questions: questions,
        passingScorePercent: int.parse(_passingScoreController.text),
        rewardExtraScreenTimeMinutes: int.parse(_rewardController.text),
        createdAt: DateTime.now(),
      ),
    );
  }
}

class _QuestionDraft {
  final question = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  final explanation = TextEditingController();
  int correctOptionIndex = 0;

  void dispose() {
    question.dispose();
    explanation.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}
