import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/providers/user_provider.dart';
import '../../../../../core/services/family_service.dart';
import 'qr_code_screen.dart';

/// Family setup screen for parents to create a family and generate invite codes
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _familyService = FamilyService();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    if (!_formKey.currentState!.validate()) return;

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
      final family = await _familyService.createFamily(
        parentId: user.id,
        familyName: _familyNameController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QRCodeScreen(
              familyId: family.id,
              familyName: family.name,
            ),
          ),
        );
      }
    } on FamilyException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create family. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(currentUserDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Setup'),
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
                : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: userData.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
            data: (user) {
              if (user?.hasFamily == true) {
                return _ExistingFamilyView(familyId: user!.familyId!);
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.family_restroom_rounded, size: 44, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          Text(
                            'Create Your Family Group',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          
                          Text(
                            'Name your family to generate pairing QR codes and start protecting children\'s devices.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          TextFormField(
                            controller: _familyNameController,
                            decoration: InputDecoration(
                              labelText: 'Family Name',
                              hintText: 'e.g., The Johnson Family',
                              prefixIcon: const Icon(Icons.home_rounded, color: Color(0xFF64748B)),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _createFamily(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a family name';
                              }
                              if (value.trim().length < 2) {
                                return 'Family name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _createFamily,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Create Family & Show QR',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Steps info
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Next Steps',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '1. Your family group will be generated.\n'
                                  '2. You\'ll receive a QR code and 6-digit pin.\n'
                                  '3. Scan on your child\'s phone to link instantly.\n'
                                  '4. Begin configuring screen-time and app limits.',
                                  style: TextStyle(color: Color(0xFF64748B), height: 1.5, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExistingFamilyView extends ConsumerWidget {
  final String familyId;

  const _ExistingFamilyView({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyService = FamilyService();

    return FutureBuilder(
      future: familyService.getFamilyData(familyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
          );
        }

        final family = snapshot.data;
        if (family == null) {
          return const Center(child: Text('Family not found'));
        }

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.family_restroom_rounded, size: 44, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Text(
                    family.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    'Your family group is active with ${family.childrenIds.length} connected device(s).',
                    style: const TextStyle(color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => QRCodeScreen(
                              familyId: family.id,
                              familyName: family.name,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.qr_code_rounded),
                      label: const Text(
                        'Show Family Pairing QR',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}