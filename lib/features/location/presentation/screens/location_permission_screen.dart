import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/services/location_service.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  final String familyId;
  final VoidCallback? onComplete;

  const LocationPermissionScreen({
    super.key,
    required this.familyId,
    this.onComplete,
  });

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  LocationPermissionInfo? _permissionInfo;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    final info = await LocationService().checkLocationPermission();
    setState(() {
      _permissionInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Sharing Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentPage + 1) / 4,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _DisclosurePage(),
                _PermissionExplanationPage(),
                _PermissionRequestPage(
                  onPermissionRequested: _requestLocationPermission,
                  permissionInfo: _permissionInfo,
                  isLoading: _isLoading,
                ),
                _SetupCompletePage(onComplete: _completeSetup),
              ],
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _previousPage,
                    child: const Text('Previous'),
                  )
                else
                  const Spacer(),
                
                const Spacer(),
                
                ElevatedButton(
                  onPressed: _canProceed() ? _nextPage : null,
                  child: Text(_currentPage == 3 ? 'Complete' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0:
      case 1:
        return true;
      case 2:
        return _permissionInfo?.canShareLocation == true;
      case 3:
        return true;
    }
    return false;
  }

  Future<void> _nextPage() async {
    if (_currentPage < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeSetup();
    }
  }

  Future<void> _previousPage() async {
    if (_currentPage > 0) {
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoading = true);
    
    try {
      final info = await LocationService().requestLocationPermission();
      
      setState(() {
        _permissionInfo = info;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeSetup() async {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      context.pop(true);
    }
  }
}

class _DisclosurePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Family Location Sharing',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Location sharing helps your family stay connected and ensures safety by allowing parents to see where family members are located.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Important Disclosure',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Your location will be shared with your family members\n'
                  '• Location is collected when the app is open and optionally in the background\n'
                  '• You can turn off location sharing at any time\n'
                  '• Location data is stored securely and only shared within your family',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your Privacy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Location sharing is completely optional\n'
                  '• You have full control over when sharing is active\n'
                  '• Your location is never shared outside your family\n'
                  '• All location data is encrypted and secure',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionExplanationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_searching,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Location Permissions',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'To share your location with your family, we need permission to access your device\'s location services.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          _PermissionCard(
            icon: Icons.location_on,
            title: 'Location Access',
            description: 'Allows the app to determine your current location',
            isRequired: true,
          ),
          
          const SizedBox(height: 16),
          
          _PermissionCard(
            icon: Icons.my_location,
            title: 'Background Location',
            description: 'Allows location sharing even when the app is not open',
            isRequired: false,
            subtitle: 'Optional - for automatic updates',
          ),
          
          const SizedBox(height: 16),
          
          _PermissionCard(
            icon: Icons.battery_saver,
            title: 'Battery Optimization',
            description: 'Ensures reliable location updates',
            isRequired: false,
            subtitle: 'Recommended for best experience',
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.eco, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Battery Efficient',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Our location sharing is designed to minimize battery usage by only updating when you move significantly and limiting update frequency.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? subtitle;
  final bool isRequired;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.subtitle,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRequestPage extends StatelessWidget {
  final VoidCallback onPermissionRequested;
  final LocationPermissionInfo? permissionInfo;
  final bool isLoading;

  const _PermissionRequestPage({
    required this.onPermissionRequested,
    required this.permissionInfo,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (permissionInfo?.canShareLocation == true)
            Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green.shade600,
            )
          else
            Icon(
              Icons.location_disabled,
              size: 80,
              color: Colors.orange.shade600,
            ),
          
          const SizedBox(height: 24),
          
          Text(
            permissionInfo?.canShareLocation == true
                ? 'Permissions Granted!'
                : 'Grant Location Permission',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          if (permissionInfo?.canShareLocation == true)
            const Text(
              'Great! Location sharing is now available. You can proceed to complete the setup.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            )
          else
            const Text(
              'Tap the button below to grant location permission. This will allow your family to see your location when sharing is enabled.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          
          const SizedBox(height: 32),
          
          if (permissionInfo != null) ...[
            _PermissionStatusCard(
              title: 'Location Access',
              status: _getPermissionStatus(permissionInfo!.status),
              isGranted: permissionInfo!.canShareLocation,
            ),
            
            const SizedBox(height: 16),
            
            if (permissionInfo!.canShareLocation)
              _PermissionStatusCard(
                title: 'Background Location',
                status: permissionInfo!.status == LocationPermissionStatus.backgroundAllowed
                    ? 'Granted'
                    : 'Foreground Only',
                isGranted: true,
                subtitle: permissionInfo!.status != LocationPermissionStatus.backgroundAllowed
                    ? 'You can still share location when the app is open'
                    : null,
              ),
          ],
          
          const SizedBox(height: 32),
          
          if (permissionInfo?.canShareLocation != true) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onPermissionRequested,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Grant Location Permission',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Location Settings'),
            ),
          ],
          
          if (permissionInfo?.denialReason != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      permissionInfo!.denialReason!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getPermissionStatus(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.notRequested:
        return 'Not Requested';
      case LocationPermissionStatus.denied:
        return 'Denied';
      case LocationPermissionStatus.foregroundOnly:
        return 'Foreground Only';
      case LocationPermissionStatus.backgroundAllowed:
        return 'Background Allowed';
    }
  }
}

class _PermissionStatusCard extends StatelessWidget {
  final String title;
  final String status;
  final bool isGranted;
  final String? subtitle;

  const _PermissionStatusCard({
    required this.title,
    required this.status,
    required this.isGranted,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.shade50 : Colors.orange.shade50,
        border: Border.all(
          color: isGranted ? Colors.green.shade300 : Colors.orange.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.warning,
            color: isGranted ? Colors.green.shade600 : Colors.orange.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCompletePage extends StatelessWidget {
  final VoidCallback onComplete;

  const _SetupCompletePage({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.celebration,
            size: 80,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Setup Complete!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Location sharing is now configured. Your family members will be able to see your location when sharing is enabled.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.control_camera, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You\'re In Control',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Turn location sharing on or off anytime\n'
                  '• See when your location is being shared\n'
                  '• Manage sharing settings in the app\n'
                  '• Your location is only shared within your family',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Finish Setup',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}