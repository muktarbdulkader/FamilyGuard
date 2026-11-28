import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

enum FamilyNavDestination {
  home,
  apps,
  location,
  requests,
  notifications,
  profile,
  lessons,
  health,
  setup,
}

/// Unified floating bottom navigation bar used consistently across all
/// parent and child screens.
class FamilyBottomNavigation extends ConsumerWidget {
  const FamilyBottomNavigation({
    required this.isParent,
    required this.selected,
    this.familyId,
    this.childId,
    this.childName,
    super.key,
  });

  final bool isParent;
  final FamilyNavDestination selected;
  final String? familyId;
  final String? childId;
  final String? childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorsProvider);
    final l10n = AppLocalizations.of(context);
    final unreadCount = isParent
        ? ref.watch(unreadNotificationCountProvider)
        : 0;

    final destinations = isParent
        ? <_NavigationItem>[
            _NavigationItem(
              FamilyNavDestination.home,
              Icons.home_rounded,
              l10n.home,
              AppRoutes.parentHome,
            ),
            _NavigationItem(
              FamilyNavDestination.apps,
              Icons.tune_rounded,
              l10n.control,
              AppRoutes.parentApps,
            ),
            _NavigationItem(
              FamilyNavDestination.location,
              Icons.location_on_rounded,
              l10n.location,
              AppRoutes.parentLocation,
            ),
            _NavigationItem(
              FamilyNavDestination.requests,
              Icons.access_time_rounded,
              l10n.requests,
              AppRoutes.parentRequests,
            ),
            _NavigationItem(
              FamilyNavDestination.notifications,
              Icons.notifications_rounded,
              l10n.alerts,
              '/notifications',
            ),
            _NavigationItem(
              FamilyNavDestination.profile,
              Icons.person_rounded,
              l10n.profile,
              AppRoutes.profile,
            ),
          ]
        : <_NavigationItem>[
            _NavigationItem(
              FamilyNavDestination.home,
              Icons.home_rounded,
              l10n.home,
              AppRoutes.childHome,
            ),
            _NavigationItem(
              FamilyNavDestination.apps,
              Icons.grid_view_rounded,
              l10n.apps,
              AppRoutes.childApps,
            ),
            _NavigationItem(
              FamilyNavDestination.lessons,
              Icons.school_rounded,
              l10n.lessons,
              AppRoutes.childEducation,
            ),
            _NavigationItem(
              FamilyNavDestination.health,
              Icons.health_and_safety_rounded,
              l10n.health,
              AppRoutes.childStatus,
            ),
            _NavigationItem(
              FamilyNavDestination.setup,
              Icons.shield_rounded,
              l10n.setup,
              AppRoutes.childPermissions,
            ),
            _NavigationItem(
              FamilyNavDestination.profile,
              Icons.person_rounded,
              l10n.profile,
              AppRoutes.profile,
            ),
          ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colors.border.withOpacity(colors.isDark ? 0.85 : 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(colors.isDark ? 0.34 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: colors.primary.withOpacity(colors.isDark ? 0.08 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in destinations)
              Expanded(
                child: _NavigationButton(
                  item: item,
                  isSelected: item.destination == selected,
                  unreadCount:
                      item.destination == FamilyNavDestination.notifications
                      ? unreadCount
                      : 0,
                  colors: colors,
                  onTap: () => _navigate(context, item),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, _NavigationItem item) {
    if (item.destination == selected) return;
    if (!isParent && item.destination == FamilyNavDestination.lessons) {
      final familyId = this.familyId;
      final childId = this.childId;
      if (familyId == null || familyId.isEmpty || childId == null) return;
      context.go(
        item.route,
        extra: {
          'familyId': familyId,
          'childId': childId,
          'childName': childName ?? 'Me',
        },
      );
      return;
    }
    context.go(item.route);
  }
}

class _NavigationItem {
  const _NavigationItem(this.destination, this.icon, this.label, this.route);

  final FamilyNavDestination destination;
  final IconData icon;
  final String label;
  final String route;
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.isSelected,
    required this.unreadCount,
    required this.colors,
    required this.onTap,
  });

  final _NavigationItem item;
  final bool isSelected;
  final int unreadCount;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? colors.primary : colors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withOpacity(colors.isDark ? 0.18 : 0.11)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: colors.primary.withOpacity(0.14),
              highlightColor: colors.primary.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: isSelected ? 16 : 0,
                      height: 2.5,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(
                      height: 22,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(item.icon, color: foreground, size: 21),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -8,
                              top: -5,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 15,
                                  minHeight: 15,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 9.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          letterSpacing: isSelected ? 0.1 : 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
