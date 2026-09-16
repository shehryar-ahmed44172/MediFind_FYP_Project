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

  /// User-facing message used when no real position can be obtained.
  static const String unavailableMessage =
      'Unable to get your location. Turn on GPS and try again.';

  /// Get the device's REAL current location.
  ///
  /// Tries a fresh GPS fix first, then the last known position. It NEVER
  /// returns made-up coordinates: if neither is available a
  /// [LocationException] with a user-facing message is thrown, so an SOS is
  /// never sent with a fake location.
  Future<Position> getCurrentLocation({
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    try {
      // Step 1: Check if location service (GPS) is enabled at the OS level
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException(
          message: 'Location services are off. Turn on GPS to share your location.',
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
          message: 'Location permission is permanently denied. Enable it in app settings.',
          code: 'PERMISSION_PERMANENTLY_DENIED',
        );
      }
      if (permission == LocationPermission.denied) {
        throw LocationException(
          message: 'Location permission denied. MediFind needs your location to send help.',
          code: 'PERMISSION_DENIED',
        );
      }

      // Step 3: fresh fix with a timeout
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeLimit,
          ),
        );
        return _applyDebugOffset(pos);
      } catch (e) {
        debugPrint('Geolocator.getCurrentPosition failed/timed out: $e');
      }

      // Step 4: last known REAL position (may be slightly stale)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return _applyDebugOffset(lastKnown);
      }

      throw LocationException(
        message: unavailableMessage,
        code: 'LOCATION_UNAVAILABLE',
      );
    } catch (e) {
      if (e is LocationException) {
        rethrow;
      }
      throw LocationException(
        message: unavailableMessage,
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
