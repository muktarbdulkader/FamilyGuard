import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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
    final colors = AppColors.of(context);
    final safeLimit = limitMinutes > 0 ? limitMinutes : 120;
    final percentage = (usedMinutes / safeLimit).clamp(0.0, 1.0);
    final isOverLimit = usedMinutes >= safeLimit;
    final remainingMinutes = (safeLimit - usedMinutes).clamp(0, safeLimit);

    Color progressColor;
    if (isOverLimit) {
      progressColor = colors.error;
    } else if (percentage > 0.8) {
      progressColor = colors.warning;
    } else if (percentage > 0.5) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = colors.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showText) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _formatUsageText(safeLimit),
                  style: TextStyle(
                    fontSize: 11,
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isOverLimit)
                Text(
                  '${_formatMinutes(remainingMinutes)} left',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  String _formatUsageText(int safeLimit) {
    final usedFormatted = _formatMinutes(usedMinutes);
    final limitFormatted = _formatMinutes(safeLimit);

    if (usedMinutes >= safeLimit) {
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
    final colors = AppColors.of(context);
    final safeLimit = limitMinutes > 0 ? limitMinutes : 120;
    final percentage = (usedMinutes / safeLimit).clamp(0.0, 1.0);
    final isOverLimit = usedMinutes >= safeLimit;

    Color color;
    if (isOverLimit) {
      color = colors.error;
    } else if (percentage > 0.8) {
      color = colors.warning;
    } else {
      color = colors.success;
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
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}