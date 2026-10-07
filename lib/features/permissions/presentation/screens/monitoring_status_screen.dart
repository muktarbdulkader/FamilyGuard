import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/providers/user_provider.dart';
import 'permission_onboarding_screen.dart';

/// Monitoring status screen showing current parental control status
/// Always visible indicator that monitoring is active (transparency requirement)
class MonitoringStatusScreen extends ConsumerStatefulWidget {
  const MonitoringStatusScreen({super.key});

  @override
  ConsumerState<MonitoringStatusScreen> createState() => _MonitoringStatusScreenState();
}

class _MonitoringStatusScreenState extends ConsumerState<MonitoringStatusScreen> {
  final PermissionService _permissionService = PermissionService();
  Timer? _statusCheckTimer;
  
  // Permission status
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasNotification = false;
  LocationPermissionStatus _locationStatus = LocationPermissionStatus.denied;
  bool _hasBatteryOptDisabled = false;
  
  PermissionStatus _overallStatus = PermissionStatus.none;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
    _startStatusCheckTimer();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  /// Start timer to periodically check permission status
  void _startStatusCheckTimer() {
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
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
      final overallStatus = await _permissionService.getAllPermissionStatus();

      if (mounted) {
        setState(() {
          _hasUsageStats = hasUsageStats;
          _hasOverlay = hasOverlay;
          _hasNotification = hasNotification;
          _locationStatus = locationStatus;
          _hasBatteryOptDisabled = hasBatteryOptDisabled;
          _overallStatus = overallStatus;
        });
      }
    } catch (e) {
      // Handle errors silently
    }
  }

  /// Get status color based on overall permission status
  Color _getStatusColor() {
    switch (_overallStatus) {
      case PermissionStatus.allGranted:
        return Colors.green;
      case PermissionStatus.partial:
        return Colors.orange;
      case PermissionStatus.none:
        return Colors.red;
    }
  }

  /// Get status text based on overall permission status
  String _getStatusText() {
    switch (_overallStatus) {
      case PermissionStatus.allGranted:
        return 'Fully Active';
      case PermissionStatus.partial:
        return 'Partially Active';
      case PermissionStatus.none:
        return 'Inactive';
    }
  }

  /// Get status description
  String _getStatusDescription() {
    switch (_overallStatus) {
      case PermissionStatus.allGranted:
        return 'All parental controls are working properly. Your parents can monitor your device usage and keep you safe.';
      case PermissionStatus.partial:
        return 'Some parental controls are active, but additional permissions are needed for full protection.';
      case PermissionStatus.none:
        return 'Parental controls are not active. Please complete the permission setup to stay safe.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(currentUserDataProvider);
    final statusColor = _getStatusColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Status'),
        backgroundColor: statusColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAllPermissions,
            tooltip: 'Refresh Status',
          ),
        ],
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
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 64,
                      color: statusColor,
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Parental Controls',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      _getStatusDescription(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Permission details
              Text(
                'Permission Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Permission status items
              _StatusItem(
                title: 'App Usage Monitoring',
                description: 'Tracks which apps are used and for how long',
                isGranted: _hasUsageStats,
                isRequired: true,
                onTap: () => _permissionService.openUsageStatsSettings(),
              ),
              
              _StatusItem(
                title: 'App Blocking',
                description: 'Can block apps and show lock screens',
                isGranted: _hasOverlay,
                isRequired: true,
                onTap: () => _permissionService.openOverlaySettings(),
              ),
              
              _StatusItem(
                title: 'Notifications',
                description: 'Shows monitoring status and alerts',
                isGranted: _hasNotification,
                isRequired: true,
                onTap: () => _permissionService.openNotificationSettings(),
              ),
              
              _StatusItem(
                title: 'Location Sharing',
                description: 'Shares location with parents for safety',
                isGranted: _locationStatus == LocationPermissionStatus.always ||
                          _locationStatus == LocationPermissionStatus.whileInUse,
                isRequired: true,
                onTap: () => _permissionService.openLocationSettings(),
              ),
              
              _StatusItem(
                title: 'Battery Optimization',
                description: 'Keeps monitoring active in background',
                isGranted: _hasBatteryOptDisabled,
                isRequired: false,
                onTap: () => _permissionService.openBatteryOptimizationSettings(),
              ),

              const SizedBox(height: 32),

              // Action buttons
              if (_overallStatus != PermissionStatus.allGranted) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PermissionOnboardingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Fix Permissions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Info section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'About Monitoring',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This app helps your parents keep you safe online. All monitoring is transparent - you\'ll always know what\'s being tracked. If you have questions, talk to your parents.',
                      style: TextStyle(color: Colors.blue[600]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You can view this status screen anytime to see which parental controls are active on your device.',
                      style: TextStyle(color: Colors.blue[600]),
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

/// Status item widget for individual permissions
class _StatusItem extends StatelessWidget {
  final String title;
  final String description;
  final bool isGranted;
  final bool isRequired;
  final VoidCallback onTap;

  const _StatusItem({
    required this.title,
    required this.description,
    required this.isGranted,
    required this.isRequired,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGranted ? Colors.green[100] : Colors.red[100],
          ),
          child: Icon(
            isGranted ? Icons.check : Icons.close,
            color: isGranted ? Colors.green : Colors.red,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (isRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
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
        ),
        subtitle: Text(description),
        trailing: isGranted
            ? null
            : IconButton(
                icon: const Icon(Icons.settings),
                onPressed: onTap,
                tooltip: 'Open Settings',
              ),
        onTap: isGranted ? null : onTap,
      ),
    );
  }
}