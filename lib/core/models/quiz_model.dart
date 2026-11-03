import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return QuizQuestion(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      questionText: (map['questionText'] as String?) ?? (map['question'] as String?) ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: (map['correctOptionIndex'] as num?)?.toInt() ?? -1,
      explanation: map['explanation'] as String?,
    );
  }

  Map<String, dynamic> toPublicMap() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
    };
  }

  Map<String, dynamic> toAnswerMap() {
    return {
      'correctOptionIndex': correctOptionIndex,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

class QuizModel {
  final String id;
  final String materialId;
  final String familyId;
  final String title;
  final String? description;
  final List<QuizQuestion> questions;
  final int passingScorePercent;
  final int rewardExtraScreenTimeMinutes;
  final DateTime createdAt;

  const QuizModel({
    required this.id,
    required this.materialId,
    required this.familyId,
    required this.title,
    this.description,
    required this.questions,
    this.passingScorePercent = 70,
    this.rewardExtraScreenTimeMinutes = 30,
    required this.createdAt,
  });

  factory QuizModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawQuestions = (data['questions'] as List<dynamic>?) ?? [];
    final questions = rawQuestions
        .asMap()
        .entries
        .map((e) => QuizQuestion.fromMap(Map<String, dynamic>.from(e.value as Map), id: e.key.toString()))
        .toList();

    return QuizModel(
      id: doc.id,
      materialId: data['materialId'] as String? ?? '',
      familyId: data['familyId'] as String? ?? '',
      title: data['title'] as String? ?? 'Lesson Quiz',
      description: data['description'] as String?,
      questions: questions,
      passingScorePercent: (data['passingScorePercent'] as num?)?.toInt() ?? 70,
      rewardExtraScreenTimeMinutes: (data['rewardExtraScreenTimeMinutes'] as num?)?.toInt() ?? 30,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'materialId': materialId,
      'familyId': familyId,
      'title': title,
      if (description != null) 'description': description,
      'questions': questions.map((q) => q.toPublicMap()).toList(),
      'passingScorePercent': passingScorePercent,
      'rewardExtraScreenTimeMinutes': rewardExtraScreenTimeMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toAnswerKeyFirestore() {
    return {
      'answers': questions.map((question) => question.toAnswerMap()).toList(),
    };
  }
}

class QuizAttempt {
  final String id;
  final String quizId;
  final String materialId;
  final String childId;
  final String childName;
  final int scorePercent;
  final int correctCount;
  final int totalQuestions;
  final bool isPassed;
  final bool rewardClaimed;
  final DateTime completedAt;
  final Map<int, int> selectedAnswers;

  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.materialId,
    required this.childId,
    required this.childName,
    required this.scorePercent,
    required this.correctCount,
    required this.totalQuestions,
    required this.isPassed,
    this.rewardClaimed = false,
    required this.completedAt,
    this.selectedAnswers = const {},
  });

  factory QuizAttempt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawAnswers = data['selectedAnswers'] as Map<dynamic, dynamic>? ?? {};
    final answers = <int, int>{};
    rawAnswers.forEach((k, v) {
      final keyInt = int.tryParse(k.toString());
      final valInt = int.tryParse(v.toString());
      if (keyInt != null && valInt != null) {
        answers[keyInt] = valInt;
      }
    });

    return QuizAttempt(
      id: doc.id,
      quizId: data['quizId'] as String? ?? '',
      materialId: data['materialId'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      childName: data['childName'] as String? ?? 'Child',
      scorePercent: (data['scorePercent'] as num?)?.toInt() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (data['totalQuestions'] as num?)?.toInt() ?? 0,
      isPassed: data['isPassed'] as bool? ?? false,
      rewardClaimed: data['rewardClaimed'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      selectedAnswers: answers,
    );
  }

  Map<String, dynamic> toFirestore() {
    final ansMap = <String, int>{};
    selectedAnswers.forEach((k, v) => ansMap[k.toString()] = v);

    return {
      'quizId': quizId,
      'materialId': materialId,
      'childId': childId,
      'childName': childName,
      'scorePercent': scorePercent,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'isPassed': isPassed,
      'rewardClaimed': rewardClaimed,
      'completedAt': Timestamp.fromDate(completedAt),
      'selectedAnswers': ansMap,
    };
  }
}

class ChildLearningStreak {
  final int currentStreakDays;
  final DateTime? lastPassedDate;
  final List<String> badges;

  const ChildLearningStreak({
    this.currentStreakDays = 0,
    this.lastPassedDate,
    this.badges = const [],
  });

  factory ChildLearningStreak.fromMap(Map<String, dynamic> data) {
    return ChildLearningStreak(
      currentStreakDays: (data['currentStreakDays'] as num?)?.toInt() ?? 0,
      lastPassedDate: (data['lastPassedDate'] as Timestamp?)?.toDate(),
      badges: List<String>.from(data['badges'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreakDays': currentStreakDays,
      if (lastPassedDate != null) 'lastPassedDate': Timestamp.fromDate(lastPassedDate!),
      'badges': badges,
    };
  }
}
