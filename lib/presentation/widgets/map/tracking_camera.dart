import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/location/road_route_service.dart';

/// Camera for live-tracking maps.
///
/// Moving the camera on every GPS fix makes the map lurch every few seconds while
/// the responder marker is still gliding. This keeps the patient and responder in
/// view and only moves when one of them nears the edge, or when the view has become
/// much wider than needed (so it zooms in as the responder approaches).
class TrackingCamera {
  static const Duration _minGap = Duration(seconds: 4);
  static const Duration _animation = Duration(milliseconds: 900);

  DateTime? _lastMove;
  bool _moving = false;

  Future<void> keepInView(
    GoogleMapController? controller, {
    required LatLng responder,
    LatLng? patient,
    bool force = false,
  }) async {
    if (controller == null || _moving) return;
    try {
      final region = await controller.getVisibleRegion();
      final now = DateTime.now();
      final recentlyMoved = _lastMove != null && now.difference(_lastMove!) < _minGap;

      final responderVisible = _insideInset(region, responder);
      final patientVisible = patient == null || _insideInset(region, patient);
      final viewSpan = math.max(
        (region.northeast.latitude - region.southwest.latitude).abs(),
        (region.northeast.longitude - region.southwest.longitude).abs(),
      );
      final pairSpan = patient == null
          ? 0.0
          : math.max((patient.latitude - responder.latitude).abs(), (patient.longitude - responder.longitude).abs());
      final tooWide = patient != null && pairSpan < viewSpan * 0.22 && viewSpan > 0.006;

      final needed = !responderVisible || !patientVisible || tooWide;
      if (!force && (!needed || (recentlyMoved && responderVisible && patientVisible))) return;

      _moving = true;
      _lastMove = now;
      final CameraUpdate update;
      if (patient == null) {
        update = CameraUpdate.newLatLng(responder);
      } else if (RoadRouteService.distanceMeters(patient, responder) < 400) {
        update = CameraUpdate.newLatLngZoom(
          LatLng((patient.latitude + responder.latitude) / 2, (patient.longitude + responder.longitude) / 2),
          16,
        );
      } else {
        update = CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(math.min(patient.latitude, responder.latitude), math.min(patient.longitude, responder.longitude)),
            northeast: LatLng(math.max(patient.latitude, responder.latitude), math.max(patient.longitude, responder.longitude)),
          ),
          72,
        );
      }
      await controller.animateCamera(update, duration: _animation);
    } catch (e) {
      debugPrint('TrackingCamera: camera update skipped: $e');
    } finally {
      _moving = false;
    }
  }

  static bool _insideInset(LatLngBounds region, LatLng p) {
    final latPad = (region.northeast.latitude - region.southwest.latitude) * 0.15;
    final lngPad = (region.northeast.longitude - region.southwest.longitude) * 0.15;
    return p.latitude > region.southwest.latitude + latPad &&
        p.latitude < region.northeast.latitude - latPad &&
        p.longitude > region.southwest.longitude + lngPad &&
        p.longitude < region.northeast.longitude - lngPad;
  }
}
