import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/models/location_model.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/family_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/family_bottom_navigation.dart';
import '../../../../l10n/app_localizations.dart';

/// Family Location Screen — shows child locations without requiring a Maps API key.
/// Tapping a location card opens the native maps app via a geo: URI.
class FamilyMapScreen extends ConsumerStatefulWidget {
  final String? familyId;

  const FamilyMapScreen({super.key, this.familyId});

  @override
  ConsumerState<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends ConsumerState<FamilyMapScreen> {
  AppColors get _colors => AppColors.of(context);

  List<FamilyLocation> _locations = [];
  bool _isLoading = true;
  String? _error;
  String? _activeFamilyId;
  StreamSubscription<List<FamilyLocation>>? _locationSubscription;
  Timer? _statusRefreshTimer;

  @override
  void initState() {
    super.initState();
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _locations.isNotEmpty) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSubscription());
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  void _initSubscription() {
    final effectiveFamilyId =
        widget.familyId ??
        ref.read(selectedFamilyProvider)?.id ??
        ref.read(currentUserDataProvider).value?.familyId ??
        '';
    if (effectiveFamilyId.isNotEmpty) {
      _subscribeToLocations(effectiveFamilyId);
    }
  }

  void _subscribeToLocations([String? familyId]) {
    final effectiveId =
        familyId ??
        _activeFamilyId ??
        widget.familyId ??
        ref.read(selectedFamilyProvider)?.id ??
        ref.read(currentUserDataProvider).value?.familyId ??
        '';

    if (effectiveId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No family linked to this account yet.';
      });
      return;
    }

    _activeFamilyId = effectiveId;
    _locationSubscription?.cancel();
    _locationSubscription = LocationService()
        .getFamilyLocations(effectiveId)
        .listen(
          (locations) {
            if (mounted) {
              setState(() {
                _locations = locations;
                _isLoading = false;
                _error = null;
              });
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _error = 'Unable to load locations: $e';
              });
            }
          },
        );
  }

  /// Open the device's built-in maps app via a geo: URI (no API key needed)
  Future<void> _openInMaps(FamilyLocation loc) async {
    final uri =
        'geo:${loc.latitude},${loc.longitude}?q=${loc.latitude},${loc.longitude}';
    const channel = MethodChannel('family_guardian/permissions');
    try {
      // Use an Intent via Android — fallback to clipboard copy if unavailable
      await channel.invokeMethod('openUrl', {'url': uri});
    } catch (_) {
      // Fallback: copy coordinates to clipboard
      await Clipboard.setData(
        ClipboardData(text: '${loc.latitude}, ${loc.longitude}'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Coordinates copied to clipboard. Paste in Google Maps.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(currentUserDataProvider, (prev, next) {
      final fid = widget.familyId ?? next.value?.familyId;
      if (fid != null && fid.isNotEmpty && fid != _activeFamilyId) {
        _subscribeToLocations(fid);
      }
    });

    ref.listen(selectedFamilyProvider, (prev, next) {
      final fid = widget.familyId ?? next?.id;
      if (fid != null && fid.isNotEmpty && fid != _activeFamilyId) {
        _subscribeToLocations(fid);
      }
    });

    // Auto-subscribe if data becomes available
    final currentFid =
        widget.familyId ??
        ref.watch(currentUserDataProvider).value?.familyId ??
        ref.watch(selectedFamilyProvider)?.id;
    if (_activeFamilyId == null &&
        currentFid != null &&
        currentFid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeFamilyId != currentFid) {
          _subscribeToLocations(currentFid);
        }
      });
    }

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _colors.surface,
        foregroundColor: _colors.textPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.familyLocations,
              style: TextStyle(
                color: _colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              l10n.liveGpsTracking,
              style: TextStyle(fontSize: 12, color: _colors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              final fid =
                  _activeFamilyId ??
                  widget.familyId ??
                  ref.read(selectedFamilyProvider)?.id ??
                  ref.read(currentUserDataProvider).value?.familyId ??
                  '';
              if (fid.isNotEmpty) {
                _subscribeToLocations(fid);
              } else {
                setState(() {
                  _isLoading = false;
                  _error = 'No family linked to this account yet.';
                });
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const FamilyBottomNavigation(
        isParent: true,
        selected: FamilyNavDestination.location,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _colors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading family locations…',
              style: TextStyle(color: _colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_rounded,
                size: 64,
                color: _colors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Location Unavailable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _locationSubscription?.cancel();
                  _subscribeToLocations();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_locations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _colors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _colors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: _colors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap a card to open the location in your maps app.',
                  style: TextStyle(color: _colors.primary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Location cards
        ..._locations.map(
          (loc) => _LocationCard(
            location: loc,
            colors: _colors,
            onTap: () => _openInMaps(loc),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _colors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_searching_rounded,
                size: 56,
                color: _colors.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Locations Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Family members need to enable location sharing in the companion app. '
              'Locations will appear here automatically once shared.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _colors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Location Card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final FamilyLocation location;
  final AppColors colors;
  final VoidCallback onTap;

  const _LocationCard({
    required this.location,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(location.timestamp);
    final isStale = location.isStale;
    final displayName =
        (location.childName != null && location.childName!.trim().isNotEmpty)
        ? location.childName!.trim()
        : 'Child (${location.childId.length > 6 ? location.childId.substring(0, 6) : location.childId})';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isStale
                ? colors.error.withOpacity(0.45)
                : colors.success.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + status badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isStale
                          ? [colors.textMuted, colors.textSecondary]
                          : [colors.primary, colors.accent],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _initials(displayName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isStale ? colors.error : colors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'GPS updated $timeAgo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isStale ? colors.error : colors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Open in maps icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 12),

            // Coordinates
            _InfoRow(
              colors: colors,
              icon: Icons.my_location_rounded,
              label: 'Latitude',
              value: location.latitude.toStringAsFixed(6),
            ),
            const SizedBox(height: 6),
            _InfoRow(
              colors: colors,
              icon: Icons.explore_rounded,
              label: 'Longitude',
              value: location.longitude.toStringAsFixed(6),
            ),
            if (location.accuracy != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                colors: colors,
                icon: Icons.gps_fixed_rounded,
                label: 'Accuracy',
                value: '±${location.accuracy!.toInt()} m',
              ),
            ],
            FutureBuilder<String?>(
              future: (location.address != null && location.address!.isNotEmpty)
                  ? Future.value(location.address)
                  : GeocodingService.instance.getPlaceName(
                      location.latitude,
                      location.longitude,
                    ),
              builder: (context, snapshot) {
                final place = snapshot.data ?? location.address;
                if (place == null || place.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _InfoRow(
                    colors: colors,
                    icon: Icons.location_city_rounded,
                    label: 'City / Area',
                    value: place,
                  ),
                );
              },
            ),

            if (!location.isDeviceOnline) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(colors.isDark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.error.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 16, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Child device is offline. This is the last reported location.',
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // "Open in Maps" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Open in Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'C' : trimmed[0].toUpperCase();
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _InfoRow extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.colors,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
