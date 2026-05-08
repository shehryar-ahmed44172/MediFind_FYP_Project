import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/utils/exceptions.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  Stream<Position>? _positionStream;
  
  // Debug offsets for testing distance between devices
  static double debugLatOffset = 0.0;
  static double debugLngOffset = 0.0;

  Position _applyDebugOffset(Position pos) {
    if (debugLatOffset == 0 && debugLngOffset == 0) return pos;
    return Position(
      latitude: pos.latitude + debugLatOffset,
      longitude: pos.longitude + debugLngOffset,
      timestamp: pos.timestamp,
      accuracy: pos.accuracy,
      altitude: pos.altitude,
      heading: pos.heading,
      speed: pos.speed,
      speedAccuracy: pos.speedAccuracy,
      altitudeAccuracy: pos.altitudeAccuracy,
      headingAccuracy: pos.headingAccuracy,
    );
  }

  /// Start real-time location updates
  Stream<Position> startLocationUpdates({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int intervalInSeconds = 10,
  }) async* {
    try {
      // Check service enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException(
          message: 'Location services are disabled.',
          code: 'LOCATION_DISABLED',
        );
      }

      // Check permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationException(
          message: 'Location permission is permanently denied.',
          code: 'PERMISSION_PERMANENTLY_DENIED',
        );
      }
      if (permission == LocationPermission.denied) {
        throw LocationException(
          message: 'Location permission denied.',
          code: 'PERMISSION_DENIED',
        );
      }

      // Define location settings based on platform
      late LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: accuracy,
          distanceFilter: 0,
          intervalDuration: Duration(seconds: intervalInSeconds),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: accuracy,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: true,
        );
      } else {
        locationSettings = LocationSettings(
          accuracy: accuracy,
          distanceFilter: 0,
        );
      }

      // Start position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).map((pos) => _applyDebugOffset(pos));

      yield* _positionStream!;
    } catch (e) {
      if (e is LocationException) {
        rethrow;
      }
      throw LocationException(
        message: 'Failed to start location updates',
        originalException: e,
      );
    }
  }

  /// Get current location once with fallback
  Future<Position> getCurrentLocation() async {
    try {
      // Step 1: Check if location service (GPS) is enabled at the OS level
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException(
          message: 'Location services are disabled. Please enable GPS.',
          code: 'LOCATION_DISABLED',
        );
      }

      // Step 2: Check / request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationException(
          message: 'Location permission is permanently denied.',
          code: 'PERMISSION_PERMANENTLY_DENIED',
        );
      }
      if (permission == LocationPermission.denied) {
        throw LocationException(
          message: 'Location permission denied.',
          code: 'PERMISSION_DENIED',
        );
      }

      // 1. Try to get current position with short timeout
      try {
        final pos = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 5),
        );
        return _applyDebugOffset(pos);
      } catch (e) {
        debugPrint('Geolocator.getCurrentPosition failed/timed out: $e');
        
        // 2. Fallback to last known position
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return _applyDebugOffset(lastKnown);
        }

        // 3. If in development, return a hardcoded Karachi coordinate
        // This prevents the SOS button from being stuck on the emulator
        return _applyDebugOffset(Position(
          latitude: 24.8607,
          longitude: 67.0011,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        ));
      }
    } catch (e) {
      if (e is LocationException) {
        rethrow;
      }
      throw LocationException(
        message: 'Failed to access location services',
        originalException: e,
      );
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Stop location updates
  void stopLocationUpdates() {
    _positionStream = null;
  }

  /// Calculate distance between two coordinates in meters
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Open location settings (so the user can enable GPS)
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (so the user can grant permanently-denied permission)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Get City and Area from coordinates
  Future<Map<String, String>> getPlaceFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        
        // Greedily try to find a house/flat number
        String houseNo = place.subThoroughfare ?? '';
        String street = place.thoroughfare ?? '';
        String name = place.name ?? '';
        
        // Fallback: If subThoroughfare is empty, check if 'name' looks like a number or building name
        if (houseNo.isEmpty && name.isNotEmpty && name != street) {
          houseNo = name;
        }

        return {
          'city': place.locality ?? place.subAdministrativeArea ?? '',
          'address': street.isNotEmpty ? street : (place.subLocality ?? name),
          'houseNumber': houseNo,
        };
      }
      return {'city': '', 'address': '', 'houseNumber': ''};
    } catch (e) {
      debugPrint('Error in reverse geocoding: $e');
      return {'city': '', 'address': '', 'houseNumber': ''};
    }
  }
}
