import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapUtils {
  // Static caches — drawn once per app session, reused on every subsequent call.
  static BitmapDescriptor? _cachedAmbulanceMarker;
  static BitmapDescriptor? _cachedPatientMarker;
  static BitmapDescriptor? _cachedConfirmedResponderMarker;

  // ─── Ambulance / Responder Marker ─────────────────────────────────────────
  // Canvas-drawn — no PNG file needed.
  // Shows a teal circle with white medical cross + soft glow ring.
  // Pass [heading] (0-360) to rotate the direction indicator arrow.
  static Future<BitmapDescriptor> getAmbulanceMarker({
    Color color = const Color(0xFF0E9AA7),
    double heading = 0,
  }) async {
    if (heading == 0 && _cachedAmbulanceMarker != null) return _cachedAmbulanceMarker!;
    const double size = 90.0;
    const double cx = size / 2;
    const double cy = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // ── 1. Outer soft glow ──────────────────────────────────────────────────
    final glowPaint = Paint()
      ..color = color.withOpacity(0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(cx, cy), 38, glowPaint);

    // ── 2. Drop shadow ──────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(cx, cy + 3), 28, shadowPaint);

    // ── 3. Outer coloured ring ───────────────────────────────────────────────
    final ringPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), 32, ringPaint);

    // ── 4. Main filled circle ────────────────────────────────────────────────
    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), 26, bgPaint);

    // ── 5. White inner circle ────────────────────────────────────────────────
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), 19, innerPaint);

    // ── 6. Medical cross (teal) ──────────────────────────────────────────────
    final crossPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy), width: 22, height: 8),
        const Radius.circular(3),
      ),
      crossPaint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy), width: 8, height: 22),
        const Radius.circular(3),
      ),
      crossPaint,
    );

    // ── 7. Direction triangle (arrow pointing in heading direction) ──────────
    // Rotate canvas around center, draw an upward-pointing triangle, restore
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(heading * math.pi / 180);

    final arrowPaint = Paint()
      ..color = Colors.white.withOpacity(0.90)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, -33)       // tip of arrow (above the circle)
      ..lineTo(-5, -26)
      ..lineTo(5, -26)
      ..close();
    canvas.drawPath(path, arrowPaint);

    canvas.restore();

    // ── Render ───────────────────────────────────────────────────────────────
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    if (heading == 0) _cachedAmbulanceMarker = descriptor;
    return descriptor;
  }

  // ─── Patient / SOS Marker ─────────────────────────────────────────────────
  // Red pulsing pin with "SOS" label. Looks nothing like the default cyan pin.
  static Future<BitmapDescriptor> getPatientMarker() async {
    if (_cachedPatientMarker != null) return _cachedPatientMarker!;
    const double w = 104.0;
    const double h = 124.0;
    const double cx = w / 2;
    const double headR = 34.0; // pin head radius
    const double cy = headR + 14;
    const navy = Color(0xFF0C637E);
    const deep = Color(0xFF04364E);
    const sos = Color(0xFFDC2626);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Soft SOS halo so the patient stands out without looking like an alert icon
    canvas.drawCircle(
      const Offset(cx, cy),
      headR + 10,
      Paint()..color = sos.withValues(alpha: 0.16),
    );

    // Shadow
    canvas.drawCircle(
      const Offset(cx, cy + 3),
      headR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Pin body (teardrop): white fill, navy outline
    final pin = Path()
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: headR))
      ..moveTo(cx - 14, cy + headR - 6)
      ..quadraticBezierTo(cx, h - 2, cx, h - 2)
      ..quadraticBezierTo(cx, h - 2, cx + 14, cy + headR - 6)
      ..close();
    canvas.drawPath(pin, Paint()..color = Colors.white);
    canvas.drawPath(
      pin,
      Paint()
        ..color = navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Person glyph
    final person = Paint()..color = deep;
    canvas.drawCircle(const Offset(cx, cy - 9), 10, person);
    final shoulders = Path()
      ..moveTo(cx - 18, cy + 20)
      ..quadraticBezierTo(cx - 18, cy + 3, cx, cy + 3)
      ..quadraticBezierTo(cx + 18, cy + 3, cx + 18, cy + 20)
      ..close();
    canvas.drawPath(shoulders, person);

    // "SOS" badge, top-right
    const badge = Rect.fromLTWH(w - 44, 2, 42, 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(11)),
      Paint()..color = sos,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(11)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final label = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(badge.center.dx - label.width / 2, badge.center.dy - label.height / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    _cachedPatientMarker = BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: 52,
      height: 62,
    );
    return _cachedPatientMarker!;
  }

  // ─── Confirmed Real Responder Marker ──────────────────────────────────────
  // Used when a real responder accepts and we switch from simulation to real.
  // Green circle with a checkmark — visually distinct from simulated bikes.
  static Future<BitmapDescriptor> getConfirmedResponderMarker() async {
    if (_cachedConfirmedResponderMarker != null) return _cachedConfirmedResponderMarker!;
    const double size = 90.0;
    const double cx = size / 2;
    const double cy = size / 2;
    const Color green = Color(0xFF22C55E);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Glow
    final glowPaint = Paint()
      ..color = green.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(const Offset(cx, cy), 38, glowPaint);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(cx, cy + 3), 28, shadowPaint);

    // Outer ring
    canvas.drawCircle(
      const Offset(cx, cy), 32,
      Paint()..color = green.withOpacity(0.30),
    );

    // Main circle
    canvas.drawCircle(
      const Offset(cx, cy), 26,
      Paint()..color = green,
    );

    // White inner circle
    canvas.drawCircle(
      const Offset(cx, cy), 19,
      Paint()..color = Colors.white,
    );

    // Green checkmark
    final checkPaint = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(cx - 8, cy)
      ..lineTo(cx - 2, cy + 7)
      ..lineTo(cx + 9, cy - 7);
    canvas.drawPath(checkPath, checkPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    _cachedConfirmedResponderMarker = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    return _cachedConfirmedResponderMarker!;
  }

  // ─── Map Styles ───────────────────────────────────────────────────────────
  // Light teal-tinted style matching MediFind brand (#0C637E / #2496A7)
  static const String _kLightMapStyle = '''
[
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b3d9e8"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#2496A7"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e2f0f3"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#b7d9e0"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#0C637E"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#f8fafc"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e2e8f0"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f1f5f9"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#cbd5e1"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#0C637E"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]}
]''';

  static String getDarkMapStyle() => _kLightMapStyle;
  static String getLightMapStyle() => _kLightMapStyle;
}
