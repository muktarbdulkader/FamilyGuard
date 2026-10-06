import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/app_scanner_service.dart';
import '../../../../core/models/app_model.dart';
import '../../../../core/providers/auth_provider.dart';

/// Child apps screen showing installed apps and their rules
/// This screen scans REAL installed apps and syncs with Firestore
class ChildAppsScreen extends ConsumerStatefulWidget {
  const ChildAppsScreen({super.key});

  @override
  ConsumerState<ChildAppsScreen> createState() => _ChildAppsScreenState();
}

class _ChildAppsScreenState extends ConsumerState<ChildAppsScreen> {
  final AppScannerService _appScannerService = AppScannerService();
  
  List<InstalledAppInfo> _installedApps = [];
  bool _isScanning = false;
  bool _isUploading = false;
  String? _errorMessage;
  Timer? _monitoringTimer;

  @override
  void initState() {
    super.initState();
    _initializeAppMonitoring();
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    _appScannerService.stopAppInstallationMonitoring();
    super.dispose();
  }

  /// Initialize app monitoring for child device
  Future<void> _initializeAppMonitoring() async {
    await _scanAndUploadApps();
    await _startMonitoring();
  }

  /// Scan installed apps using real Android PackageManager API
  Future<void> _scanAndUploadApps() async {
    final userData = ref.read(currentUserDataProvider).value;
    if (userData == null || !userData.hasFamily) {
      setState(() {
        _errorMessage = 'Must be part of a family to scan apps';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      // Scan real installed apps using native Android APIs
      final installedApps = await _appScannerService.scanInstalledApps();
      
      setState(() {
        _installedApps = installedApps;
        _isScanning = false;
        _isUploading = true;
      });

      // Upload to Firestore for parent management
      await _appScannerService.uploadAppsToFirestore(
        familyId: userData.familyId!,
        childId: userData.uid,
        apps: installedApps,
      );

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${installedApps.length} apps'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _isUploading = false;
        _errorMessage = 'Failed to scan apps: ${e.toString()}';
      });
    }
  }

  /// Start monitoring for new app installations
  Future<void> _startMonitoring() async {
    final userData = ref.read(currentUserDataProvider).value;
    if (userData == null || !userData.hasFamily) return;

    try {
      // Start real-time monitoring for app installations/removals
      await _appScannerService.startAppInstallationMonitoring(
        familyId: userData.familyId!,
        childId: userData.uid,
      );

      // Periodic check for new apps (every 5 minutes)
      _monitoringTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _checkForNewApps(),
      );
    } catch (e) {
      print('Failed to start app monitoring: $e');
    }
  }

  /// Check for newly installed apps
  Future<void> _checkForNewApps() async {
    final userData = ref.read(currentUserDataProvider).value;
    if (userData == null || !userData.hasFamily) return;

    try {
      final newApps = await _appScannerService.checkForNewApps(
        familyId: userData.familyId!,
        childId: userData.uid,
      );

      if (newApps.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newApps.length} new apps detected'),
            backgroundColor: Colors.orange,
          ),
        );

        // Refresh the app list
        await _scanAndUploadApps();
      }
    } catch (e) {
      print('Failed to check for new apps: $e');
    }
  }

  /// Get app icon from base64 bytes
  Widget _buildAppIcon(InstalledAppInfo app) {
    if (app.iconBytes != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            app.iconBytes!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(Icons.android, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installed Apps'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning || _isUploading ? null : _scanAndUploadApps,
            tooltip: 'Rescan Apps',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.visibility, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your parents can see and manage these apps',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading states
          if (_isScanning || _isUploading) ...[
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _isScanning ? 'Scanning installed apps...' : 'Uploading to parents...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This may take a moment',
              style: TextStyle(color: Colors.grey),
            ),
          ],

          // Error message
          if (_errorMessage != null) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Apps list
          if (!_isScanning && !_isUploading && _installedApps.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.apps, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_installedApps.length} apps found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _installedApps.length,
                itemBuilder: (context, index) {
                  final app = _installedApps[index];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _buildAppIcon(app),
                      title: Text(
                        app.appName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.packageName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (app.isSystemApp) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'System',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                'v${app.version}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.info_outline,
                        color: Colors.grey[400],
                      ),
                      onTap: () => _showAppDetails(app),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      
      // Rescan button
      floatingActionButton: _isScanning || _isUploading
          ? null
          : FloatingActionButton(
              onPressed: _scanAndUploadApps,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
    );
  }

  /// Show app details dialog
  void _showAppDetails(InstalledAppInfo app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _buildAppIcon(app),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                app.appName,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Package Name', app.packageName),
            _DetailRow('Version', app.version),
            _DetailRow(
              'Installed',
              '${app.installTime.day}/${app.installTime.month}/${app.installTime.year}',
            ),
            _DetailRow(
              'Last Updated',
              '${app.lastUpdateTime.day}/${app.lastUpdateTime.month}/${app.lastUpdateTime.year}',
            ),
            _DetailRow('Type', app.isSystemApp ? 'System App' : 'User App'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying app detail rows
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}