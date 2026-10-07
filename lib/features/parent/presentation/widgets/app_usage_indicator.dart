import 'package:flutter/material.dart';

/// Widget that shows app usage progress against daily limit
class AppUsageIndicator extends StatelessWidget {
  final int usedMinutes;
  final int limitMinutes;
  final bool showText;

  const AppUsageIndicator({
    super.key,
    required this.usedMinutes,
    required this.limitMinutes,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (usedMinutes / limitMinutes).clamp(0.0, 1.0);
    final isOverLimit = usedMinutes >= limitMinutes;
    final remainingMinutes = limitMinutes - usedMinutes;

    Color progressColor;
    if (isOverLimit) {
      progressColor = Colors.red;
    } else if (percentage > 0.8) {
      progressColor = Colors.orange;
    } else if (percentage > 0.5) {
      progressColor = Colors.amber;
    } else {
      progressColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showText) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatUsageText(),
                style: TextStyle(
                  fontSize: 11,
                  color: progressColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isOverLimit)
                Text(
                  '${_formatMinutes(remainingMinutes)} left',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  String _formatUsageText() {
    final usedFormatted = _formatMinutes(usedMinutes);
    final limitFormatted = _formatMinutes(limitMinutes);
    
    if (usedMinutes >= limitMinutes) {
      return '$usedFormatted / $limitFormatted (Limit exceeded)';
    } else {
      return '$usedFormatted / $limitFormatted';
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }
}

/// Compact version for use in lists
class CompactUsageIndicator extends StatelessWidget {
  final int usedMinutes;
  final int limitMinutes;

  const CompactUsageIndicator({
    super.key,
    required this.usedMinutes,
    required this.limitMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (usedMinutes / limitMinutes).clamp(0.0, 1.0);
    final isOverLimit = usedMinutes >= limitMinutes;

    Color color;
    if (isOverLimit) {
      color = Colors.red;
    } else if (percentage > 0.8) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    return SizedBox(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${usedMinutes}m',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}