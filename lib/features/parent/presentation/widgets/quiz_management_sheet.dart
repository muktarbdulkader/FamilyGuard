import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/educational_material_model.dart';
import '../../../../core/models/quiz_model.dart';
import '../../../../core/services/education_service.dart';

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
      builder: (_) => QuizManagementSheet(
        familyId: familyId,
        material: material,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quizzes · ${material.title}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Create quiz',
                    onPressed: () => _createQuiz(context, ref),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<QuizModel>>(
                  stream: ref
                      .read(educationServiceProvider)
                      .getQuizzesStream(familyId, material.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Could not load quizzes: ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final quizzes = snapshot.data!;
                    if (quizzes.isEmpty) {
                      return const Center(
                        child: Text('No quizzes for this lesson yet.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: quizzes.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final quiz = quizzes[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.quiz_outlined),
                          ),
                          title: Text(quiz.title),
                          subtitle: Text(
                            '${quiz.questions.length} questions · Pass ${quiz.passingScorePercent}% · ${quiz.rewardExtraScreenTimeMinutes} min reward',
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete quiz',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteQuiz(context, ref, quiz),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _createQuiz(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Create quiz'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createQuiz(BuildContext context, WidgetRef ref) async {
    final quiz = await showDialog<QuizModel>(
      context: context,
      builder: (_) => const _QuizAuthoringDialog(),
    );
    if (quiz == null || !context.mounted) return;
    try {
      await ref.read(educationServiceProvider).createQuiz(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz created.')),
        );
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
      await ref.read(educationServiceProvider).deleteQuiz(
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

class _QuizAuthoringDialog extends StatefulWidget {
  const _QuizAuthoringDialog();

  @override
  State<_QuizAuthoringDialog> createState() => _QuizAuthoringDialogState();
}

class _QuizAuthoringDialogState extends State<_QuizAuthoringDialog> {
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
    return AlertDialog(
      title: const Text('Create lesson quiz'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Quiz title'),
                validator: _requiredText,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _passingScoreController,
                      decoration: const InputDecoration(
                        labelText: 'Passing score (%)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => _boundedNumber(value, 0, 100),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rewardController,
                      decoration: const InputDecoration(
                        labelText: 'Reward minutes',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => _boundedNumber(value, 0, 240),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < _questions.length; index++)
                _buildQuestionEditor(index),
              TextButton.icon(
                onPressed: _questions.length >= 50
                    ? null
                    : () => setState(() => _questions.add(_QuestionDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveQuiz,
          child: const Text('Save quiz'),
        ),
      ],
    );
  }

  Widget _buildQuestionEditor(int index) {
    final draft = _questions[index];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
            TextFormField(
              controller: draft.question,
              decoration: const InputDecoration(labelText: 'Question'),
              validator: _requiredText,
            ),
            for (var option = 0; option < draft.options.length; option++)
              TextFormField(
                controller: draft.options[option],
                decoration: InputDecoration(labelText: 'Option ${option + 1}'),
                validator: _requiredText,
              ),
            DropdownButtonFormField<int>(
              value: draft.correctOptionIndex,
              decoration: const InputDecoration(labelText: 'Correct option'),
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
            TextFormField(
              controller: draft.explanation,
              decoration: const InputDecoration(
                labelText: 'Explanation (optional)',
              ),
            ),
          ],
        ),
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
