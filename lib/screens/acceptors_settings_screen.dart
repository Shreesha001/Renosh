import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AcceptorSettingsScreen extends StatefulWidget {
  const AcceptorSettingsScreen({super.key});

  @override
  _AcceptorSettingsScreenState createState() => _AcceptorSettingsScreenState();
}

class _AcceptorSettingsScreenState extends State<AcceptorSettingsScreen> {
  double _maxDistanceKm = 50;
  bool _isLoading = false;
  bool _isFetchingGPS = false;
  String _statusMessage = '';
  bool _isError = false;

  double? _latitude;
  double? _longitude;
  String _locationLabel = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        final data = doc.data()!;
        final loaded = (data['maxDistanceKm'] as num?)?.toDouble() ?? 50;
        final loc = data['location'];
        setState(() {
          _maxDistanceKm = loaded.clamp(1.0, 150.0);
          if (loc != null) {
            _latitude = (loc['latitude'] as num?)?.toDouble();
            _longitude = (loc['longitude'] as num?)?.toDouble();
            if (_latitude != null && _longitude != null) {
              _locationLabel =
                  'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}';
            }
          }
        });
        // Try reverse-geocoding to show a friendly address label
        if (_latitude != null && _longitude != null) {
          _reverseGeocode(_latitude!, _longitude!);
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [
          p.subLocality,
          p.locality,
          p.postalCode,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        if (parts.isNotEmpty) {
          setState(() => _locationLabel = parts);
        }
      }
    } catch (_) {}
  }

  Future<void> _useDeviceGPS() async {
    setState(() {
      _isFetchingGPS = true;
      _statusMessage = '';
      _isError = false;
    });

    try {
      // Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _statusMessage =
              'Location permission denied. Please enable in phone settings.';
          _isError = true;
        });
        return;
      }

      // Check if location service is on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage =
              'Please turn on Location Services in your phone settings.';
          _isError = true;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationLabel =
            'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}';
        _statusMessage = 'GPS location captured successfully!';
        _isError = false;
      });

      // Try to show a human-readable address
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error getting GPS location: $e';
        _isError = true;
      });
      debugPrint('GPS error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingGPS = false);
    }
  }

  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_latitude == null || _longitude == null) {
      setState(() {
        _statusMessage = 'Please set your location first using the GPS button.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'maxDistanceKm': _maxDistanceKm,
        'location': {'latitude': _latitude, 'longitude': _longitude},
      }, SetOptions(merge: true));

      debugPrint(
        'Saved: lat=$_latitude, lng=$_longitude, maxDist=$_maxDistanceKm',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settings saved!',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF39FF14),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error saving: $e';
        _isError = true;
      });
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool locationSet = _latitude != null && _longitude != null;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  const Color(0xFF1A3C34).withOpacity(0.95),
                  const Color(0xFF2D2D2D).withOpacity(0.85),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFFF9F7F3),
                            size: 28,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Settings',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF9F7F3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Location Section
                    Text(
                      'Your Location',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF9F7F3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your location is used to find nearby donations. Tap the button below to use your device GPS.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFB0B0B0),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // GPS Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isFetchingGPS ? null : _useDeviceGPS,
                        icon:
                            _isFetchingGPS
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1A3C34),
                                  ),
                                )
                                : const Icon(Icons.my_location),
                        label: Text(
                          _isFetchingGPS
                              ? 'Getting GPS location...'
                              : 'Use My Current GPS Location',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF39FF14),
                          foregroundColor: const Color(0xFF1A3C34),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Location Status
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            locationSet
                                ? const Color(0xFF39FF14).withOpacity(0.10)
                                : const Color(0xFFFF4A4A).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              locationSet
                                  ? const Color(0xFF39FF14)
                                  : const Color(0xFFFF4A4A),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            locationSet
                                ? Icons.check_circle
                                : Icons.location_off,
                            color:
                                locationSet
                                    ? const Color(0xFF39FF14)
                                    : const Color(0xFFFF4A4A),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locationSet
                                  ? '📍 $_locationLabel'
                                  : 'Location not set — tap button above',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color:
                                    locationSet
                                        ? const Color(0xFF39FF14)
                                        : const Color(0xFFB0B0B0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status / error message
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color:
                              _isError
                                  ? const Color(0xFFFF4A4A)
                                  : const Color(0xFF39FF14),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Distance Range
                    Text(
                      'Maximum Distance Range',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF9F7F3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Show donations within this radius (1–150 km)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFB0B0B0),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbColor: const Color(0xFF39FF14),
                        activeTrackColor: const Color(0xFF39FF14),
                        inactiveTrackColor: const Color(
                          0xFFB0B0B0,
                        ).withOpacity(0.3),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        valueIndicatorColor: const Color(0xFF39FF14),
                        valueIndicatorTextStyle: GoogleFonts.inter(
                          color: const Color(0xFF1A3C34),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Slider(
                        value: _maxDistanceKm,
                        min: 1,
                        max: 150,
                        divisions: 149,
                        label: '${_maxDistanceKm.round()} km',
                        onChanged:
                            (value) => setState(() => _maxDistanceKm = value),
                      ),
                    ),
                    Text(
                      'Current range: ${_maxDistanceKm.round()} km',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF9F7F3),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF39FF14),
                          foregroundColor: const Color(0xFF1A3C34),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1A3C34),
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'Save Settings',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
