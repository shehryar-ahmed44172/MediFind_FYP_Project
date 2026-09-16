import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Motorbike Ambulance — animated marker widget for the simulation map overlay.
// Drawn entirely with Flutter Canvas; no external SVG file needed.
// ─────────────────────────────────────────────────────────────────────────────

class MotorbikeAmbulanceWidget extends StatefulWidget {
  /// Direction of travel in degrees (0 = north, 90 = east, 180 = south, 270 = west).
  final double bearing;
  const MotorbikeAmbulanceWidget({super.key, this.bearing = 90});

  @override
  State<MotorbikeAmbulanceWidget> createState() => _MotorbikeAmbulanceWidgetState();
}

class _MotorbikeAmbulanceWidgetState extends State<MotorbikeAmbulanceWidget>
    with TickerProviderStateMixin {
  late final AnimationController _wheelCtrl;
  late final AnimationController _sirenCtrl;

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat();
    _sirenCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..repeat();
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _sirenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Painter draws the bike facing right (east = 90°).
    // Subtract 90° so that bearing 0 (north) = -90° rotation = facing up.
    final rotationRad = (widget.bearing - 90) * math.pi / 180;

    return AnimatedBuilder(
      animation: Listenable.merge([_wheelCtrl, _sirenCtrl]),
      builder: (_, __) => Transform.rotate(
        angle: rotationRad,
        child: CustomPaint(
          size: const Size(128, 76),
          painter: _BikePainter(
            wheelAngle: _wheelCtrl.value * 2 * math.pi,
            sirenBlue: _sirenCtrl.value > 0.5,
          ),
        ),
      ),
    );
  }
}

class _BikePainter extends CustomPainter {
  final double wheelAngle;
  final bool sirenBlue;
  const _BikePainter({required this.wheelAngle, required this.sirenBlue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fixed reference points
    final rearC  = Offset(w * 0.19, h * 0.78);
    final frontC = Offset(w * 0.81, h * 0.78);
    const wr = 12.0; // wheel radius

    // ── Ground shadow ────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.97), width: w * 0.68, height: h * 0.09),
      Paint()
        ..color = Colors.black.withOpacity(0.17)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Wheels ────────────────────────────────────────────────────────────
    _wheel(canvas, rearC,  wr, wheelAngle);
    _wheel(canvas, frontC, wr, wheelAngle);

    // ── Suspension arms ──────────────────────────────────────────────────
    _line(canvas, Offset(w * 0.26, h * 0.62), Offset(rearC.dx,  rearC.dy  - wr + 1), const Color(0xFF9ca3af), 2.2);
    _line(canvas, Offset(w * 0.76, h * 0.58), Offset(frontC.dx, frontC.dy - wr + 1), const Color(0xFF9ca3af), 2.2);

    // ── Ambulance cargo box (white body) ─────────────────────────────────
    final boxRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.13, h * 0.18, w * 0.72, h * 0.64),
      const Radius.circular(6),
    );
    canvas.drawRRect(boxRRect, Paint()..color = const Color(0xFFf8fafc));

    // Red emergency stripe at the bottom of the box
    canvas.save();
    canvas.clipRRect(boxRRect);
    canvas.drawRect(
      Rect.fromLTRB(w * 0.13, h * 0.50, w * 0.72, h * 0.64),
      Paint()..color = const Color(0xFFdc2626),
    );
    // "AMBULANCE" text on stripe
    _label(canvas, Offset(w * 0.425, h * 0.575), 'AMBULANCE', 5.4, Colors.white);
    canvas.restore();

    // Box border
    canvas.drawRRect(
      boxRRect,
      Paint()
        ..color = const Color(0xFFcbd5e1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── Medical cross on box body ─────────────────────────────────────────
    _cross(canvas, Offset(w * 0.41, h * 0.34), 9.5);

    // ── Siren bar on roof ────────────────────────────────────────────────
    _siren(canvas, Offset(w * 0.30, h * 0.12), Offset(w * 0.56, h * 0.12), sirenBlue);

    // ── Rider compartment ─────────────────────────────────────────────────
    // Seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.64, h * 0.26, w * 0.82, h * 0.38),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF1e293b),
    );
    // Rider torso
    canvas.drawOval(
      Rect.fromLTRB(w * 0.65, h * 0.12, w * 0.79, h * 0.30),
      Paint()..color = const Color(0xFF374151),
    );
    // Helmet
    canvas.drawOval(
      Rect.fromLTRB(w * 0.66, h * 0.04, w * 0.79, h * 0.18),
      Paint()..color = const Color(0xFF0ea5e9),
    );
    // Visor
    canvas.drawRect(
      Rect.fromLTRB(w * 0.69, h * 0.08, w * 0.79, h * 0.14),
      Paint()..color = const Color(0xFF7dd3fc).withOpacity(0.55),
    );

    // Handlebar
    _line(canvas, Offset(w * 0.74, h * 0.22), Offset(w * 0.80, h * 0.30),
        const Color(0xFF374151), 3);

    // ── Exhaust pipe ─────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.07, h * 0.60, w * 0.16, h * 0.67),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6b7280),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _wheel(Canvas canvas, Offset c, double r, double angle) {
    // Tyre
    canvas.drawCircle(c, r, Paint()
      ..color = const Color(0xFF0f172a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.40);
    // Rim ring
    canvas.drawCircle(c, r * 0.62, Paint()
      ..color = const Color(0xFFd1d5db)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    // 5 spokes
    final sp = Paint()
      ..color = const Color(0xFF9ca3af)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final a = angle + i * 2 * math.pi / 5;
      canvas.drawLine(c, c + Offset(math.cos(a) * r * 0.57, math.sin(a) * r * 0.57), sp);
    }
    // Hub
    canvas.drawCircle(c, r * 0.14, Paint()..color = const Color(0xFF4b5563));
  }

  void _cross(Canvas canvas, Offset c, double half) {
    final p = Paint()..color = const Color(0xFF16a34a);
    const rad = Radius.circular(1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: half * 2.1, height: half * 0.75), rad), p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: half * 0.75, height: half * 2.1), rad), p);
  }

  void _siren(Canvas canvas, Offset l, Offset r, bool blue) {
    final c1 = blue ? const Color(0xFF3b82f6) : const Color(0xFFef4444);
    final c2 = blue ? const Color(0xFFef4444) : const Color(0xFF3b82f6);

    // Siren housing bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(l.dx - 5, l.dy - 4, r.dx + 5, r.dy + 4),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF374151),
    );
    // Glow
    canvas.drawCircle(l, 6.5, Paint()..color = c1.withOpacity(0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(r, 6.5, Paint()..color = c2.withOpacity(0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Core dots
    canvas.drawCircle(l, 4.2, Paint()..color = c1);
    canvas.drawCircle(r, 4.2, Paint()..color = c2);
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color, double width) =>
      canvas.drawLine(a, b, Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round);

  void _label(Canvas canvas, Offset center, String text, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: 0.6),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BikePainter old) =>
      old.wheelAngle != wheelAngle || old.sirenBlue != sirenBlue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient SOS Avatar — pulsing avatar pin for the patient's location.
// ─────────────────────────────────────────────────────────────────────────────

class PatientAvatarWidget extends StatefulWidget {
  final String? profileImageUrl;
  final String? name;
  const PatientAvatarWidget({super.key, this.profileImageUrl, this.name});

  @override
  State<PatientAvatarWidget> createState() => _PatientAvatarWidgetState();
}

class _PatientAvatarWidgetState extends State<PatientAvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.38).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = (widget.name ?? '')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    final displayInitials = initials.isEmpty ? '?' : initials;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => SizedBox(
        width: 68,
        height: 84,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Outer pulse ring
            Positioned(
              top: 0,
              child: Transform.scale(
                scale: _pulse.value,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent.withOpacity(0.38), width: 2),
                  ),
                ),
              ),
            ),
            // Inner pulse ring
            Positioned(
              top: 5,
              child: Transform.scale(
                scale: _pulse.value * 0.78 + 0.15,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent.withOpacity(0.28), width: 1.5),
                  ),
                ),
              ),
            ),
            // Avatar circle
            Positioned(
              top: 8,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 2.5),
                  color: const Color(0xFF7f1d1d),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: widget.profileImageUrl != null
                    ? Image.network(
                        widget.profileImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _InitialsView(displayInitials),
                      )
                    : _InitialsView(displayInitials),
              ),
            ),
            // SOS label + pin tail
            Positioned(
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: const Size(10, 6),
                    painter: _PinTailPainter(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialsView extends StatelessWidget {
  final String text;
  const _InitialsView(this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      );
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Colors.redAccent,
    );
  }

  @override
  bool shouldRepaint(_PinTailPainter _) => false;
}
