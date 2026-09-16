import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// A driving route that follows real roads.
class RoadRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  /// True when the router was unreachable and [points] is a straight line.
  final bool isFallback;

  const RoadRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isFallback = false,
  });
}

/// Road-following routes from the OSRM routing engine (OpenStreetMap data,
/// no API key). Used for the route line on tracking maps and for the
/// search animation. Falls back to a straight line when offline.
///
/// Note: the public OSRM demo server is fine for demos; production should
/// point [baseUrl] at a self-hosted OSRM instance.
class RoadRouteService {
  RoadRouteService._();

  static const String baseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static final Map<String, RoadRoute> _cache = {};

  static Future<RoadRoute> route(LatLng from, LatLng to) async {
    final key = '${_round(from)}|${_round(to)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        '$baseUrl/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final coords = ((r['geometry'] as Map)['coordinates'] as List)
              .map((c) => LatLng((c as List)[1].toDouble(), c[0].toDouble()))
              .toList();
          if (coords.length >= 2) {
            final route = RoadRoute(
              points: coords,
              distanceMeters: (r['distance'] as num).toDouble(),
              durationSeconds: (r['duration'] as num).toDouble(),
            );
            if (_cache.length > 50) _cache.clear();
            _cache[key] = route;
            return route;
          }
        }
      }
    } catch (e) {
      debugPrint('[RoadRoute] falling back to straight line: $e');
    }

    final meters = distanceMeters(from, to);
    return RoadRoute(
      points: [from, to],
      distanceMeters: meters,
      durationSeconds: meters / (40000 / 3600),
      isFallback: true,
    );
  }

  /// Position [meters] along [points] (clamped to the end).
  static LatLng pointAlong(List<LatLng> points, double meters) {
    if (points.isEmpty) throw ArgumentError('empty route');
    var remaining = meters;
    for (var i = 0; i < points.length - 1; i++) {
      final seg = distanceMeters(points[i], points[i + 1]);
      if (remaining <= seg && seg > 0) {
        final f = remaining / seg;
        return LatLng(
          points[i].latitude + (points[i + 1].latitude - points[i].latitude) * f,
          points[i].longitude + (points[i + 1].longitude - points[i].longitude) * f,
        );
      }
      remaining -= seg;
    }
    return points.last;
  }

  static double lengthMeters(List<LatLng> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += distanceMeters(points[i], points[i + 1]);
    }
    return total;
  }

  static double distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static String _round(LatLng p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
}
