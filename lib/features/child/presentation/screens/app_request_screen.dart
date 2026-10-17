import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/request_model.dart';
import '../../../../core/services/request_service.dart';
import '../../../../core/services/monitoring_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/providers/user_provider.dart';

/// Screen shown when child tries to access an ASK_PARENT app
class AppRequestScreen extends ConsumerStatefulWidget {
  final String packageName;
  final String appName;
  final String? appIconBase64;

  const AppRequestScreen({
    super.key,
    required this.packageName,
    required this.appName,
    this.appIconBase64,
  });

  @override
  ConsumerState<AppRequestScreen> createState() => _AppRequestScreenState();
}

class _AppRequestScreenState extends ConsumerState<AppRequestScreen> {
  bool _isRequesting = false;
  AppRequest? _pendingRequest;
  TemporaryPermission? _activePermission;

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
    _checkActivePermission();
    _listenForRequestUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // App icon
              _buildAppIcon(),
              
              const SizedBox(height: 24),
              
              // Title and message
              Text(
                'App Permission Required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                '${widget.appName} requires parent approval to use.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Content based on current state
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: widget.appIconBase64 != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.memory(
                base64Decode(widget.appIconBase64!),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
              ),
            )
          : _buildDefaultIcon(),
    );
  }

  Widget _buildDefaultIcon() {
    return Icon(
      Icons.apps,
      size: 40,
      color: Colors.blue[600],
    );
  }

  Widget _buildContent() {
    // Show active permission if available
    if (_activePermission?.isValid == true) {
      return _buildActivePermissionView();
    }

    // Show pending request if exists
    if (_pendingRequest?.isPending == true) {
      return _buildPendingRequestView();
    }

    // Show approved request waiting to be used
    if (_pendingRequest?.isApproved == true && _pendingRequest!.isAccessValid) {
      return _buildApprovedRequestView();
    }

    // Show denied request
    if (_pendingRequest?.isDenied == true) {
      return _buildDeniedRequestView();
    }

    // Show request form
    return _buildRequestForm();
  }

  Widget _buildRequestForm() {
    return Column(
      children: [
        // Information card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF4F46E5),
                size: 32,
              ),
              SizedBox(height: 12),
              Text(
                'Your parents will be notified about your request. They can approve it with specific time limits.',
                style: TextStyle(
                  color: Color(0xFF3730A3),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Request button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isRequesting ? null : _makeRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isRequesting
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
                      Text('Sending Request...'),
                    ],
                  )
                : const Text(
                    'Ask Parent',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Cancel button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.orange[600],
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Request Sent',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your parents have been notified. Please wait for their response.',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Request expires in ${_getTimeRemaining(_pendingRequest!.expiresAt)}',
                style: TextStyle(
                  color: Colors.orange[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.apps, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.appName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _cancelRequest,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[600],
            side: BorderSide(color: Colors.red[300]!),
          ),
          child: const Text('Cancel Request'),
        ),
      ],
    );
  }

  Widget _buildApprovedRequestView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Request Approved!',
                style: TextStyle(
                  color: Colors.green[800],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your parent approved ${_pendingRequest!.grantedMinutes} minutes of access.',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _pendingRequest!.timeRemainingText,
                style: TextStyle(
                  color: Colors.green[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Use app button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _activatePermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Use App Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivePermissionView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.timer,
                color: Colors.green[600],
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'App Access Active',
                style: TextStyle(
                  color: Colors.green[800],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can use ${widget.appName} until the timer expires.',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${_activePermission!.minutesRemaining} minutes remaining',
                style: TextStyle(
                  color: Colors.green[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Continue to app button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await MonitoringService.instance.openApp(widget.packageName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue to App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeniedRequestView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cancel,
                color: Colors.red[600],
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Request Denied',
                style: TextStyle(
                  color: Colors.red[800],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your parent has denied access to this app for now.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Try again later button
        OutlinedButton(
          onPressed: () {
            setState(() {
              _pendingRequest = null;
            });
          },
          child: const Text('Ask Again Later'),
        ),
      ],
    );
  }

  // Event handlers

  Future<void> _makeRequest() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    try {
      final user = ref.read(authProvider).user;
      final familyId = user?.familyId ?? ref.read(currentUserDataProvider).value?.familyId ?? ref.read(selectedFamilyProvider)?.id;
      
      if (user == null || familyId == null || familyId.isEmpty) {
        _showError('Not properly authenticated with a family');
        return;
      }

      final result = await RequestService.instance.createRequest(
        familyId: familyId,
        childId: user.uid,
        childName: user.displayName,
        packageName: widget.packageName,
        appName: widget.appName,
        deviceInfo: await _getDeviceInfo(),
      );

      if (result.success) {
        setState(() {
          _pendingRequest = result.request;
        });
        
        _showSuccess('Request sent to your parents');
      } else {
        _showError(result.error ?? 'Failed to send request');
        
        if (result.type == RequestResultType.duplicate) {
          setState(() {
            _pendingRequest = result.request;
          });
        }
      }
    } catch (e) {
      _showError('Failed to send request: $e');
    } finally {
      setState(() {
        _isRequesting = false;
      });
    }
  }

  Future<void> _cancelRequest() async {
    if (_pendingRequest == null) return;

    final user = ref.read(authProvider).user;
    final familyId = user?.familyId ?? ref.read(currentUserDataProvider).value?.familyId ?? ref.read(selectedFamilyProvider)?.id;
    
    if (user == null || familyId == null || familyId.isEmpty) return;

    final success = await RequestService.instance.cancelRequest(
      familyId,
      user.uid,
      _pendingRequest!.id,
    );

    if (success) {
      setState(() {
        _pendingRequest = null;
      });
      _showSuccess('Request cancelled');
    } else {
      _showError('Failed to cancel request');
    }
  }

  Future<void> _activatePermission() async {
    if (_pendingRequest?.isApproved != true) return;

    await RequestService.instance.handleApprovedRequest(_pendingRequest!);
    
    // Check for created permission
    var permission = await RequestService.instance.getActivePermission(widget.packageName);
    permission ??= TemporaryPermission(
      packageName: widget.packageName,
      appName: widget.appName,
      grantedAt: DateTime.now(),
      expiresAt: _pendingRequest?.accessExpiresAt ??
          DateTime.now().add(Duration(minutes: _pendingRequest?.grantedMinutes ?? 30)),
      grantedBy: _pendingRequest?.decidedBy ?? 'Parent',
    );
    if (mounted) {
      setState(() {
        _activePermission = permission;
      });
    }
    
    _showSuccess('App access activated');
    await MonitoringService.instance.openApp(widget.packageName);
  }

  // Helper methods

  void _checkExistingRequest() async {
    final user = ref.read(authProvider).user;
    final familyId = user?.familyId ?? ref.read(currentUserDataProvider).value?.familyId ?? ref.read(selectedFamilyProvider)?.id;
    
    if (user == null || familyId == null || familyId.isEmpty) return;

    // Check deterministic request document directly first
    final reqId = '${user.uid}_${widget.packageName.replaceAll('.', '_')}';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('requests')
          .doc(reqId)
          .get();
      if (doc.exists && mounted) {
        final req = AppRequest.fromFirestore(doc);
        if (!req.isExpired) {
          setState(() {
            _pendingRequest = req;
          });
          if (req.isApproved) {
            _activatePermission();
          }
          return;
        }
      }
    } catch (_) {}

    final requests = await RequestService.instance.getPendingRequests(familyId, user.uid);
    final existingRequest = requests.where((r) => r.packageName == widget.packageName).firstOrNull;
    
    if (existingRequest != null && mounted) {
      setState(() {
        _pendingRequest = existingRequest;
      });
      if (existingRequest.isApproved) {
        _activatePermission();
      }
    }
  }

  void _checkActivePermission() async {
    final permission = await RequestService.instance.getActivePermission(widget.packageName);
    if (permission != null) {
      setState(() {
        _activePermission = permission;
      });
    }
  }

  StreamSubscription? _docSubscription;

  void _listenForRequestUpdates() {
    final user = ref.read(authProvider).user;
    final familyId = user?.familyId ?? ref.read(currentUserDataProvider).value?.familyId ?? ref.read(selectedFamilyProvider)?.id;
    
    if (user == null || familyId == null || familyId.isEmpty) return;

    // 1. Listen via RequestService
    RequestService.instance.startListening(familyId, user.uid);
    RequestService.instance.requestUpdates.listen((request) {
      if (request.packageName == widget.packageName && mounted) {
        setState(() {
          _pendingRequest = request;
        });
        if (request.isApproved) {
          _activatePermission();
        }
      }
    });

    // 2. Direct listener on the exact request document for instant parent approval detection
    final reqId = '${user.uid}_${widget.packageName.replaceAll('.', '_')}';
    _docSubscription = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('requests')
        .doc(reqId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      try {
        final req = AppRequest.fromFirestore(snapshot);
        setState(() {
          _pendingRequest = req;
        });
        if (req.isApproved) {
          _activatePermission();
        }
      } catch (_) {}
    });
  }

  String _getTimeRemaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes} minutes';
    } else {
      return '${remaining.inSeconds} seconds';
    }
  }

  Future<String> _getDeviceInfo() async {
    // Get basic device info without sensitive data
    return 'Child Device'; // Placeholder
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

  @override
  void dispose() {
    _docSubscription?.cancel();
    RequestService.instance.stopListening();
    super.dispose();
  }
}