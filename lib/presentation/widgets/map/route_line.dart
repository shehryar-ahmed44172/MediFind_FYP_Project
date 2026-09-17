import 'dart:math' as math;

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
  // Two most recent positions, for the direction of travel
  LatLng? _prevPoint;
  LatLng? _olderPoint;
  LatLng? _lastTo;
  DateTime? _lastFetch;
  bool _loading = false;
  bool _disposed = false;

  RouteLine({this.id = const PolylineId('responder_route'), required this.color});

  void update(LatLng? from, LatLng? to) {
    if (_disposed || from == null || to == null) return;
    if (_prevPoint == null || RoadRouteService.distanceMeters(_prevPoint!, from) > 10) {
      _olderPoint = _prevPoint;
      _prevPoint = from;
    }
    if (_loading) return;
    final movedFrom = _lastFrom == null ? double.infinity : RoadRouteService.distanceMeters(_lastFrom!, from);
    final movedTo = _lastTo == null ? double.infinity : RoadRouteService.distanceMeters(_lastTo!, to);
    final stale = _lastFetch == null || DateTime.now().difference(_lastFetch!) > const Duration(seconds: 60);
    // Replacing the line makes the map redraw its overlays, so only re-route when the
    // responder has left the current route, has driven a good part of it, or it is old.
    final current = route.value;
    final offRoute = current == null || _distanceToLine(from, current.points) > 40;
    if (!offRoute && movedFrom < 400 && movedTo < 50 && !stale) return;

    // Direction of travel since the last route, when the responder has really moved
    final last = _olderPoint;
    double? heading;
    if (last != null && RoadRouteService.distanceMeters(last, from) > 10) {
      final lat1 = last.latitude * math.pi / 180, lat2 = from.latitude * math.pi / 180;
      final dLng = (from.longitude - last.longitude) * math.pi / 180;
      heading = (math.atan2(math.sin(dLng) * math.cos(lat2),
                      math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng)) *
                  180 / math.pi +
              360) %
          360;
    }

    _loading = true;
    RoadRouteService.route(from, to, heading: heading).then((r) {
      _loading = false;
      if (_disposed) return;
      _lastFrom = from;
      _lastTo = to;
      _lastFetch = DateTime.now();
      final points = _withoutStartHook(r.points);
      route.value = RoadRoute(
        points: points,
        distanceMeters: r.distanceMeters,
        durationSeconds: r.durationSeconds,
        isFallback: r.isFallback,
      );
      polylines.value = {
        Polyline(
          polylineId: id,
          points: points,
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

  /// Shortest distance in metres from [p] to the polyline.
  static double _distanceToLine(LatLng p, List<LatLng> points) {
    if (points.length < 2) return double.infinity;
    final cosLat = math.cos(p.latitude * math.pi / 180);
    var best = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final ax = (points[i].longitude - p.longitude) * 111320 * cosLat, ay = (points[i].latitude - p.latitude) * 110540;
      final bx = (points[i + 1].longitude - p.longitude) * 111320 * cosLat, by = (points[i + 1].latitude - p.latitude) * 110540;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final f = len2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0);
      final cx = ax + dx * f, cy = ay + dy * f;
      best = math.min(best, math.sqrt(cx * cx + cy * cy));
    }
    return best;
  }

  /// The router sometimes starts with a short loop (drive ahead, U-turn, come back)
  /// when the position sits on the other side of a divided road. Cut that loop so the
  /// line and the marker start where the responder really is.
  static List<LatLng> _withoutStartHook(List<LatLng> points) {
    if (points.length < 3) return points;
    var travelled = 0.0;
    for (var i = 1; i < points.length; i++) {
      travelled += RoadRouteService.distanceMeters(points[i - 1], points[i]);
      if (travelled > 250) break;
      if (travelled > 30 && RoadRouteService.distanceMeters(points[i], points.first) < 20) {
        return [points.first, ...points.sublist(i + 1 < points.length ? i + 1 : i)];
      }
    }
    return points;
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
