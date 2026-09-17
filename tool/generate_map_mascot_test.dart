// Renders the motorbike-ambulance map marker into PNG assets.
//
//   flutter test tool/generate_map_mascot_test.dart
//
// Live maps move this marker many times a second. With a bytes icon the Android
// maps plugin decodes the image on every move, and the marker can blink when the
// route line redraws. Asset icons are loaded and cached by the Maps SDK instead.
// Re-run after changing MascotTopDownPainter.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medifind_mobile_application/presentation/widgets/map/ambulance_mascot.dart';

void main() {
  testWidgets('generate map mascot assets', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory('assets/map');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      for (final ratio in AmbulanceMascot.assetPixelRatios) {
        for (final flash in [false, true]) {
          final px = (AmbulanceMascot.logicalSize * ratio).round();
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
          canvas.scale(ratio);
          MascotTopDownPainter(flash: flash)
              .paint(canvas, const Size(AmbulanceMascot.logicalSize, AmbulanceMascot.logicalSize));
          final image = await recorder.endRecording().toImage(px, px);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(AmbulanceMascot.assetPath(ratio, flash)).writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
