import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/permission_service.dart';

/// Permission onboarding screen for child devices
/// Guides children through required Android permissions step-by-step
class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends ConsumerState<PermissionOnboardingScreen> {
  final PageController _pageController = PageController();
  final PermissionService _permissionService = PermissionService();
  
  int _currentPage = 0;
  Timer? _statusCheckTimer;
  
  // Permission status tracking
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasNotification = false;
  LocationPermissionStatus _locationStatus = LocationPermissionStatus.denied;
  bool _hasBatteryOptDisabled = false;

  final List<PermissionStep> _permissionSteps = [
    PermissionStep(
      title: 'Usage Access',
      description: 'Allows the app to monitor which apps are being used and for how long.',
      explanation: 'This permission helps parents understand your app usage and set appropriate time limits.',
      icon: Icons.analytics,
      isRequired: true,
    ),
    PermissionStep(
      title: 'Display Over Other Apps',
      description: 'Shows a lock screen when blocked apps are opened.',
      explanation: 'This creates a safe barrier that prevents access to blocked apps and shows request options.',
      icon: Icons.lock_outline,
      isRequired: true,
    ),
    PermissionStep(
      title: 'Notifications',
      description: 'Displays monitoring status and parental control alerts.',
      explanation: 'You\'ll always know when monitoring is active, and parents can send important messages.',
      icon: Icons.notifications,
      isRequired: true,
    ),
    PermissionStep(
      title: 'Location Access',
      description: 'Shares your location with parents for safety.',
      explanation: 'This helps parents know you\'re safe and can set up safe zones like home and school.',
      icon: Icons.location_on,
      isRequired: true,
    ),
    PermissionStep(
      title: 'Battery Optimization',
      description: 'Keeps the monitoring service running in the background.',
      explanation: 'This ensures parental controls work consistently even when other apps are running.',
      icon: Icons.battery_full,
      isRequired: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
    _startStatusCheckTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  /// Start timer to periodically check permission status
  void _startStatusCheckTimer() {
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkAllPermissions(),
    );
  }

  /// Check status of all permissions
  Future<void> _checkAllPermissions() async {
    try {
      final hasUsageStats = await _permissionService.hasUsageStatsPermission();
      final hasOverlay = await _permissionService.hasOverlayPermission();
      final hasNotification = await _permissionService.hasNotificationPermission();
      final locationStatus = await _permissionService.getLocationPermissionStatus();
      final hasBatteryOptDisabled = await _permissionService.isBatteryOptimizationDisabled();

      if (mounted) {
        setState(() {
          _hasUsageStats = hasUsageStats;
          _hasOverlay = hasOverlay;
          _hasNotification = hasNotification;
          _locationStatus = locationStatus;
          _hasBatteryOptDisabled = hasBatteryOptDisabled;
        });
      }
    } catch (e) {
      // Silently handle errors during permission checks
    }
  }

  /// Get permission status for current step
  bool _isCurrentStepGranted() {
    switch (_currentPage) {
      case 0:
        return _hasUsageStats;
      case 1:
        return _hasOverlay;
      case 2:
        return _hasNotification;
      case 3:
        return _locationStatus == LocationPermissionStatus.always ||
               _locationStatus == LocationPermissionStatus.whileInUse;
      case 4:
        return _hasBatteryOptDisabled;
      default:
        return false;
    }
  }

  /// Handle permission request for current step
  Future<void> _requestCurrentPermission() async {
    try {
      switch (_currentPage) {
        case 0:
          await _permissionService.openUsageStatsSettings();
          break;
        case 1:
          await _permissionService.openOverlaySettings();
          break;
        case 2:
          await _permissionService.requestNotificationPermission();
          break;
        case 3:
          await _permissionService.requestLocationPermission();
          break;
        case 4:
          await _permissionService.openBatteryOptimizationSettings();
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Go to next step or complete onboarding
  void _nextStep() {
    if (_currentPage < _permissionSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  /// Go to previous step
  void _previousStep() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Complete the onboarding process
  Future<void> _completeOnboarding() async {
    // Create monitoring notification
    try {
      await _permissionService.createMonitoringNotification();
    } catch (e) {
      // Continue even if notification creation fails
    }

    // Navigate to child home
    if (mounted) {
      context.go(AppRoutes.childHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Setup'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: _currentPage > 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_currentPage + 1} of ${_permissionSteps.length}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${((_currentPage + 1) / _permissionSteps.length * 100).round()}%',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentPage + 1) / _permissionSteps.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ],
            ),
          ),

          // Permission steps
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _permissionSteps.length,
              itemBuilder: (context, index) {
                final step = _permissionSteps[index];
                final isGranted = _isCurrentStepGranted();

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Icon and status
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isGranted ? Colors.green[100] : Colors.orange[100],
                          border: Border.all(
                            color: isGranted ? Colors.green : Colors.orange,
                            width: 3,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              step.icon,
                              size: 48,
                              color: isGranted ? Colors.green : Colors.orange,
                            ),
                            if (isGranted)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Title and required badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (step.isRequired) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Required',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // Explanation
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Why is this needed?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              step.explanation,
                              style: TextStyle(color: Colors.blue[600]),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Status and action button
                      if (isGranted) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Permission granted! You can continue to the next step.',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ElevatedButton(
                          onPressed: _requestCurrentPermission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: Text(
                            step.isRequired 
                                ? 'Grant Permission' 
                                : 'Open Settings (Optional)',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Previous button
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),

                if (_currentPage > 0) const SizedBox(width: 16),

                // Next/Complete button
                Expanded(
                  flex: _currentPage > 0 ? 1 : 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final currentStep = _permissionSteps[_currentPage];
                      if (currentStep.isRequired && !_isCurrentStepGranted()) {
                        // Show warning for required permissions
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Permission Required'),
                            content: const Text(
                              'This permission is required for the parental controls to work properly. Please grant the permission to continue.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        _nextStep();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _currentPage == _permissionSteps.length - 1
                          ? 'Complete Setup'
                          : 'Next',
                      style: const TextStyle(fontSize: 16),
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
}

/// Permission step data class
class PermissionStep {
  final String title;
  final String description;
  final String explanation;
  final IconData icon;
  final bool isRequired;

  const PermissionStep({
    required this.title,
    required this.description,
    required this.explanation,
    required this.icon,
    required this.isRequired,
  });
}