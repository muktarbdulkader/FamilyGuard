import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../../core/constants/app_routes.dart';
import '../../../../../core/providers/auth_provider.dart';
import '../../../../../core/services/family_service.dart';

/// Join family screen for children to scan QR or enter code
/// Supports both QR code scanning and manual code entry
class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _familyService = FamilyService();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  /// Join family with invite code
  Future<void> _joinFamily(String inviteCode) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _familyService.joinFamily(
        inviteCode: inviteCode,
        childId: user.uid,
      );

      if (mounted) {
        // Show success and navigate to child home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined family!'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.go(AppRoutes.childHome);
      }

    } on FamilyException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to join family. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle QR code detection
  void _onQRDetected(BarcodeCapture capture) {
    if (_isLoading) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null) return;

    try {
      // Try to parse as JSON (QR code data)
      final data = json.decode(code);
      if (data['type'] == 'family_invite' && data['code'] != null) {
        _joinFamily(data['code']);
      }
    } catch (e) {
      // If not JSON, treat as plain invite code
      if (FamilyService.isValidCodeFormat(code)) {
        _joinFamily(code);
      } else {
        setState(() {
          _errorMessage = 'Invalid QR code format';
        });
      }
    }
  }

  /// Submit manual code entry
  void _submitCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the invite code';
      });
      return;
    }

    if (!FamilyService.isValidCodeFormat(code)) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code';
      });
      return;
    }

    _joinFamily(code);
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(currentUserDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.keyboard), text: 'Enter Code'),
          ],
        ),
      ),
      body: userData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (user) {
          // If user already has a family, show message
          if (user?.hasFamily == true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.family_restroom,
                      size: 80,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Already in Family',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You are already part of a family. Contact your parent if you need to join a different family.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.childHome),
                      child: const Text('Go to Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // QR Scanner Tab
              _QRScannerTab(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                onQRDetected: _onQRDetected,
              ),

              // Manual Code Entry Tab
              _ManualCodeTab(
                controller: _codeController,
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                onSubmit: _submitCode,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// QR Scanner tab widget
class _QRScannerTab extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final Function(BarcodeCapture) onQRDetected;

  const _QRScannerTab({
    required this.isLoading,
    required this.errorMessage,
    required this.onQRDetected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scanner area
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              MobileScanner(
                onDetect: onQRDetected,
              ),
              
              // Overlay with scanning frame
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Corner frames
                        ...List.generate(4, (index) {
                          final isTop = index < 2;
                          final isLeft = index % 2 == 0;
                          return Positioned(
                            top: isTop ? 0 : null,
                            bottom: isTop ? null : 0,
                            left: isLeft ? 0 : null,
                            right: isLeft ? null : 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.only(
                                  topLeft: isTop && isLeft ? const Radius.circular(10) : Radius.zero,
                                  topRight: isTop && !isLeft ? const Radius.circular(10) : Radius.zero,
                                  bottomLeft: !isTop && isLeft ? const Radius.circular(10) : Radius.zero,
                                  bottomRight: !isTop && !isLeft ? const Radius.circular(10) : Radius.zero,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // Loading overlay
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 16),
                        Text(
                          'Joining family...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Instructions area
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  size: 32,
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Point your camera at the QR code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Your parent should show you the QR code on their device',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),

                // Error message
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Manual code entry tab widget
class _ManualCodeTab extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  const _ManualCodeTab({
    required this.controller,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          // Icon and title
          const Icon(
            Icons.keyboard,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          
          Text(
            'Enter the 6-digit code',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          Text(
            'Ask your parent for the 6-digit family code and enter it below',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Code input
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Family Code',
              hintText: '123456',
              prefixIcon: Icon(Icons.family_restroom),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            maxLength: 6,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 24),

          // Error message
          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                errorMessage!,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit button
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Join Family',
                    style: TextStyle(fontSize: 16),
                  ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}