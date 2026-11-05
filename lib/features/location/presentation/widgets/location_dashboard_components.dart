import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/models/location_model.dart';
import '../../../../core/theme/app_colors.dart';

class LocationPageHeader extends StatelessWidget {
  const LocationPageHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.isRefreshing,
    required this.refreshTooltip,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final String refreshTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: colors.surfaceHighlight,
            borderRadius: BorderRadius.circular(13),
            child: IconButton(
              onPressed: onRefresh,
              tooltip: refreshTooltip,
              icon: isRefreshing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationOverviewPanel extends StatelessWidget {
  const LocationOverviewPanel({
    required this.locations,
    required this.selectedLocationId,
    required this.onLocationSelected,
    super.key,
  });

  final List<FamilyLocation> locations;
  final String? selectedLocationId;
  final ValueChanged<FamilyLocation> onLocationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recentCount = locations.where((location) => !location.isStale).length;
    final onlineCount = locations
        .where((location) => location.isDeviceOnline)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.isDark
              ? const [Color(0xFF251B45), Color(0xFF18243B)]
              : const [Color(0xFFF2ECFF), Color(0xFFE9E9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.isDark
              ? const Color(0xFF514078)
              : const Color(0xFFD8CCFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Family overview',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded, size: 15, color: colors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Live updates',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LiveFamilyMap(
            locations: locations,
            selectedLocationId: selectedLocationId,
            onLocationSelected: onLocationSelected,
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: 'Locations',
                  value: '${locations.length}',
                  icon: Icons.place_outlined,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetric(
                  label: 'Recent',
                  value: '$recentCount',
                  icon: Icons.update_rounded,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetric(
                  label: 'Devices online',
                  value: '$onlineCount',
                  icon: Icons.wifi_rounded,
                  colors: colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LocationSectionHeading extends StatelessWidget {
  const LocationSectionHeading({
    required this.title,
    required this.count,
    super.key,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: colors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LiveFamilyMap extends StatefulWidget {
  const _LiveFamilyMap({
    required this.locations,
    required this.selectedLocationId,
    required this.onLocationSelected,
  });

  final List<FamilyLocation> locations;
  final String? selectedLocationId;
  final ValueChanged<FamilyLocation> onLocationSelected;

  @override
  State<_LiveFamilyMap> createState() => _LiveFamilyMapState();
}

class _LiveFamilyMapState extends State<_LiveFamilyMap> {
  GoogleMapController? _controller;
  String _locationFingerprint = '';
  String? _lastSelectedLocationId;

  List<FamilyLocation> get _validLocations => widget.locations
      .where(
        (location) =>
            location.latitude.isFinite &&
            location.longitude.isFinite &&
            location.latitude >= -90 &&
            location.latitude <= 90 &&
            location.longitude >= -180 &&
            location.longitude <= 180 &&
            (location.latitude != 0 || location.longitude != 0),
      )
      .toList(growable: false);

  String _fingerprint(List<FamilyLocation> locations) => locations
      .map(
        (location) =>
            '${location.id}:${location.latitude}:${location.longitude}:'
            '${location.timestamp.microsecondsSinceEpoch}',
      )
      .join('|');

  @override
  void didUpdateWidget(covariant _LiveFamilyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locations = _validLocations;
    final fingerprint = _fingerprint(locations);
    if (fingerprint != _locationFingerprint) {
      _locationFingerprint = fingerprint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAllLocations();
      });
    } else if (widget.selectedLocationId != _lastSelectedLocationId) {
      _lastSelectedLocationId = widget.selectedLocationId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusSelectedLocation();
      });
    }
  }

  Set<Marker> _buildMarkers() {
    return {
      for (final location in _validLocations)
        Marker(
          markerId: MarkerId(
            location.id.isNotEmpty ? location.id : location.childId,
          ),
          position: LatLng(location.latitude, location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            location.isStale ? BitmapDescriptor.hueRed : 276,
          ),
          infoWindow: InfoWindow(
            title: _displayName(location),
            snippet: location.isStale
                ? 'Last location · ${_timeAgo(location.timestamp)}'
                : 'Updated ${_timeAgo(location.timestamp)}',
          ),
          onTap: () => widget.onLocationSelected(location),
        ),
    };
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _locationFingerprint = _fingerprint(_validLocations);
    _lastSelectedLocationId = widget.selectedLocationId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showAllLocations();
    });
  }

  Future<void> _showAllLocations() async {
    final controller = _controller;
    final locations = _validLocations;
    if (controller == null || locations.isEmpty) return;

    if (locations.length == 1) {
      final location = locations.single;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
            zoom: 15,
          ),
        ),
      );
      return;
    }

    final bounds = _boundsFor(locations);
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 54));
  }

  LatLngBounds _boundsFor(List<FamilyLocation> locations) {
    var minLatitude = locations.first.latitude;
    var maxLatitude = minLatitude;
    var minLongitude = locations.first.longitude;
    var maxLongitude = minLongitude;

    for (final location in locations.skip(1)) {
      if (location.latitude < minLatitude) minLatitude = location.latitude;
      if (location.latitude > maxLatitude) maxLatitude = location.latitude;
      if (location.longitude < minLongitude) {
        minLongitude = location.longitude;
      }
      if (location.longitude > maxLongitude) {
        maxLongitude = location.longitude;
      }
    }

    if (minLatitude == maxLatitude) {
      minLatitude = (minLatitude - 0.005).clamp(-90.0, 90.0);
      maxLatitude = (maxLatitude + 0.005).clamp(-90.0, 90.0);
    }
    if (minLongitude == maxLongitude) {
      minLongitude = (minLongitude - 0.005).clamp(-180.0, 180.0);
      maxLongitude = (maxLongitude + 0.005).clamp(-180.0, 180.0);
    }

    return LatLngBounds(
      southwest: LatLng(minLatitude, minLongitude),
      northeast: LatLng(maxLatitude, maxLongitude),
    );
  }

  Future<void> _focusSelectedLocation() async {
    final controller = _controller;
    final selectedId = widget.selectedLocationId;
    if (controller == null || selectedId == null) return;
    for (final location in _validLocations) {
      if (location.id == selectedId || location.childId == selectedId) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(location.latitude, location.longitude),
              zoom: 16,
            ),
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final locations = _validLocations;
    final initialTarget = locations.isEmpty
        ? const LatLng(0, 0)
        : LatLng(locations.first.latitude, locations.first.longitude);

    return Container(
      height: 220,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceHighlight,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: locations.isEmpty ? 2 : 14,
            ),
            markers: _buildMarkers(),
            onMapCreated: _onMapCreated,
            mapType: MapType.normal,
            mapToolbarEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: false,
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(0.96),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${locations.length} ${locations.length == 1 ? 'child' : 'children'}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (locations.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Shared child locations will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 3,
              child: IconButton(
                tooltip: 'Show all children',
                onPressed: _showAllLocations,
                icon: Icon(Icons.center_focus_strong, color: colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(FamilyLocation location) {
    final name = location.childName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = location.childId;
    return 'Child (${id.length > 6 ? id.substring(0, 6) : id})';
  }

  String _timeAgo(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);
    if (age.inDays > 0) return '${age.inDays}d ago';
    if (age.inHours > 0) return '${age.inHours}h ago';
    if (age.inMinutes > 0) return '${age.inMinutes}m ago';
    return 'just now';
  }
}
