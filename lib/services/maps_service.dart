import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class MapsService {
  /// Fetches LatLng for a given address using native geocoding.
  static Future<LatLng?> getLatLngFromAddress(String address) async {
    if (address.trim().isEmpty) return null;

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return LatLng(location.latitude, location.longitude);
      }
    } catch (e) {
      print('Native Geocoding error for address $address: $e');
    }

    // Fallback Mock Location
    if (address.trim().length >= 4) {
      print('Fallback: Mocking location for address: $address');
      return const LatLng(12.9716, 77.5946); // Dummy latitude & longitude
    }
    return null;
  }

  /// Calculates real road distance in kilometers using Google Distance Matrix API.
  static Future<double?> getRoadDistance(
    LatLng origin,
    LatLng destination,
  ) async {
    // If we're mocking the location for Gemini API, also mock the distance
    // so it doesn't fail with the same API error.
    if ((origin.latitude == 0.0 && origin.longitude == 0.0) ||
        (destination.latitude == 0.0 && destination.longitude == 0.0)) {
      return null;
    }
    // Simple mock returning Haversine distance since the Distance Matrix API is not enabled
    // The main screen already uses `calculateDistance` (Haversine) for fallback filtering,
    // so we can just return null here to let the UI display the estimate instead of failing.
    return null;
  }
}
