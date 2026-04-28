import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'location_service.dart';
import '../../presentation/providers/emergency_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';

final responderLocationTrackerProvider = Provider<ResponderLocationTracker>((ref) {
  final tracker = ResponderLocationTracker(ref);
  ref.onDispose(() => tracker.stop());
  return tracker;
});

class ResponderLocationTracker {
  final Ref _ref;
  Timer? _timer;
  bool _isTracking = false;

  ResponderLocationTracker(this._ref);

  void start() {
    if (_isTracking) return;
    _isTracking = true;
    
    // Initial sync
    _syncLocation();
    
    // Periodic sync every 30 seconds while the app is active
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _syncLocation());
    debugPrint('🚀 Responder Location Tracking Started');
  }

  void stop() {
    _timer?.cancel();
    _isTracking = false;
    debugPrint('🛑 Responder Location Tracking Stopped');
  }

  Future<void> _syncLocation() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || user.role != 'RESPONDER' || !user.isActive) {
      if (_isTracking) stop();
      return;
    }

    // CRITICAL: Respect Simulation Mode so we don't overwrite fake locations during physical device testing!
    final isSimulating = _ref.read(simulationModeProvider);
    if (isSimulating) {
      debugPrint('📍 Auto-Sync Skipped: Simulation Mode is ON');
      return;
    }

    try {
      final position = await LocationService().getCurrentLocation();
      await _ref.read(updateResponderLocationProvider(position).future);
      debugPrint('📍 Auto-Synced Responder Location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('⚠️ Auto-Sync Location Failed: $e');
    }
  }
}
