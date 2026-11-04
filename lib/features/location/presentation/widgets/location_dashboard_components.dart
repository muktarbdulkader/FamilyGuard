import 'package:flutter/material.dart';

import '../../../../core/models/location_model.dart';
import '../../../../core/theme/app_colors.dart';

class LocationPageHeader extends StatelessWidget {
  const LocationPageHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.isRefreshing,
    required this.refreshTooltip,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final String refreshTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: colors.surfaceHighlight,
            borderRadius: BorderRadius.circular(13),
            child: IconButton(
              onPressed: onRefresh,
              tooltip: refreshTooltip,
              icon: isRefreshing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationOverviewPanel extends StatelessWidget {
  const LocationOverviewPanel({required this.locations, super.key});

  final List<FamilyLocation> locations;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recentCount = locations.where((location) => !location.isStale).length;
    final onlineCount = locations
        .where((location) => location.isDeviceOnline)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isDark
              ? const [Color(0xFF251B45), Color(0xFF18243B)]
              : const [Color(0xFFF2ECFF), Color(0xFFE9E9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.isDark
              ? const Color(0xFF514078)
              : const Color(0xFFD8CCFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Family overview',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded, size: 15, color: colors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Live updates',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 154,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.isDark
                  ? const Color(0xFF17233A)
                  : const Color(0xFFFAF8FF),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: colors.isDark
                    ? const Color(0xFF34425A)
                    : const Color(0xFFE3DDF2),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LocationGridPainter(
                      lineColor: colors.primary.withOpacity(
                        colors.isDark ? 0.12 : 0.09,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withOpacity(0.08),
                    border: Border.all(
                      color: colors.primary.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withOpacity(0.12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: colors.primary,
                    size: 42,
                  ),
                ),
                Positioned(
                  right: 13,
                  bottom: 12,
                  child: Text(
                    'Select a location to open Maps',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: 'Locations',
                  value: '${locations.length}',
                  icon: Icons.place_outlined,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetric(
                  label: 'Recent',
                  value: '$recentCount',
                  icon: Icons.update_rounded,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetric(
                  label: 'Devices online',
                  value: '$onlineCount',
                  icon: Icons.wifi_rounded,
                  colors: colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LocationSectionHeading extends StatelessWidget {
  const LocationSectionHeading({
    required this.title,
    required this.count,
    super.key,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: colors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LocationGridPainter extends CustomPainter {
  const _LocationGridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    for (var x = -size.height; x < size.width + size.height; x += 38) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset((x + size.height).toDouble(), size.height),
        paint,
      );
    }

    for (var y = 22.0; y < size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LocationGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
