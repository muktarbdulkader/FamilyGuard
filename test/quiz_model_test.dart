import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_study_app/core/models/quiz_model.dart';

void main() {
  test('public quiz data does not contain answer keys or explanations', () {
    final quiz = QuizModel(
      id: 'quiz',
      materialId: 'material',
      familyId: 'family',
      title: 'Lesson check',
      questions: const [
        QuizQuestion(
          id: '0',
          questionText: 'Which is correct?',
          options: ['A', 'B'],
          correctOptionIndex: 1,
          explanation: 'B is correct.',
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
    );

    final publicQuestion =
        (quiz.toFirestore()['questions'] as List).single as Map;
    final privateAnswers =
        (quiz.toAnswerKeyFirestore()['answers'] as List).single as Map;

    expect(publicQuestion.containsKey('correctOptionIndex'), isFalse);
    expect(publicQuestion.containsKey('explanation'), isFalse);
    expect(privateAnswers['correctOptionIndex'], 1);
    expect(privateAnswers['explanation'], 'B is correct.');
  });

  test('parsing public quiz questions leaves answer undisclosed', () {
    final question = QuizQuestion.fromMap({
      'id': '0',
      'questionText': 'Which is correct?',
      'options': ['A', 'B'],
    });

    expect(question.correctOptionIndex, -1);
    expect(question.explanation, isNull);
  });
}
