import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapsService {
  /// Fetches LatLng for a given address using native geocoding with Nominatim fallback.
  static Future<LatLng?> getLatLngFromAddress(String address) async {
    if (address.trim().isEmpty) return null;

    // Try native geocoding first
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        print(
          'Native geocoded "$address" to ${location.latitude}, ${location.longitude}',
        );
        return LatLng(location.latitude, location.longitude);
      }
    } catch (e) {
      print('Native Geocoding error for address "$address": $e');
    }

    // Fallback to Nominatim (OpenStreetMap)
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&limit=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'RenoshApp/1.0 (contact@renosh.app)'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'] as String);
          final lng = double.tryParse(data[0]['lon'] as String);
          if (lat != null && lng != null) {
            print('Nominatim geocoded "$address" to $lat, $lng');
            return LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      print('Nominatim geocoding error for "$address": $e');
    }

    return null; // No fallback to dummy coords anymore
  }

  /// Calculates real road distance in kilometers using Google Distance Matrix API.
  static Future<double?> getRoadDistance(
    LatLng origin,
    LatLng destination,
  ) async {
    // Skip calculation for dummy/zero locations
    if ((origin.latitude == 0.0 && origin.longitude == 0.0) ||
        (destination.latitude == 0.0 && destination.longitude == 0.0)) {
      return null;
    }
    // Return null to let the UI show the Haversine estimate instead
    return null;
  }
}
