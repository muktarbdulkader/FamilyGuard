import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service providing reverse geocoding to retrieve readable Place, City, Village, and Country names
class GeocodingService {
  static final GeocodingService instance = GeocodingService._internal();
  GeocodingService._internal();

  static const MethodChannel _locationChannel = MethodChannel('com.example.flutter_study_app/location');
  final Map<String, String> _cache = {};

  /// Get formatted place name: "City/Village, Country" (e.g. "Maya City, Ethiopia" or "Addis Ababa, Ethiopia")
  Future<String?> getPlaceName(double latitude, double longitude) async {
    if (latitude == 0.0 && longitude == 0.0) return null;

    final cacheKey = '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // 1. Try native Android Geocoder first
    try {
      final dynamic raw = await _locationChannel.invokeMethod('getAddressFromCoordinates', {
        'latitude': latitude,
        'longitude': longitude,
      });

      if (raw is Map) {
        final city = (raw['city'] ?? '').toString().trim();
        final country = (raw['country'] ?? '').toString().trim();
        final display = (raw['displayName'] ?? raw['formattedAddress'] ?? '').toString().trim();

        String place;
        if (city.isNotEmpty && country.isNotEmpty) {
          place = '$city, $country';
        } else if (display.isNotEmpty) {
          place = display;
        } else {
          place = city.isNotEmpty ? city : country;
        }

        if (place.isNotEmpty) {
          _cache[cacheKey] = place;
          return place;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Native reverse geocoder exception: $e');
      }
    }

    // 2. Fallback: OpenStreetMap Nominatim reverse geocode via HttpClient
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&zoom=14&addressdetails=1',
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'FamilyGuardParentalApp/1.0 (familyguardian@studyapp.local)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              address['suburb'] ??
              address['county'] ??
              address['city_district'] ??
              address['hamlet'];
          final state = address['state'];
          final country = address['country'] ?? 'Ethiopia';

          String result;
          if (city != null && city.toString().trim().isNotEmpty) {
            result = '${city.toString().trim()}, ${country.toString().trim()}';
          } else if (state != null && state.toString().trim().isNotEmpty) {
            result = '${state.toString().trim()}, ${country.toString().trim()}';
          } else {
            result = data['display_name']?.toString() ?? '$country';
          }

          _cache[cacheKey] = result;
          client.close();
          return result;
        }
      }
      client.close();
    } catch (e) {
      if (kDebugMode) {
        print('Nominatim fallback geocode error: $e');
      }
    }

    return null;
  }
}
