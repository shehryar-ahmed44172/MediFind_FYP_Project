import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/location/road_route_service.dart';

/// Road-following route line between the responder and the patient.
///
/// Recomputed only when the responder has moved noticeably (or every 30 s),
/// so live location updates don't hammer the routing server.
class RouteLine {
  final PolylineId id;
  final Color color;

  final ValueNotifier<Set<Polyline>> polylines = ValueNotifier<Set<Polyline>>({});
  final ValueNotifier<RoadRoute?> route = ValueNotifier<RoadRoute?>(null);

  LatLng? _lastFrom;
  LatLng? _lastTo;
  DateTime? _lastFetch;
  bool _loading = false;
  bool _disposed = false;

  RouteLine({this.id = const PolylineId('responder_route'), required this.color});

  void update(LatLng? from, LatLng? to) {
    if (_disposed || _loading || from == null || to == null) return;
    final movedFrom = _lastFrom == null ? double.infinity : RoadRouteService.distanceMeters(_lastFrom!, from);
    final movedTo = _lastTo == null ? double.infinity : RoadRouteService.distanceMeters(_lastTo!, to);
    final stale = _lastFetch == null || DateTime.now().difference(_lastFetch!) > const Duration(seconds: 30);
    if (movedFrom < 150 && movedTo < 50 && !stale) return;

    _loading = true;
    RoadRouteService.route(from, to).then((r) {
      _loading = false;
      if (_disposed) return;
      _lastFrom = from;
      _lastTo = to;
      _lastFetch = DateTime.now();
      route.value = r;
      polylines.value = {
        Polyline(
          polylineId: id,
          points: r.points,
          color: color,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          // Dashed when the router was unreachable (straight-line estimate)
          patterns: r.isFallback ? [PatternItem.dash(18), PatternItem.gap(10)] : const [],
        ),
      };
    }).catchError((_) {
      _loading = false;
    });
  }

  void clear() {
    if (_disposed) return;
    polylines.value = {};
    route.value = null;
  }

  void dispose() {
    _disposed = true;
    polylines.dispose();
    route.dispose();
  }
}
