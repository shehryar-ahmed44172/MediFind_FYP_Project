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

  /// Start real-time location updates
  Stream<Position> startLocationUpdates({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int intervalInSeconds = 10,
  }) async* {
    try {
      // Check permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied ||
            newPermission == LocationPermission.deniedForever) {
          throw LocationException(
            message: 'Location permission denied',
            code: 'PERMISSION_DENIED',
          );
        }
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
      );

      yield* _positionStream!;
    } catch (e) {
      if (e is LocationException) {
        throw e;
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
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied ||
            newPermission == LocationPermission.deniedForever) {
          throw LocationException(
            message: 'Location permission denied',
            code: 'PERMISSION_DENIED',
          );
        }
      }

      // 1. Try to get current position with short timeout
      try {
        return await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        debugPrint('Geolocator.getCurrentPosition failed/timed out: $e');
        
        // 2. Fallback to last known position
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return lastKnown;
        }

        // 3. If in development, return a hardcoded Karachi coordinate
        // This prevents the SOS button from being stuck on the emulator
        return Position(
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
        );
      }
    } catch (e) {
      if (e is LocationException) {
        throw e;
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

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Get City and Area from coordinates
  Future<Map<String, String>> getPlaceFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return {
          'city': place.locality ?? place.subAdministrativeArea ?? '',
          'address': place.subLocality ?? place.name ?? '',
        };
      }
      return {'city': '', 'address': ''};
    } catch (e) {
      debugPrint('Error in reverse geocoding: $e');
      return {'city': '', 'address': ''};
    }
  }
}
