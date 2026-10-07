import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../../../core/models/location_model.dart';
import '../../../../core/services/location_service.dart';

class FamilyMapScreen extends ConsumerStatefulWidget {
  final String familyId;

  const FamilyMapScreen({
    super.key,
    required this.familyId,
  });

  @override
  ConsumerState<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends ConsumerState<FamilyMapScreen> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  Set<Marker> _markers = {};
  List<FamilyLocation> _locations = [];
  bool _isLoading = true;
  StreamSubscription<List<FamilyLocation>>? _locationSubscription;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _subscribeToLocations();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToLocations() {
    _locationSubscription = LocationService()
        .getFamilyLocations(widget.familyId)
        .listen((locations) {
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
      _updateMarkers(locations);
      _fitMapToLocations(locations);
    });
  }

  void _updateMarkers(List<FamilyLocation> locations) {
    final markers = <Marker>{};
    
    for (final location in locations) {
      markers.add(
        Marker(
          markerId: MarkerId(location.childId),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: _getChildName(location.childId),
            snippet: _getLocationSnippet(location),
          ),
          icon: location.isStale
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGrey)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _showLocationDetails(location),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  Future<void> _fitMapToLocations(List<FamilyLocation> locations) async {
    if (locations.isEmpty || _mapController == null) return;
    
    if (locations.length == 1) {
      // Single location - center on it
      final location = locations.first;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          15,
        ),
      );
      return;
    }
    
    // Multiple locations - fit to bounds
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;
    
    for (final location in locations) {
      minLat = minLat < location.latitude ? minLat : location.latitude;
      maxLat = maxLat > location.latitude ? maxLat : location.latitude;
      minLng = minLng < location.longitude ? minLng : location.longitude;
      maxLng = maxLng > location.longitude ? maxLng : location.longitude;
    }
    
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100, // padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Locations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLocations,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openLocationSettings(),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _mapController = controller;
              if (_locations.isNotEmpty) {
                _fitMapToLocations(_locations);
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          
          // Location list drawer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _LocationListPanel(
              locations: _locations,
              onLocationTap: _centerOnLocation,
              onLocationDetails: _showLocationDetails,
            ),
          ),
        ],
      ),
      floatingActionButton: _locations.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _fitMapToLocations(_locations),
              child: const Icon(Icons.center_focus_strong),
            )
          : null,
    );
  }

  String _getChildName(String childId) {
    // In a real implementation, you'd get this from user/family data
    return 'Child ${childId.substring(0, 6)}';
  }

  String _getLocationSnippet(FamilyLocation location) {
    final timeAgo = _getTimeAgo(location.timestamp);
    final accuracy = location.accuracy != null 
        ? ' (±${location.accuracy!.toInt()}m)'
        : '';
    
    return '$timeAgo$accuracy${location.isStale ? ' - Stale' : ''}';
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _refreshLocations() async {
    // Locations are automatically updated via stream
    // This could trigger a manual refresh if needed
  }

  void _openLocationSettings() {
    // Navigate to location settings
  }

  void _centerOnLocation(FamilyLocation location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        16,
      ),
    );
  }

  void _showLocationDetails(FamilyLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationDetailsSheet(location: location),
    );
  }
}

class _LocationListPanel extends StatelessWidget {
  final List<FamilyLocation> locations;
  final ValueChanged<FamilyLocation> onLocationTap;
  final ValueChanged<FamilyLocation> onLocationDetails;

  const _LocationListPanel({
    required this.locations,
    required this.onLocationTap,
    required this.onLocationDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No Locations Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Family members need to enable location sharing',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Family Locations (${locations.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return _LocationListItem(
                  location: location,
                  onTap: () => onLocationTap(location),
                  onDetails: () => onLocationDetails(location),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationListItem extends StatelessWidget {
  final FamilyLocation location;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  const _LocationListItem({
    required this.location,
    required this.onTap,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: location.isStale 
            ? Colors.grey.shade300 
            : Colors.blue.shade100,
        child: Icon(
          Icons.person,
          color: location.isStale 
              ? Colors.grey.shade600 
              : Colors.blue.shade700,
        ),
      ),
      
      title: Text(_getChildName(location.childId)),
      
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getTimeAgo(location.timestamp)),
          if (location.accuracy != null)
            Text(
              'Accuracy: ±${location.accuracy!.toInt()}m',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
      
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (location.isStale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Stale',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
      
      onTap: onTap,
      onLongPress: onDetails,
    );
  }

  String _getChildName(String childId) {
    return 'Child ${childId.substring(0, 6)}';
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _LocationDetailsSheet extends StatelessWidget {
  final FamilyLocation location;

  const _LocationDetailsSheet({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.person,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getChildName(location.childId),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getLocationStatus(),
                        style: TextStyle(
                          fontSize: 14,
                          color: location.isStale ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            _DetailRow(
              icon: Icons.access_time,
              title: 'Last Updated',
              value: _formatTimestamp(location.timestamp),
            ),
            
            const SizedBox(height: 16),
            
            _DetailRow(
              icon: Icons.location_on,
              title: 'Coordinates',
              value: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
            ),
            
            if (location.accuracy != null) ...[
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.gps_fixed,
                title: 'Accuracy',
                value: '±${location.accuracy!.toInt()} meters',
              ),
            ],
            
            if (location.altitude != null) ...[
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.terrain,
                title: 'Altitude',
                value: '${location.altitude!.toInt()}m above sea level',
              ),
            ],
            
            if (location.speed != null && location.speed! > 0) ...[
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.speed,
                title: 'Speed',
                value: '${(location.speed! * 3.6).toStringAsFixed(1)} km/h',
              ),
            ],
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Center map on this location
                },
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Center on Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getChildName(String childId) {
    return 'Child ${childId.substring(0, 6)}';
  }

  String _getLocationStatus() {
    if (location.isStale) {
      return 'Location may be outdated';
    } else {
      return 'Recent location';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}