import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../../../core/utils/map_utils.dart';
import 'ambulance_mascot.dart';

/// Prepares the SOS map before it is needed, so the countdown screen does not
/// pause while the Maps SDK starts and the marker bitmaps are drawn.
class MapWarmup {
  MapWarmup._();

  static bool _started = false;

  static Future<void> run() async {
    if (_started) return;
    _started = true;
    // Marker bitmaps are cached for the app session
    AmbulanceMascot.frames().ignore();
    MapUtils.getPatientMarker().ignore();
    MapUtils.getConfirmedResponderMarker().ignore();
    final platform = GoogleMapsFlutterPlatform.instance;
    if (!kIsWeb && platform is GoogleMapsFlutterAndroid) {
      try {
        await platform.warmup();
      } catch (e) {
        debugPrint('MapWarmup: $e');
      }
    }
  }
}
