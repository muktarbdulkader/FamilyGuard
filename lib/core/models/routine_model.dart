import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    if (!daysOfWeek.contains(now.weekday)) return false;

    final currentMins = now.hour * 60 + now.minute;
    if (startMinutes <= endMinutes) {
      return currentMins >= startMinutes && currentMins <= endMinutes;
    } else {
      // Overnight routine (e.g. 21:00 to 07:00)
      return currentMins >= startMinutes || currentMins <= endMinutes;
    }
  }

  /// Minutes until this routine starts
  int minutesUntilStart({DateTime? nowTime}) {
    final now = nowTime ?? DateTime.now();
    if (!daysOfWeek.contains(now.weekday)) return 9999;
    final currentMins = now.hour * 60 + now.minute;
    if (startMinutes > currentMins) {
      return startMinutes - currentMins;
    }
    return 9999;
  }

  /// Conflict detector: check if this routine overlaps with another on any common day
  static List<String> findConflicts(RoutineModel candidate, List<RoutineModel> existingRoutines) {
    final conflicts = <String>[];
    if (!candidate.isActive) return conflicts;

    for (final other in existingRoutines) {
      if (other.id == candidate.id || !other.isActive) continue;

      // Check common days
      final commonDays = candidate.daysOfWeek.where((d) => other.daysOfWeek.contains(d)).toList();
      if (commonDays.isEmpty) continue;

      // Check time overlap
      final cStart = candidate.startMinutes;
      final cEnd = candidate.endMinutes > candidate.startMinutes
          ? candidate.endMinutes
          : candidate.endMinutes + 1440;

      final oStart = other.startMinutes;
      final oEnd = other.endMinutes > other.startMinutes
          ? other.endMinutes
          : other.endMinutes + 1440;

      final overlaps = (cStart < oEnd && cEnd > oStart);
      if (overlaps) {
        final dayNames = commonDays.map(_dayName).join(', ');
        final timeStr = '${_fmt(other.startTime)} - ${_fmt(other.endTime)}';
        conflicts.add('Overlaps with "${other.name}" on $dayNames ($timeStr)');
      }
    }

    return conflicts;
  }

  static String _dayName(int d) => switch (d) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        7 => 'Sun',
        _ => '',
      };

  static String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  factory RoutineModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    TimeOfDay parseTime(Map<String, dynamic>? map, TimeOfDay fallback) {
      if (map == null) return fallback;
      return TimeOfDay(
        hour: (map['hour'] as num?)?.toInt() ?? fallback.hour,
        minute: (map['minute'] as num?)?.toInt() ?? fallback.minute,
      );
    }

    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return RoutineModel(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      childId: data['childId'] as String? ?? '',
      name: data['name'] as String? ?? 'Routine',
      templateType: RoutineTemplate.fromString(data['templateType'] as String?),
      startTime: parseTime(data['startTime'] as Map<String, dynamic>?, const TimeOfDay(hour: 8, minute: 0)),
      endTime: parseTime(data['endTime'] as Map<String, dynamic>?, const TimeOfDay(hour: 9, minute: 0)),
      daysOfWeek: List<int>.from(data['daysOfWeek'] ?? [1, 2, 3, 4, 5, 6, 7]),
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String?,
      allowedCategories: List<String>.from(data['allowedCategories'] ?? []),
      blockedCategories: List<String>.from(data['blockedCategories'] ?? []),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
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

