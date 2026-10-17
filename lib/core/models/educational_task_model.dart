import 'package:cloud_firestore/cloud_firestore.dart';

class EducationalTask {
  final String id;
  final String familyId;
  final String childId;
  final String title;
  final String subject;
  final String note;
  final String? url;
  final String senderName;
  final DateTime createdAt;
  final bool isCompleted;
  final DateTime? completedAt;

  const EducationalTask({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.title,
    this.subject = 'General',
    this.note = '',
    this.url,
    this.senderName = 'Parent',
    required this.createdAt,
    this.isCompleted = false,
    this.completedAt,
  });

  factory EducationalTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EducationalTask(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      title: data['title'] as String? ?? 'Educational Material',
      subject: data['subject'] as String? ?? 'General',
      note: data['note'] as String? ?? '',
      url: data['url'] as String?,
      senderName: data['senderName'] as String? ?? 'Parent',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyId': familyId,
      'childId': childId,
      'title': title,
      'subject': subject,
      'note': note,
      'url': url,
      'senderName': senderName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  EducationalTask copyWith({
    String? title,
    String? subject,
    String? note,
    String? url,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return EducationalTask(
      id: id,
      familyId: familyId,
      childId: childId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      note: note ?? this.note,
      url: url ?? this.url,
      senderName: senderName,
      createdAt: createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
