import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/firestore_parsers.dart';
import '../utils/formatters.dart';

enum RoutineTemplate {
  study,
  dinner,
  bedtime,
  play,
  custom;

  String get displayName => switch (this) {
    RoutineTemplate.study => 'Study & Focus',
    RoutineTemplate.dinner => 'Family Dinner',
    RoutineTemplate.bedtime => 'Bedtime Routine',
    RoutineTemplate.play => 'Free Play Time',
    RoutineTemplate.custom => 'Custom Routine',
  };

  IconData get icon => switch (this) {
    RoutineTemplate.study => Icons.menu_book_rounded,
    RoutineTemplate.dinner => Icons.restaurant_rounded,
    RoutineTemplate.bedtime => Icons.nights_stay_rounded,
    RoutineTemplate.play => Icons.sports_esports_rounded,
    RoutineTemplate.custom => Icons.schedule_rounded,
  };

  Color get color => switch (this) {
    RoutineTemplate.study => const Color(0xFF2DD4BF),
    RoutineTemplate.dinner => const Color(0xFFF59E0B),
    RoutineTemplate.bedtime => const Color(0xFF6366F1),
    RoutineTemplate.play => const Color(0xFFEC4899),
    RoutineTemplate.custom => const Color(0xFF3B82F6),
  };

  static RoutineTemplate fromString(String? type) {
    return switch ((type ?? '').toLowerCase()) {
      'study' => RoutineTemplate.study,
      'dinner' => RoutineTemplate.dinner,
      'bedtime' => RoutineTemplate.bedtime,
      'play' => RoutineTemplate.play,
      _ => RoutineTemplate.custom,
    };
  }
}

class RoutineModel {
  final String id;
  final String familyId;
  final String childId;
  final String name;
  final RoutineTemplate templateType;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<int> daysOfWeek; // 1=Mon, 7=Sun
  final bool isActive;
  final String? description;
  final List<String> allowedCategories;
  final List<String> blockedCategories;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoutineModel({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.name,
    this.templateType = RoutineTemplate.custom,
    required this.startTime,
    required this.endTime,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.isActive = true,
    this.description,
    this.allowedCategories = const [],
    this.blockedCategories = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;

  /// Check if routine is currently active right now
  bool isCurrentlyActive({DateTime? nowTime}) {
    if (!isActive) return false;
    final now = nowTime ?? DateTime.now();
    final currentMins = now.hour * 60 + now.minute;
    if (startMinutes < endMinutes) {
      return daysOfWeek.contains(now.weekday) &&
          currentMins >= startMinutes &&
          currentMins < endMinutes;
    }

    if (currentMins >= startMinutes) {
      return daysOfWeek.contains(now.weekday);
    }
    if (currentMins < endMinutes) {
      final previousDay = now.weekday == DateTime.monday
          ? DateTime.sunday
          : now.weekday - 1;
      return daysOfWeek.contains(previousDay);
    }
    return false;
  }

  /// Minutes until this routine starts
  int minutesUntilStart({DateTime? nowTime}) {
    final now = nowTime ?? DateTime.now();
    final currentMins = now.hour * 60 + now.minute;
    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = now.add(Duration(days: dayOffset)).weekday;
      if (!daysOfWeek.contains(day)) continue;
      final minutesUntil = dayOffset * 1440 + startMinutes - currentMins;
      if (minutesUntil >= 0) return minutesUntil;
    }
    return 9999;
  }

  /// Conflict detector: check if this routine overlaps with another on any common day
  static List<String> findConflicts(
    RoutineModel candidate,
    List<RoutineModel> existingRoutines,
  ) {
    final conflicts = <String>[];
    if (!candidate.isActive) return conflicts;

    for (final other in existingRoutines) {
      if (other.id == candidate.id || !other.isActive) continue;

      final candidateIntervals = _weeklyIntervals(candidate);
      final otherIntervals = _weeklyIntervals(other);
      var overlaps = false;
      for (final candidateInterval in candidateIntervals) {
        for (final otherInterval in otherIntervals) {
          for (final weekOffset in const [-10080, 0, 10080]) {
            final otherStart = otherInterval.$1 + weekOffset;
            final otherEnd = otherInterval.$2 + weekOffset;
            if (candidateInterval.$1 < otherEnd &&
                candidateInterval.$2 > otherStart) {
              overlaps = true;
              break;
            }
          }
          if (overlaps) break;
        }
        if (overlaps) break;
      }
      if (overlaps) {
        final timeStr =
            '${AppFormatters.formatTimeOfDayAmPm(other.startTime)} - ${AppFormatters.formatTimeOfDayAmPm(other.endTime)}';
        conflicts.add('Overlaps with "${other.name}" ($timeStr)');
      }
    }

    return conflicts;
  }

  static List<(int, int)> _weeklyIntervals(RoutineModel routine) {
    const minutesPerWeek = 7 * 24 * 60;
    final duration = routine.endMinutes > routine.startMinutes
        ? routine.endMinutes - routine.startMinutes
        : routine.endMinutes - routine.startMinutes + 24 * 60;
    final intervals = <(int, int)>[];
    for (final day in routine.daysOfWeek) {
      final start = (day - 1) * 24 * 60 + routine.startMinutes;
      final end = start + duration;
      intervals.add((start, end));
      if (end > minutesPerWeek) {
        intervals.add((start - minutesPerWeek, end - minutesPerWeek));
      }
    }
    return intervals;
  }

  factory RoutineModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return RoutineModel(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      name: data['name'] as String? ?? 'Routine',
      templateType: RoutineTemplate.fromString(data['templateType'] as String?),
      startTime: FirestoreParsers.parseTimeOfDay(
        data['startTime'],
        fallback: const TimeOfDay(hour: 8, minute: 0),
      ),
      endTime: FirestoreParsers.parseTimeOfDay(
        data['endTime'],
        fallback: const TimeOfDay(hour: 9, minute: 0),
      ),
      daysOfWeek: List<int>.from(data['daysOfWeek'] ?? [1, 2, 3, 4, 5, 6, 7]),
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String?,
      allowedCategories: List<String>.from(data['allowedCategories'] ?? []),
      blockedCategories: List<String>.from(data['blockedCategories'] ?? []),
      createdAt: FirestoreParsers.parseDateTime(data['createdAt']),
      updatedAt: FirestoreParsers.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'childId': childId,
      'name': name,
      'templateType': templateType.name,
      'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
      'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
      'daysOfWeek': daysOfWeek,
      'isActive': isActive,
      if (description != null) 'description': description,
      'allowedCategories': allowedCategories,
      'blockedCategories': blockedCategories,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RoutineModel copyWith({
    String? name,
    RoutineTemplate? templateType,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<int>? daysOfWeek,
    bool? isActive,
    String? description,
    List<String>? allowedCategories,
    List<String>? blockedCategories,
  }) {
    return RoutineModel(
      id: id,
      familyId: familyId,
      childId: childId,
      name: name ?? this.name,
      templateType: templateType ?? this.templateType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      allowedCategories: allowedCategories ?? this.allowedCategories,
      blockedCategories: blockedCategories ?? this.blockedCategories,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
