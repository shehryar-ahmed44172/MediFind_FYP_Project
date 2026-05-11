import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapUtils {
  // ─── Ambulance / Responder Marker ─────────────────────────────────────────
  // Canvas-drawn — no PNG file needed.
  // Shows a teal circle with white medical cross + soft glow ring.
  // Pass [heading] (0-360) to rotate the direction indicator arrow.
  static Future<BitmapDescriptor> getAmbulanceMarker({
    Color color = const Color(0xFF0E9AA7),
    double heading = 0,
  }) async {
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
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ─── Patient / SOS Marker ─────────────────────────────────────────────────
  // Red pulsing pin with "SOS" label. Looks nothing like the default cyan pin.
  static Future<BitmapDescriptor> getPatientMarker() async {
    const double w = 80.0;
    const double h = 96.0; // taller than wide — pin shape
    const double cx = w / 2;
    const double pinR = 32.0;
    const double pinCy = pinR + 4;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // ── 1. Drop shadow ───────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.red.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx, pinCy + 4), pinR - 2, shadowPaint);

    // ── 2. Glow ──────────────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..color = Colors.red.withOpacity(0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(cx, pinCy), pinR + 4, glowPaint);

    // ── 3. Outer ring ────────────────────────────────────────────────────────
    final outerPaint = Paint()
      ..color = Colors.red.shade300
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, pinCy), pinR, outerPaint);

    // ── 4. Main red circle ───────────────────────────────────────────────────
    final mainPaint = Paint()
      ..color = Colors.red.shade600
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, pinCy), pinR - 4, mainPaint);

    // ── 5. "SOS" text ────────────────────────────────────────────────────────
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, pinCy - textPainter.height / 2),
    );

    // ── 6. Pin tail ──────────────────────────────────────────────────────────
    final tailPaint = Paint()
      ..color = Colors.red.shade700
      ..style = PaintingStyle.fill;

    final tailPath = Path()
      ..moveTo(cx - 8, pinCy + pinR - 8)
      ..lineTo(cx + 8, pinCy + pinR - 8)
      ..lineTo(cx, h - 4)
      ..close();
    canvas.drawPath(tailPath, tailPaint);

    // ── Render ───────────────────────────────────────────────────────────────
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ─── Confirmed Real Responder Marker ──────────────────────────────────────
  // Used when a real responder accepts and we switch from simulation to real.
  // Green circle with a checkmark — visually distinct from simulated bikes.
  static Future<BitmapDescriptor> getConfirmedResponderMarker() async {
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
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ─── Map Style ────────────────────────────────────────────────────────────
  static String getDarkMapStyle() {
    return '''
[
  {"elementType":"geometry","stylers":[{"color":"#1a1f2e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a1f2e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#9ca3af"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2d3748"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a202c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#374151"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2937"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#9ca3af"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#1f2937"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f172a"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#374151"}]}
]''';
  }
}
