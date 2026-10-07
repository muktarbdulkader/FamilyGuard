import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/providers/user_provider.dart';
import '../../../../../core/services/family_service.dart';
import 'qr_code_screen.dart';

/// Family setup screen for parents to create a family and generate invite codes
/// Shows options to create family and display QR/numeric codes
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

  /// Create family and navigate to QR code screen
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
      // Create family
      final family = await _familyService.createFamily(
        parentId: user.id,
        familyName: _familyNameController.text.trim(),
      );

      // Navigate to QR code screen
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Setup'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
          // If user already has a family, show existing family info
          if (user?.hasFamily == true) {
            return _ExistingFamilyView(familyId: user!.familyId!);
          }

          // Show family creation form
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Icon(
                    Icons.family_restroom,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Create Your Family',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Set up your family to start monitoring and managing children\'s devices safely.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Family name input
                  TextFormField(
                    controller: _familyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Family Name',
                      prefixIcon: Icon(Icons.home),
                      border: OutlineInputBorder(),
                      helperText: 'e.g., "The Smith Family"',
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
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Create family button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createFamily,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Family',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Info section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'What happens next?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. We\'ll create your family group\n'
                          '2. You\'ll get a QR code and 6-digit code\n'
                          '3. Share these with your children to join\n'
                          '4. Start monitoring and managing devices',
                          style: TextStyle(color: Colors.blue[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget showing existing family information
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        final family = snapshot.data;
        if (family == null) {
          return const Center(
            child: Text('Family not found'),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(
                Icons.family_restroom,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              
              Text(
                family.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Your family is already set up with ${family.childrenIds.length} child device(s).',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Generate new invite button
              ElevatedButton(
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Another Child Device'),
              ),
            ],
          ),
        );
      },
    );
  }
}