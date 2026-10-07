import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/request_model.dart';
import '../../../../core/models/family_model.dart';
import '../../../../core/services/approval_service.dart';
import '../../../../core/providers/auth_provider.dart';

/// Screen for parents to approve or deny child app requests
class AppApprovalScreen extends ConsumerStatefulWidget {
  final AppRequest request;
  final ChildModel child;

  const AppApprovalScreen({
    super.key,
    required this.request,
    required this.child,
  });

  @override
  ConsumerState<AppApprovalScreen> createState() => _AppApprovalScreenState();
}

class _AppApprovalScreenState extends ConsumerState<AppApprovalScreen> {
  bool _isProcessing = false;
  ApprovalDuration? _selectedDuration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('App Request'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request info card
            _buildRequestInfoCard(),
            
            const SizedBox(height: 24),
            
            // Child info
            _buildChildInfo(),
            
            const SizedBox(height: 24),
            
            // Request details
            _buildRequestDetails(),
            
            const SizedBox(height: 32),
            
            // Approval options
            Text(
              'Grant Access For:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Duration options
            Expanded(
              child: _buildDurationOptions(),
            ),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          // App icon placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.apps,
              color: Colors.blue[600],
              size: 32,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.appName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.request.packageName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'REQUIRES APPROVAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green[100],
            child: Icon(
              Icons.person,
              color: Colors.green[600],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.child.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                widget.child.statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.child.statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Request Details',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        _buildDetailRow('Requested at', _formatDateTime(widget.request.createdAt)),
        _buildDetailRow('Expires at', _formatDateTime(widget.request.expiresAt)),
        _buildDetailRow('Device', widget.request.deviceInfo ?? 'Unknown'),
        
        const SizedBox(height: 8),
        
        if (widget.request.expiresAt.isBefore(DateTime.now())) 
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '⚠️ This request has expired',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationOptions() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: ApprovalDuration.values.map((duration) {
        final isSelected = _selectedDuration == duration;
        
        return InkWell(
          onTap: widget.request.isExpired 
              ? null 
              : () {
                  setState(() {
                    _selectedDuration = duration;
                  });
                },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.white,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getDurationIcon(duration),
                  color: isSelected ? Colors.blue : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  duration.displayText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.blue : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    final canApprove = !widget.request.isExpired && _selectedDuration != null;
    
    return Column(
      children: [
        // Approve button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (canApprove && !_isProcessing) ? _approveRequest : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Processing...'),
                    ],
                  )
                : Text(
                    canApprove 
                        ? 'Approve for ${_selectedDuration!.displayText}' 
                        : 'Select duration to approve',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Deny button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: (!widget.request.isExpired && !_isProcessing) ? _denyRequest : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Deny Request',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Cancel button
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  // Event handlers

  Future<void> _approveRequest() async {
    if (_selectedDuration == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = ref.read(authProvider).user;
      if (user == null) throw Exception('Not authenticated');

      final success = await ApprovalService.instance.approveRequest(
        requestId: widget.request.id,
        familyId: widget.request.familyId,
        childId: widget.request.childId,
        parentId: user.uid,
        grantedMinutes: _selectedDuration!.minutes,
      );

      if (success) {
        if (mounted) {
          _showSuccess('Request approved successfully');
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) _showError('Failed to approve request');
      }
    } catch (e) {
      if (mounted) _showError('Error approving request: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _denyRequest() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = ref.read(authProvider).user;
      if (user == null) throw Exception('Not authenticated');

      final success = await ApprovalService.instance.denyRequest(
        requestId: widget.request.id,
        familyId: widget.request.familyId,
        childId: widget.request.childId,
        parentId: user.uid,
      );

      if (success) {
        if (mounted) {
          _showSuccess('Request denied');
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) _showError('Failed to deny request');
      }
    } catch (e) {
      if (mounted) _showError('Error denying request: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Helper methods

  IconData _getDurationIcon(ApprovalDuration duration) {
    switch (duration) {
      case ApprovalDuration.fifteenMinutes:
        return Icons.timer;
      case ApprovalDuration.thirtyMinutes:
        return Icons.schedule;
      case ApprovalDuration.oneHour:
        return Icons.access_time;
      case ApprovalDuration.twoHours:
        return Icons.timelapse;
      case ApprovalDuration.restOfDay:
        return Icons.today;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.abs().inMinutes < 1) {
      return 'Just now';
    } else if (difference.abs().inMinutes < 60) {
      return difference.isNegative 
          ? '${difference.abs().inMinutes}m ago'
          : 'In ${difference.inMinutes}m';
    } else if (difference.abs().inHours < 24) {
      return difference.isNegative
          ? '${difference.abs().inHours}h ago'
          : 'In ${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}