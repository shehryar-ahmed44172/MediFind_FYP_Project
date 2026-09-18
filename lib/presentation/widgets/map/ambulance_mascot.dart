import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Motorbike-ambulance mascot (InDrive-style top-down vehicle marker).
//
// Drawn with a CustomPainter, rendered ONCE per frame variant into a cached
// BitmapDescriptor (two frames: light bar red-left / blue-left) and reused by
// every map. The bike faces north (up) so `Marker.rotation` = bearing.
// ─────────────────────────────────────────────────────────────────────────────

class AmbulanceMascot {
  AmbulanceMascot._();

  /// Logical size of the marker on the map (dp).
  static const double logicalSize = 64;
  static const double _pixelRatio = 3;

  static List<BitmapDescriptor>? _frames;
  static Future<List<BitmapDescriptor>>? _loading;

  /// Pre-rendered PNG sizes in assets/map (see tool/generate_map_mascot_test.dart).
  static const List<double> assetPixelRatios = [2, 2.5, 3, 3.5, 4];

  static String assetPath(double ratio, bool flash) =>
      'assets/map/mascot_${ratio.toString().replaceAll('.', '_')}x_${flash ? 1 : 0}.png';

  /// Two pre-rendered frames for the siren flash. Cached for the app session.
  static Future<List<BitmapDescriptor>> frames() {
    final cached = _frames;
    if (cached != null) return Future.value(cached);
    return _loading ??= _render().then((f) {
      _frames = f;
      _loading = null;
      return f;
    });
  }

  static Future<List<BitmapDescriptor>> _render() async {
    // Android: asset icons are cached by the Maps SDK. A bytes icon is decoded again on
    // every marker move, which costs frames and makes the moving marker blink.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final views = ui.PlatformDispatcher.instance.views;
      final dpr = views.isEmpty ? _pixelRatio : views.first.devicePixelRatio;
      final ratio = assetPixelRatios.reduce((a, b) => (a - dpr).abs() <= (b - dpr).abs() ? a : b);
      return [false, true]
          .map((flash) => AssetMapBitmap(assetPath(ratio, flash), bitmapScaling: MapBitmapScaling.none))
          .toList();
    }
    return Future.wait([_renderFrame(false), _renderFrame(true)]);
  }

  static Future<BitmapDescriptor> _renderFrame(bool flash) async {
    final px = (logicalSize * _pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
    canvas.scale(_pixelRatio);
    MascotTopDownPainter(flash: flash).paint(canvas, const Size(logicalSize, logicalSize));
    final image = await recorder.endRecording().toImage(px, px);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: _pixelRatio,
    );
  }
}

/// Top-down motorbike ambulance: front wheel up, rider helmet, white cargo box
/// with red cross, and a light bar whose colours swap when [flash] is true.
class MascotTopDownPainter extends CustomPainter {
  final bool flash;
  const MascotTopDownPainter({this.flash = false});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64; // design grid is 64x64
    canvas.save();
    canvas.scale(s);

    const cx = 32.0;

    // Soft pulse halo (brighter on flash frame)
    canvas.drawCircle(
      const Offset(cx, 33),
      flash ? 29 : 26,
      Paint()..color = const Color(0xFFEF4444).withValues(alpha: flash ? 0.20 : 0.12),
    );

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 11, 9, cx + 11, 59), const Radius.circular(10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final tyre = Paint()..color = const Color(0xFF111827);
    // Front wheel (top) and rear wheel (bottom)
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 3.2, 5, cx + 3.2, 17), const Radius.circular(3)), tyre);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 3.6, 48, cx + 3.6, 60), const Radius.circular(3)), tyre);

    // Handlebar
    canvas.drawLine(
      const Offset(cx - 10, 17),
      const Offset(cx + 10, 17),
      Paint()
        ..color = const Color(0xFF374151)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    // Mirrors
    final mirror = Paint()..color = const Color(0xFF9CA3AF);
    canvas.drawCircle(const Offset(cx - 10, 17), 1.8, mirror);
    canvas.drawCircle(const Offset(cx + 10, 17), 1.8, mirror);

    // Bike body (red fairing)
    final body = RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 6, 12, cx + 6, 34), const Radius.circular(6));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFEF4444));
    // Windscreen highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 4, 13.5, cx + 4, 17.5), const Radius.circular(2)),
      Paint()..color = const Color(0xFFE2F0F3).withValues(alpha: 0.9),
    );

    // Rider: shoulders + helmet
    canvas.drawOval(const Rect.fromLTRB(cx - 8, 21, cx + 8, 32), Paint()..color = const Color(0xFF1F2937));
    canvas.drawCircle(const Offset(cx, 24.5), 5.2, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(cx, 24.5),
      5.2,
      Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Helmet visor (facing forward/up)
    canvas.drawArc(
      const Rect.fromLTRB(cx - 4, 20, cx + 4, 28),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = const Color(0xFF2496A7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // Cargo box (white) with red cross
    final box = RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 11, 34, cx + 11, 54), const Radius.circular(4));
    canvas.drawRRect(box, Paint()..color = Colors.white);
    canvas.drawRRect(
      box,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final cross = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx, 45), width: 12, height: 4), const Radius.circular(1)), cross);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx, 45), width: 4, height: 12), const Radius.circular(1)), cross);

    // Light bar on the front edge of the box
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(cx - 9, 33, cx + 9, 37.5), const Radius.circular(2)),
      Paint()..color = const Color(0xFF374151),
    );
    final left = flash ? const Color(0xFF2891C2) : const Color(0xFFEF4444);
    final right = flash ? const Color(0xFFEF4444) : const Color(0xFF2891C2);
    for (final entry in [
      MapEntry(const Offset(cx - 5, 35.2), left),
      MapEntry(const Offset(cx + 5, 35.2), right),
    ]) {
      canvas.drawCircle(
        entry.key,
        4.5,
        Paint()
          ..color = entry.value.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(entry.key, 2.3, Paint()..color = entry.value);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(MascotTopDownPainter oldDelegate) => oldDelegate.flash != flash;
}

/// Small animated mascot illustration for cards (e.g. "Responder assigned").
class AmbulanceMascotBadge extends StatefulWidget {
  final double size;
  const AmbulanceMascotBadge({super.key, this.size = 48});

  @override
  State<AmbulanceMascotBadge> createState() => _AmbulanceMascotBadgeState();
}

class _AmbulanceMascotBadgeState extends State<AmbulanceMascotBadge> {
  Timer? _timer;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _flash = !_flash);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Motorbike ambulance',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: MascotTopDownPainter(flash: _flash),
        ),
      ),
    );
  }
}

/// Drives one mascot marker on a GoogleMap:
///  * smoothly interpolates between position updates (~1 s),
///  * rotates to the bearing of travel,
///  * alternates two siren frames every 500 ms.
///
/// Exposes a [ValueListenable] so only the map rebuilds (wrap the GoogleMap
/// in a `ValueListenableBuilder`), and throttles interpolation to ~20 fps.
class AnimatedMascotMarker {
  final MarkerId markerId;
  final InfoWindow infoWindow;
  final Duration moveDuration;

  final ValueNotifier<Marker?> marker = ValueNotifier<Marker?>(null);

  /// Frame interval of the glide (~30 fps).
  static const Duration _tick = Duration(milliseconds: 33);

  /// A GPS fix further than this from the road route is followed in a straight line.
  static const double _maxRouteOffsetMeters = 40;

  List<BitmapDescriptor>? _frames;
  LatLng? _current;
  LatLng? _from;
  LatLng? _to;
  double _bearing = 0;
  double _targetBearing = 0;
  bool _flash = false;
  DateTime? _moveStart;
  DateTime? _lastUpdateAt;
  Duration _currentMoveDuration = const Duration(milliseconds: 1000);
  Timer? _moveTimer;
  Timer? _flashTimer;
  bool _disposed = false;

  // Road route the responder is driving (from the route line); glides follow it.
  List<LatLng>? _path;
  List<double> _cumulative = const [];
  // A new route is applied at the next GPS fix, never in the middle of a glide
  List<LatLng>? _pendingPath;
  bool _hasPendingPath = false;
  double? _fromAlong;
  double? _toAlong;
  // Gap between the marker and its spot on the road at glide start; fades out
  double _startDLat = 0;
  double _startDLng = 0;
  // Recent drawn positions: the heading follows the actual motion on screen
  final List<LatLng> _trail = [];

  AnimatedMascotMarker({
    this.markerId = const MarkerId('responder_mascot'),
    this.infoWindow = const InfoWindow(title: 'Responder'),
    this.moveDuration = const Duration(milliseconds: 1000),
    bool flashSiren = true,
  }) {
    AmbulanceMascot.frames().then((frames) {
      if (_disposed) return;
      _frames = frames;
      _publish();
    });
    if (flashSiren) {
      _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _flash = !_flash;
        if (_moveTimer?.isActive != true) _publish(); // the glide publishes every frame anyway
      });
    }
  }

  LatLng? get position => _to ?? _current;

  /// Where the marker is drawn right now (mid-glide).
  LatLng? get displayPosition => _current;
  double get bearing => _bearing;

  /// Road geometry between responder and patient. Glides between GPS fixes follow
  /// it instead of cutting straight across blocks. Pass null to clear.
  void setPath(List<LatLng>? points) {
    if (_disposed) return;
    _pendingPath = points;
    _hasPendingPath = true;
  }

  void _applyPendingPath() {
    if (!_hasPendingPath) return;
    _hasPendingPath = false;
    final points = _pendingPath;
    _pendingPath = null;
    if (points == null || points.length < 2) {
      _path = null;
      _cumulative = const [];
      return;
    }
    final cumulative = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cumulative[i] = cumulative[i - 1] + _distance(points[i - 1], points[i]);
    }
    _path = points;
    _cumulative = cumulative;
  }

  static const double _teleportMeters = 20000;

  /// Move to [target]. The first call places the marker without animation.
  void moveTo(LatLng target) {
    if (_disposed) return;
    final current = _current;
    if (current == null) {
      _current = target;
      _to = target;
      _publish();
      return;
    }
    if (_sameSpot(current, target)) return;
    // A jump of many km is a GPS correction (e.g. the first good fix after a bad
    // one), not driving: place it directly instead of gliding across the map.
    if (_distance(current, target) > _teleportMeters) {
      _moveTimer?.cancel();
      _from = null;
      _fromAlong = null;
      _toAlong = null;
      _current = target;
      _to = target;
      _lastUpdateAt = DateTime.now();
      _publish();
      return;
    }

    _from = current;
    _to = target;
    _fromAlong = null;
    _toAlong = null;
    _applyPendingPath();

    // Follow the road when both ends sit on the route and the move goes forward.
    final path = _path;
    if (path != null) {
      final a = _project(current, preferLater: true);
      final b = _project(target);
      final straight = _distance(current, target);
      if (a.offset < _maxRouteOffsetMeters &&
          b.offset < _maxRouteOffsetMeters &&
          b.along >= a.along - 5 &&
          // Road distance close to the straight gap: skips U-turn hooks and wrong matches
          b.along - a.along <= straight * 1.8 + 20 &&
          !_reverses(a.along, math.max(a.along, b.along), bearingBetween(current, target))) {
        _fromAlong = a.along;
        _toAlong = math.max(a.along, b.along);
        final onRoad = _pointAt(a.along);
        _startDLat = current.latitude - onRoad.latitude;
        _startDLng = current.longitude - onRoad.longitude;
      }
    }
    if (_fromAlong == null && _distance(current, target) > 6) _targetBearing = bearingBetween(current, target);

    // Live location arrives every few seconds: glide over the whole gap so the
    // bike keeps moving continuously instead of jumping and then waiting.
    final now = DateTime.now();
    final gap = _lastUpdateAt == null ? moveDuration : now.difference(_lastUpdateAt!);
    _lastUpdateAt = now;
    final ms = gap.inMilliseconds.clamp(moveDuration.inMilliseconds, 6000);
    _currentMoveDuration = Duration(milliseconds: ms);
    _moveStart = now;
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(_tick, (t) {
      final start = _moveStart;
      final from = _from;
      final to = _to;
      if (_disposed || start == null || from == null || to == null) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final raw = (elapsed / _currentMoveDuration.inMilliseconds).clamp(0.0, 1.0);
      final fromAlong = _fromAlong;
      final toAlong = _toAlong;
      if (fromAlong != null && toAlong != null && _path != null) {
        // Constant speed along the road geometry
        final along = fromAlong + (toAlong - fromAlong) * raw;
        final onRoad = _pointAt(along);
        // Ends on the road point of the fix (GPS can sit a few metres off the road)
        _current = LatLng(onRoad.latitude + _startDLat * (1 - raw), onRoad.longitude + _startDLng * (1 - raw));
      } else {
        _current = LatLng(
          from.latitude + (to.latitude - from.latitude) * raw,
          from.longitude + (to.longitude - from.longitude) * raw,
        );
      }
      // Heading from the last ~0.4 s of real movement, eased instead of snapping
      _trail.add(_current!);
      if (_trail.length > 12) _trail.removeAt(0);
      if (_distance(_trail.first, _current!) > 4) _targetBearing = bearingBetween(_trail.first, _current!);
      _bearing = _lerpAngle(_bearing, _targetBearing, 0.18);
      _publish();
      if (raw >= 1 && _angleDiff(_bearing, _targetBearing).abs() < 1) t.cancel();
    });
  }

  /// Closest spot on the path. With [preferLater], a later pass of the road that is
  /// about as close wins (the marker has already driven the earlier one).
  ({double along, double offset}) _project(LatLng p, {bool preferLater = false}) {
    final path = _path!;
    var bestAlong = 0.0;
    var bestOffset = double.infinity;
    final cosLat = math.cos(p.latitude * math.pi / 180);
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      // Local flat projection in metres around p
      final ax = (a.longitude - p.longitude) * 111320 * cosLat, ay = (a.latitude - p.latitude) * 110540;
      final bx = (b.longitude - p.longitude) * 111320 * cosLat, by = (b.latitude - p.latitude) * 110540;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final f = len2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0);
      final cx = ax + dx * f, cy = ay + dy * f;
      final offset = math.sqrt(cx * cx + cy * cy);
      final along = _cumulative[i] + (_cumulative[i + 1] - _cumulative[i]) * f;
      if (offset < bestOffset - 8 || (offset < bestOffset + (preferLater ? 8 : 0) && (preferLater ? along > bestAlong : offset < bestOffset))) {
        bestOffset = math.min(offset, bestOffset);
        bestAlong = along;
      }
    }
    return (along: bestAlong, offset: bestOffset);
  }

  /// True when the road between two positions turns back against the direction of
  /// travel (a U-turn hook), which would make the marker drive backwards.
  bool _reverses(double fromAlong, double toAlong, double travelBearing) {
    const step = 10.0;
    var prev = _pointAt(fromAlong);
    for (var s = fromAlong + step; s <= toAlong; s += step) {
      final next = _pointAt(s);
      if (_distance(prev, next) > 2 && _angleDiff(travelBearing, bearingBetween(prev, next)).abs() > 110) {
        return true;
      }
      prev = next;
    }
    return false;
  }

  LatLng _pointAt(double along) {
    final path = _path!;
    final c = _cumulative;
    if (along <= 0) return path.first;
    if (along >= c.last) return path.last;
    var lo = 0, hi = c.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (c[mid] <= along) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final seg = c[hi] - c[lo];
    final f = seg == 0 ? 0.0 : (along - c[lo]) / seg;
    return LatLng(
      path[lo].latitude + (path[hi].latitude - path[lo].latitude) * f,
      path[lo].longitude + (path[hi].longitude - path[lo].longitude) * f,
    );
  }

  static double _angleDiff(double from, double to) => ((to - from + 540) % 360) - 180;

  static double _lerpAngle(double from, double to, double t) => (from + _angleDiff(from, to) * t + 360) % 360;

  static double _distance(LatLng a, LatLng b) {
    final cosLat = math.cos((a.latitude + b.latitude) / 2 * math.pi / 180);
    final dx = (b.longitude - a.longitude) * 111320 * cosLat;
    final dy = (b.latitude - a.latitude) * 110540;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _publish() {
    if (_disposed) return;
    final frames = _frames;
    final pos = _current;
    if (frames == null || pos == null) return;
    marker.value = Marker(
      markerId: markerId,
      position: pos,
      icon: frames[_flash ? 1 : 0],
      rotation: _bearing,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndexInt: 2,
      infoWindow: infoWindow,
    );
  }

  static bool _sameSpot(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-6 && (a.longitude - b.longitude).abs() < 1e-6;

  /// Initial compass bearing in degrees (0 = north) from [a] to [b].
  static double bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void dispose() {
    _disposed = true;
    _moveTimer?.cancel();
    _flashTimer?.cancel();
    marker.dispose();
  }
}
