import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/services/family_service.dart';
import '../../../../../core/models/family_invite_model.dart';
import '../../../../../core/constants/app_constants.dart';

/// QR code screen showing invite code and QR code for family pairing
/// Displays both QR code and 6-digit numeric code with auto-refresh
class QRCodeScreen extends StatefulWidget {
  final String familyId;
  final String familyName;

  const QRCodeScreen({
    super.key,
    required this.familyId,
    required this.familyName,
  });

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  final _familyService = FamilyService();
  
  FamilyInviteModel? _currentInvite;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _generateInviteCode();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Generate new invite code
  Future<void> _generateInviteCode() async {
    // Get current user from the widget context
    final context = this.context;
    if (!context.mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the parent ID from the family document
      final familyDoc = await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyId)
          .get();
      
      if (!familyDoc.exists) {
        throw FamilyException('Family not found');
      }

      final familyData = familyDoc.data() as Map<String, dynamic>;
      final parentId = familyData['parentId'] as String;

      final invite = await _familyService.generateInviteCode(
        familyId: widget.familyId,
        parentId: parentId,
      );

      setState(() {
        _currentInvite = invite;
        _remainingSeconds = invite.expiresAt.difference(DateTime.now()).inSeconds;
      });

      _startCountdown();
    } on FamilyException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate invite code';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Start auto-refresh timer (generate new code when current expires)
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(minutes: AppConstants.familyCodeExpirationMinutes),
      (_) => _generateInviteCode(),
    );
  }

  /// Start countdown timer for remaining time
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        setState(() {
          _remainingSeconds--;
        });
        
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _generateInviteCode(); // Generate new code when expired
        }
      },
    );
  }

  /// Copy invite code to clipboard
  void _copyCode() {
    if (_currentInvite != null) {
      Clipboard.setData(ClipboardData(text: _currentInvite!.code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Get QR code data as JSON
  String _getQRData() {
    if (_currentInvite == null) return '';
    
    return json.encode({
      'type': 'family_invite',
      'code': _currentInvite!.code,
      'familyId': widget.familyId,
      'familyName': widget.familyName,
      'expiresAt': _currentInvite!.expiresAt.toIso8601String(),
    });
  }

  /// Format remaining time as MM:SS
  String _formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Invite'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _generateInviteCode,
            tooltip: 'Generate New Code',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              widget.familyName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            Text(
              'Share this code with your child to connect their device',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error, color: Colors.red[700], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _generateInviteCode,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ] else if (_currentInvite != null) ...[
              // QR Code
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // QR Code
                      Expanded(
                        child: QrImageView(
                          data: _getQRData(),
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 6-digit code
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentInvite!.code,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: _copyCode,
                              tooltip: 'Copy Code',
                              color: Colors.blue[700],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Expiration info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code expires in: ${_formatRemainingTime()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                          Text(
                            'A new code will be generated automatically',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. On your child\'s device, open Family Guardian\n'
                      '2. Choose "I am a Child" and create/login to account\n'
                      '3. Scan this QR code OR enter the 6-digit code\n'
                      '4. Complete the device permission setup\n'
                      '5. Start monitoring and managing safely!',
                      style: TextStyle(color: Colors.blue[600]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}