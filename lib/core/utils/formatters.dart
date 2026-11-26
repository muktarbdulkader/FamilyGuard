import 'package:flutter/material.dart';

/// Shared date, time, day-of-week, and duration formatters across all modules.
class AppFormatters {
  AppFormatters._();

  static const List<String> shortDayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String shortDayName(int weekday) {
    if (weekday >= 1 && weekday <= 7) {
      return shortDayNames[weekday - 1];
    }
    return '';
  }

  static String formatDaysList(
    List<int> days, {
    List<String>? dayLabels,
    String everyDayLabel = 'Every day',
    String separator = ' ',
  }) {
    if (days.length >= 7) return everyDayLabel;
    final labels = (dayLabels != null && dayLabels.length >= 7)
        ? dayLabels
        : shortDayNames;
    final sorted = List<int>.from(days)..sort();
    return sorted
        .where((d) => d >= 1 && d <= 7)
        .map((d) => labels[d - 1])
        .join(separator);
  }

  static String formatTimeOfDayAmPm(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  static String formatRelativeTime(
    DateTime dt, {
    bool includeHoursMinutesInDay = false,
    bool fallbackToDateTime = false,
  }) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      return includeHoursMinutesInDay
          ? '${diff.inHours}h ${diff.inMinutes % 60}m ago'
          : '${diff.inHours}h ago';
    }
    if (fallbackToDateTime) {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${diff.inDays}d ago';
  }
}
