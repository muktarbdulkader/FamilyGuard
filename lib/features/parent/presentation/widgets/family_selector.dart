import 'package:flutter/material.dart';
import '../../../../core/models/family_model.dart';

/// Widget for selecting a family from user's families
class FamilySelector extends StatelessWidget {
  final List<FamilyModel> families;
  final FamilyModel? selectedFamily;
  final ValueChanged<FamilyModel> onFamilySelected;

  const FamilySelector({
    super.key,
    required this.families,
    required this.selectedFamily,
    required this.onFamilySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : Colors.grey[700]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.home_outlined,
              size: 20,
              color: isDark ? const Color(0xFF2DD4BF) : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              'Family',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: labelColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (families.length == 1) ...[
          // Single family - show as card
          _FamilyCard(
            family: families.first,
            isSelected: true,
            onTap: () => onFamilySelected(families.first),
          ),
        ] else ...[
          // Multiple families - show as dropdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? const Color(0xFF1E3554) : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(14),
              color: isDark ? const Color(0xFF132238) : Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FamilyModel>(
                value: selectedFamily,
                dropdownColor: isDark ? const Color(0xFF132238) : Colors.white,
                hint: Text(
                  'Select a family',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF8BA0B8) : Colors.grey[600],
                  ),
                ),
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? const Color(0xFF8BA0B8) : Colors.grey[700],
                ),
                items: families.map((family) {
                  return DropdownMenuItem<FamilyModel>(
                    value: family,
                    child: Row(
                      children: [
                        Icon(
                          Icons.home,
                          size: 20,
                          color: isDark
                              ? const Color(0xFF2DD4BF)
                              : Colors.blue[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                family.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${family.childIds.length} children',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF8BA0B8)
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (family) {
                  if (family != null) {
                    onFamilySelected(family);
                  }
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Individual family card widget
class _FamilyCard extends StatelessWidget {
  final FamilyModel family;
  final bool isSelected;
  final VoidCallback onTap;

  const _FamilyCard({
    required this.family,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? (isSelected ? const Color(0xFF0F2B38) : const Color(0xFF132238))
        : (isSelected ? Colors.blue[50]! : Colors.white);

    final borderColor = isDark
        ? (isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF1E3554))
        : (isSelected ? Colors.blue[300]! : Colors.grey[300]!);

    final iconBg = isDark
        ? const Color(0xFF063D39)
        : (isSelected ? Colors.blue[100]! : Colors.grey[100]!);

    final iconColor = isDark ? const Color(0xFF2DD4BF) : Colors.blue[700]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.home_rounded, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: isDark
                              ? Colors.white
                              : (isSelected
                                    ? Colors.blue[800]
                                    : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: isDark
                                ? const Color(0xFF8BA0B8)
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${family.childIds.length} children',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF8BA0B8)
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    color: isDark ? const Color(0xFF2DD4BF) : Colors.blue[600],
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: isDark ? const Color(0xFF8BA0B8) : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Created ${_formatDate(family.createdAt)}',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF8BA0B8)
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).round()}w ago';
    } else {
      return '${(difference.inDays / 30).round()}mo ago';
    }
  }
}
