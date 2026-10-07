import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/providers/auth_provider.dart';

class LocationSettingsScreen extends ConsumerStatefulWidget {
  final String familyId;

  const LocationSettingsScreen({
    super.key,
    required this.familyId,
  });

  @override
  ConsumerState<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends ConsumerState<LocationSettingsScreen> {
  LocationSharingSettings? _settings;
  LocationPermissionInfo? _permissionInfo;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final settings = await LocationService().getFamilyLocationSettings(widget.familyId);
      final permissionInfo = await LocationService().checkLocationPermission();
      
      setState(() {
        _settings = settings ?? LocationSharingSettings(familyId: widget.familyId);
        _permissionInfo = permissionInfo;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isParent = user?.role == 'parent';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Sharing'),
        actions: [
          if (isParent)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isParent) ...[
                    _ParentLocationControls(
                      settings: _settings!,
                      onSettingsChanged: (newSettings) {
                        setState(() => _settings = newSettings);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  _ChildLocationStatus(
                    settings: _settings!,
                    permissionInfo: _permissionInfo,
                    onPermissionSetup: _setupPermissions,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  _LocationPrivacyInfo(),
                ],
              ),
            ),
    );
  }

  Future<void> _setupPermissions() async {
    final result = await context.push<bool>(
      '/location/permissions/${widget.familyId}',
    );
    
    if (result == true) {
      await _loadSettings();
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final user = ref.read(authProvider);
      if (user == null) return;

      // Get family data to find children
      // In a real implementation, you'd get this from family provider
      final childIds = <String>[]; // TODO: Get actual child IDs from family
      
      final success = await LocationService().enableLocationSharing(
        familyId: widget.familyId,
        childIds: _settings!.enabledForChildren.isNotEmpty 
            ? _settings!.enabledForChildren 
            : childIds,
        updateInterval: _settings!.updateInterval,
        minimumDistance: _settings!.minimumDistance,
        shareOnlyWhenAppOpen: _settings!.shareOnlyWhenAppOpen,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location sharing settings saved'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to save settings');
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

class _ParentLocationControls extends StatelessWidget {
  final LocationSharingSettings settings;
  final ValueChanged<LocationSharingSettings> onSettingsChanged;

  const _ParentLocationControls({
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Family Location Sharing',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Location Sharing'),
                subtitle: const Text('Allow family members to share their locations'),
                value: settings.isEnabled,
                onChanged: (value) {
                  onSettingsChanged(settings.copyWith(isEnabled: value));
                },
              ),
              
              if (settings.isEnabled) ...[
                const Divider(height: 1),
                
                ListTile(
                  title: const Text('Update Frequency'),
                  subtitle: Text('Every ${settings.updateInterval.inMinutes} minutes'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showUpdateIntervalPicker(context),
                ),
                
                const Divider(height: 1),
                
                ListTile(
                  title: const Text('Minimum Distance'),
                  subtitle: Text('${settings.minimumDistance.toInt()} meters'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showDistancePicker(context),
                ),
                
                const Divider(height: 1),
                
                SwitchListTile(
                  title: const Text('Foreground Only'),
                  subtitle: const Text('Only share location when app is open'),
                  value: settings.shareOnlyWhenAppOpen,
                  onChanged: (value) {
                    onSettingsChanged(settings.copyWith(shareOnlyWhenAppOpen: value));
                  },
                ),
              ],
            ],
          ),
        ),
        
        if (settings.isEnabled) ...[
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Location Sharing Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Family members with location sharing enabled will have their locations visible to parents. All family members can see their own sharing status.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showUpdateIntervalPicker(BuildContext context) async {
    final intervals = [
      const Duration(minutes: 1),
      const Duration(minutes: 2),
      const Duration(minutes: 5),
      const Duration(minutes: 10),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
    ];

    final selected = await showDialog<Duration>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Update Frequency'),
        children: intervals.map((interval) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(interval),
            child: Text('Every ${interval.inMinutes} minutes'),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      onSettingsChanged(settings.copyWith(updateInterval: selected));
    }
  }

  Future<void> _showDistancePicker(BuildContext context) async {
    final distances = [10.0, 25.0, 50.0, 100.0, 200.0, 500.0];

    final selected = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Minimum Distance'),
        children: distances.map((distance) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(distance),
            child: Text('${distance.toInt()} meters'),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      onSettingsChanged(settings.copyWith(minimumDistance: selected));
    }
  }
}

class _ChildLocationStatus extends StatelessWidget {
  final LocationSharingSettings settings;
  final LocationPermissionInfo? permissionInfo;
  final VoidCallback onPermissionSetup;

  const _ChildLocationStatus({
    required this.settings,
    required this.permissionInfo,
    required this.onPermissionSetup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Location Sharing Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      settings.isEnabled && _canShareLocation()
                          ? Icons.location_on
                          : Icons.location_off,
                      color: settings.isEnabled && _canShareLocation()
                          ? Colors.green
                          : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getStatusSubtitle(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (settings.isEnabled) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  _StatusRow(
                    icon: Icons.family_restroom,
                    title: 'Family Sharing',
                    status: 'Enabled',
                    isPositive: true,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _StatusRow(
                    icon: Icons.security,
                    title: 'Location Permission',
                    status: _getPermissionStatusText(),
                    isPositive: _canShareLocation(),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _StatusRow(
                    icon: Icons.update,
                    title: 'Update Frequency',
                    status: 'Every ${settings.updateInterval.inMinutes} minutes',
                    isPositive: true,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _StatusRow(
                    icon: settings.shareOnlyWhenAppOpen ? Icons.phone_android : Icons.background_replace,
                    title: 'Sharing Mode',
                    status: settings.shareOnlyWhenAppOpen ? 'Foreground Only' : 'Background Enabled',
                    isPositive: true,
                  ),
                ],
                
                if (!_canShareLocation() && settings.isEnabled) ...[
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPermissionSetup,
                      child: const Text('Setup Location Permissions'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        if (LocationService().isLocationSharingActive) ...[
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.radio_button_checked, color: Colors.green.shade600),
                const SizedBox(height: 8),
                Text(
                  'Location Sharing Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your location is being shared with your family',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _canShareLocation() {
    return permissionInfo?.canShareLocation == true;
  }

  String _getStatusTitle() {
    if (!settings.isEnabled) {
      return 'Location Sharing Disabled';
    } else if (_canShareLocation()) {
      return 'Location Sharing Enabled';
    } else {
      return 'Permission Required';
    }
  }

  String _getStatusSubtitle() {
    if (!settings.isEnabled) {
      return 'Your family has not enabled location sharing';
    } else if (_canShareLocation()) {
      return 'Your location can be shared with your family';
    } else {
      return 'Location permissions need to be granted';
    }
  }

  String _getPermissionStatusText() {
    if (permissionInfo == null) return 'Checking...';
    
    switch (permissionInfo!.status) {
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

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final bool isPositive;

  const _StatusRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isPositive ? Colors.green.shade600 : Colors.orange.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isPositive ? Colors.green.shade700 : Colors.orange.shade700,
          ),
        ),
      ],
    );
  }
}

class _LocationPrivacyInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy & Security',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Your Location Data',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                const _PrivacyPoint(
                  icon: Icons.family_restroom,
                  text: 'Only shared within your family group',
                ),
                
                const SizedBox(height: 8),
                
                const _PrivacyPoint(
                  icon: Icons.lock,
                  text: 'Encrypted and securely stored',
                ),
                
                const SizedBox(height: 8),
                
                const _PrivacyPoint(
                  icon: Icons.timer,
                  text: 'Automatically deleted after 30 days',
                ),
                
                const SizedBox(height: 8),
                
                const _PrivacyPoint(
                  icon: Icons.control_camera,
                  text: 'You can disable sharing anytime',
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () {
                    // TODO: Open privacy policy
                  },
                  child: const Text('View Privacy Policy'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PrivacyPoint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.blue.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}