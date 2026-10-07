import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../../core/constants/app_routes.dart';
import '../../../../../core/providers/user_provider.dart';
import '../../../../../core/services/family_service.dart';

/// Join family screen for children to scan QR or enter code
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
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _joinFamily(String inviteCode) async {
    final userData = ref.read(currentUserDataProvider);
    final user = userData.value;
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
        childId: user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined family group!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
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
        _errorMessage = 'Failed to join family. Please verify the code.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onQRDetected(BarcodeCapture capture) {
    if (_isLoading) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null) return;

    try {
      final data = json.decode(code);
      if (data['type'] == 'family_invite' && data['code'] != null) {
        _joinFamily(data['code']);
      }
    } catch (e) {
      if (FamilyService.isValidCodeFormat(code)) {
        _joinFamily(code);
      } else {
        setState(() {
          _errorMessage = 'Invalid QR code format';
        });
      }
    }
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFECFDF5), const Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Tab Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: const Color(0xFF059669),
                    unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Scan QR Code'),
                      Tab(text: 'Enter 6-Digit Code'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Error alert
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // QR Scanner View
                    _buildQRScannerTab(isDark),

                    // Manual Code Entry View
                    _buildManualCodeTab(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRScannerTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            'Point camera at the QR code shown on your parent\'s device',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onQRDetected,
                  ),
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981), width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  if (_isLoading)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFF10B981)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildManualCodeTab(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.pin_rounded, size: 48, color: Color(0xFF059669)),
                    const SizedBox(height: 14),
                    const Text(
                      'Enter Family Pairing Code',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter the 6-digit numeric code from your parent\'s screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onSubmitted: (_) => _submitCode(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Connect to Family', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}