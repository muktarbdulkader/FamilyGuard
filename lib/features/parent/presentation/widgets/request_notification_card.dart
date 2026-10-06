import 'package:flutter/material.dart';
import '../../../../core/models/request_model.dart';
import '../../../../core/models/family_model.dart';
import '../screens/app_approval_screen.dart';

/// Notification card for displaying pending app requests to parents
class RequestNotificationCard extends StatelessWidget {
  final AppRequest request;
  final ChildModel child;
  final VoidCallback? onApproved;
  final VoidCallback? onDenied;

  const RequestNotificationCard({
    Key? key,
    required this.request,
    required this.child,
    this.onApproved,
    this.onDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isExpired = request.isExpired;
    final timeRemaining = _getTimeRemaining();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isExpired ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpired 
              ? Colors.grey[300]! 
              : Colors.orange[300]!,
          width: isExpired ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: isExpired ? null : () => _openApprovalScreen(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Status icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isExpired 
                          ? Colors.grey[100] 
                          : Colors.orange[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpired ? Icons.access_time_filled : Icons.help_outline,
                      color: isExpired 
                          ? Colors.grey[600] 
                          : Colors.orange[700],
                      size: 18,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Request info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Permission Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isExpired ? Colors.grey[600] : Colors.black87,
                          ),
                        ),
                        Text(
                          isExpired ? 'Expired' : timeRemaining,
                          style: TextStyle(
                            fontSize: 12,
                            color: isExpired 
                                ? Colors.grey[500] 
                                : Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Priority indicator
                  if (!isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // App and child info
              Row(
                children: [
                  // App icon placeholder
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Icon(
                      Icons.apps,
                      color: Colors.blue[600],
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.appName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requested by ${child.displayName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _formatRequestTime(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (!isExpired) ...[
                const SizedBox(height: 16),
                
                // Quick action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _quickDeny(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Deny',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _quickApprove(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '15 min',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // More options button
                    ElevatedButton(
                      onPressed: () => _openApprovalScreen(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'More',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeRemaining() {
    if (request.isExpired) return 'Expired';
    
    final remaining = request.expiresAt.difference(DateTime.now());
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m remaining';
    } else {
      return '${remaining.inSeconds}s remaining';
    }
  }

  String _formatRequestTime() {
    final now = DateTime.now();
    final difference = now.difference(request.createdAt);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${request.createdAt.day}/${request.createdAt.month}';
    }
  }

  void _openApprovalScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AppApprovalScreen(
          request: request,
          child: child,
        ),
      ),
    ).then((approved) {
      if (approved == true) {
        onApproved?.call();
      } else if (approved == false) {
        onDenied?.call();
      }
    });
  }

  void _quickApprove(BuildContext context) {
    // Show quick approval options
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => QuickApprovalSheet(
        request: request,
        child: child,
        onApproved: onApproved,
      ),
    );
  }

  void _quickDeny(BuildContext context) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Request'),
        content: Text(
          'Are you sure you want to deny ${child.displayName}\'s request to use ${request.appName}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Call denial service
              onDenied?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
  }
}

/// Quick approval bottom sheet
class QuickApprovalSheet extends StatelessWidget {
  final AppRequest request;
  final ChildModel child;
  final VoidCallback? onApproved;

  const QuickApprovalSheet({
    Key? key,
    required this.request,
    required this.child,
    this.onApproved,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final quickOptions = [
      ApprovalDuration.fifteenMinutes,
      ApprovalDuration.thirtyMinutes,
      ApprovalDuration.oneHour,
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Approve',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${request.appName} for ${child.displayName}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Quick approval options
          ...quickOptions.map((duration) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Call approval service with duration
                  onApproved?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Allow for ${duration.displayText}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )),
          
          const SizedBox(height: 8),
          
          // More options button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AppApprovalScreen(
                      request: request,
                      child: child,
                    ),
                  ),
                ).then((approved) {
                  if (approved == true) {
                    onApproved?.call();
                  }
                });
              },
              child: const Text('More Options'),
            ),
          ),
        ],
      ),
    );
  }
}