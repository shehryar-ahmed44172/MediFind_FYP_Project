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

  List<BitmapDescriptor>? _frames;
  LatLng? _current;
  LatLng? _from;
  LatLng? _to;
  double _bearing = 0;
  bool _flash = false;
  DateTime? _moveStart;
  Timer? _moveTimer;
  Timer? _flashTimer;
  bool _disposed = false;

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
        _publish();
      });
    }
  }

  LatLng? get position => _to ?? _current;
  double get bearing => _bearing;

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

    _bearing = bearingBetween(current, target);
    _from = current;
    _to = target;
    _moveStart = DateTime.now();
    _moveTimer?.cancel();
    _moveTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      final start = _moveStart;
      final from = _from;
      final to = _to;
      if (start == null || from == null || to == null) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final raw = (elapsed / moveDuration.inMilliseconds).clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(raw);
      _current = LatLng(
        from.latitude + (to.latitude - from.latitude) * eased,
        from.longitude + (to.longitude - from.longitude) * eased,
      );
      _publish();
      if (raw >= 1) t.cancel();
    });
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
