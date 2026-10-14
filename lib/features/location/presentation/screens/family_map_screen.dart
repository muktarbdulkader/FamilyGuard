import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/models/location_model.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/providers/user_provider.dart';

/// Family Location Screen — shows child locations without requiring a Maps API key.
/// Tapping a location card opens the native maps app via a geo: URI.
class FamilyMapScreen extends ConsumerStatefulWidget {
  final String? familyId;

  const FamilyMapScreen({super.key, this.familyId});

  @override
  ConsumerState<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends ConsumerState<FamilyMapScreen> {
  List<FamilyLocation> _locations = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<FamilyLocation>>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeToLocations());
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToLocations() {
    final effectiveFamilyId =
        widget.familyId ?? ref.read(currentUserDataProvider).value?.familyId ?? '';
    if (effectiveFamilyId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No family linked to this account yet.';
      });
      return;
    }

    _locationSubscription = LocationService()
        .getFamilyLocations(effectiveFamilyId)
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
    final uri = 'geo:${loc.latitude},${loc.longitude}?q=${loc.latitude},${loc.longitude}';
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
            content: Text('Coordinates copied to clipboard. Paste in Google Maps.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Family Locations',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              'Live GPS tracking',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _locationSubscription?.cancel();
              _subscribeToLocations();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(height: 16),
            Text('Loading family locations…', style: TextStyle(color: Color(0xFF64748B))),
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
              const Icon(Icons.location_off_rounded, size: 64, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 16),
              const Text(
                'Location Unavailable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() { _isLoading = true; _error = null; });
                  _locationSubscription?.cancel();
                  _subscribeToLocations();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
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
            color: const Color(0xFF4F46E5).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap a card to open the location in your maps app.',
                  style: TextStyle(
                    color: const Color(0xFF4F46E5).withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Location cards
        ..._locations.map((loc) => _LocationCard(
          location: loc,
          onTap: () => _openInMaps(loc),
        )),
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
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_searching_rounded,
                size: 56,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Locations Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Family members need to enable location sharing in the companion app. '
              'Locations will appear here automatically once shared.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
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
  final VoidCallback onTap;

  const _LocationCard({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(location.timestamp);
    final isStale = location.isStale;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isStale
                ? const Color(0xFFFCA5A5)
                : const Color(0xFF34D399).withOpacity(0.4),
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
                          ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                          : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _initials(location.childId),
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
                        'Child · ${location.childId.substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isStale
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isStale ? 'Stale ($timeAgo)' : 'Updated $timeAgo',
                            style: TextStyle(
                              fontSize: 12,
                              color: isStale
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.w500,
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
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Coordinates
            _InfoRow(
              icon: Icons.my_location_rounded,
              label: 'Latitude',
              value: location.latitude.toStringAsFixed(6),
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.explore_rounded,
              label: 'Longitude',
              value: location.longitude.toStringAsFixed(6),
            ),
            if (location.accuracy != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.gps_fixed_rounded,
                label: 'Accuracy',
                value: '±${location.accuracy!.toInt()} m',
              ),
            ],
            if (location.address != null && location.address!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.place_rounded,
                label: 'Address',
                value: location.address!,
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
                  backgroundColor: const Color(0xFF4F46E5),
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

  String _initials(String childId) {
    return childId.isEmpty ? 'C' : childId[0].toUpperCase();
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
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}