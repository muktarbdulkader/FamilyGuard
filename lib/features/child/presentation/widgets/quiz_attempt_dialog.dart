import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/quiz_model.dart';
import '../../../../core/services/education_service.dart';

class QuizAttemptDialog extends ConsumerStatefulWidget {
  final String familyId;
  final String childId;
  final String childName;
  final QuizModel quiz;

  const QuizAttemptDialog({
    super.key,
    required this.familyId,
    required this.childId,
    required this.childName,
    required this.quiz,
  });

  static Future<QuizAttempt?> show(
    BuildContext context, {
    required String familyId,
    required String childId,
    required String childName,
    required QuizModel quiz,
  }) {
    return showDialog<QuizAttempt>(
      context: context,
      builder: (_) => QuizAttemptDialog(
        familyId: familyId,
        childId: childId,
        childName: childName,
        quiz: quiz,
      ),
    );
  }

  @override
  ConsumerState<QuizAttemptDialog> createState() => _QuizAttemptDialogState();
}

class _QuizAttemptDialogState extends ConsumerState<QuizAttemptDialog> {
  final Map<int, int> _answers = {};
  bool _isSubmitting = false;
  String? _error;
  QuizAttempt? _result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_result == null ? widget.quiz.title : 'Quiz results'),
      content: SizedBox(
        width: 520,
        child: _result == null
            ? ListView(
                shrinkWrap: true,
                children: [
                  if (widget.quiz.description?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        widget.quiz.description!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  for (var index = 0;
                      index < widget.quiz.questions.length;
                      index++)
                    _buildQuestion(index, widget.quiz.questions[index]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              )
            : _buildResult(theme),
      ),
      actions: _result == null
          ? [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit answers'),
              ),
            ]
          : [
              FilledButton(
                onPressed: () => Navigator.pop(context, _result),
                child: const Text('Done'),
              ),
            ],
    );
  }

  Widget _buildQuestion(int index, QuizQuestion question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${question.questionText}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (var option = 0; option < question.options.length; option++)
              RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(question.options[option]),
                value: option,
                groupValue: _answers[index],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _answers[index] = value;
                            _error = null;
                          });
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    final result = _result!;
    final passed = result.isPassed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          passed ? Icons.celebration_rounded : Icons.menu_book_rounded,
          size: 52,
          color: passed ? Colors.green : theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          '${result.scorePercent}%',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: passed ? Colors.green : theme.colorScheme.primary,
          ),
        ),
        Text('${result.correctCount} of ${result.totalQuestions} correct'),
        const SizedBox(height: 8),
        Text(
          passed
              ? 'You passed this quiz!'
              : 'Keep practicing and try again.',
          textAlign: TextAlign.center,
        ),
        if (result.rewardClaimed) ...[
          const SizedBox(height: 8),
          Text(
            'You earned ${widget.quiz.rewardExtraScreenTimeMinutes} extra screen-time minutes.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  Future<void> _submit() async {
    if (_answers.length != widget.quiz.questions.length) {
      setState(() => _error = 'Answer every question before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(educationServiceProvider).submitQuizAttempt(
            familyId: widget.familyId,
            quiz: widget.quiz,
            childId: widget.childId,
            childName: widget.childName,
            selectedAnswers: Map<int, int>.of(_answers),
          );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not submit quiz: $error');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
