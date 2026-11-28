import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/quiz_model.dart';
import '../../../../core/services/education_service.dart';
import '../../../../core/theme/app_colors.dart';

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
    final colors = ref.watch(appColorsProvider);
    final theme = Theme.of(context);
    final totalQuestions = widget.quiz.questions.length;
    final answeredCount = _answers.length;
    final progress = totalQuestions == 0 ? 0.0 : answeredCount / totalQuestions;

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _result == null
                          ? Icons.quiz_rounded
                          : (_result!.isPassed
                                ? Icons.celebration_rounded
                                : Icons.menu_book_rounded),
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
                          _result == null ? widget.quiz.title : 'Quiz Results',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (_result == null)
                          Text(
                            '$answeredCount of $totalQuestions answered · Pass ${widget.quiz.passingScorePercent}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context, _result),
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  ),
                ],
              ),

              if (_result == null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
                if (widget.quiz.rewardExtraScreenTimeMinutes > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: colors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pass to earn +${widget.quiz.rewardExtraScreenTimeMinutes} min screen time',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (widget.quiz.description?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            widget.quiz.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      for (
                        var index = 0;
                        index < widget.quiz.questions.length;
                        index++
                      )
                        _buildQuestion(
                          index,
                          widget.quiz.questions[index],
                          colors,
                        ),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Answers',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 16),
                _buildResult(theme, colors),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _result),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(
    int index,
    QuizQuestion question,
    AppColors colors,
  ) {
    final selected = _answers[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected != null
              ? colors.primary.withOpacity(0.5)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${question.questionText}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var option = 0; option < question.options.length; option++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _answers[index] = option;
                          _error = null;
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected == option
                        ? colors.primary.withOpacity(0.14)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == option
                          ? colors.primary
                          : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected == option
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: selected == option
                            ? colors.primary
                            : colors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          question.options[option],
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: selected == option
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme, AppColors colors) {
    final result = _result!;
    final passed = result.isPassed;
    final accent = passed ? colors.success : colors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.celebration_rounded : Icons.menu_book_rounded,
            size: 54,
            color: accent,
          ),
          const SizedBox(height: 12),
          Text(
            '${result.scorePercent}%',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.correctCount} of ${result.totalQuestions} correct',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            passed ? 'You passed this quiz!' : 'Keep practicing and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (result.rewardClaimed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.success.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'You earned +${widget.quiz.rewardExtraScreenTimeMinutes} extra screen-time minutes!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.success,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ],
      ),
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
      final result = await ref
          .read(educationServiceProvider)
          .submitQuizAttempt(
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
