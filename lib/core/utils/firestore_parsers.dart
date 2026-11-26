import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shared Firestore field parsing utilities used across all data models.
class FirestoreParsers {
  FirestoreParsers._();

  static DateTime parseDateTime(dynamic value, {DateTime? fallback}) {
    final parsed = parseOptionalDateTime(value);
    return parsed ?? fallback ?? DateTime.now();
  }

  static DateTime? parseOptionalDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static TimeOfDay parseTimeOfDay(
    dynamic value, {
    TimeOfDay fallback = const TimeOfDay(hour: 8, minute: 0),
  }) {
    if (value is Map) {
      return TimeOfDay(
        hour: (value['hour'] as num?)?.toInt() ?? fallback.hour,
        minute: (value['minute'] as num?)?.toInt() ?? fallback.minute,
      );
    }
    return fallback;
  }
}
