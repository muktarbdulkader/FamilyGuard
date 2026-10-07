import 'package:flutter/material.dart';
import '../../../../core/models/family_model.dart';

/// Widget for selecting a child from family's children
class ChildSelector extends StatelessWidget {
  final List<ChildModel> children;
  final ChildModel? selectedChild;
  final ValueChanged<ChildModel> onChildSelected;

  const ChildSelector({
    super.key,
    required this.children,
    required this.selectedChild,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.child_care_outlined,
              size: 20,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              'Child',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (children.length <= 2) ...[
          // Few children - show as cards
          ...children.map((child) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChildCard(
              child: child,
              isSelected: selectedChild?.id == child.id,
              onTap: () => onChildSelected(child),
            ),
          )),
        ] else ...[
          // Many children - show as dropdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ChildModel>(
                value: selectedChild,
                hint: const Text('Select a child'),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: children.map((child) {
                  return DropdownMenuItem<ChildModel>(
                    value: child,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: child.statusColor.withOpacity(0.2),
                          child: Icon(
                            Icons.child_care,
                            size: 16,
                            color: child.statusColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                child.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                child.statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: child.statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: child.statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (child) {
                  if (child != null) {
                    onChildSelected(child);
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

/// Individual child card widget
class _ChildCard extends StatelessWidget {
  final ChildModel child;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChildCard({
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green[300]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green[100],
                  child: Icon(
                    Icons.child_care,
                    color: Colors.green[700],
                    size: 28,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: child.statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Colors.green[800] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: child.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          child.statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: child.statusColor,
                          ),
                        ),
                      ),
                      if (child.deviceInfo != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.phone_android,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            child.deviceInfo!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}