import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/map/ambulance_mascot.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/emergency_status.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/audio/voice_alert_service.dart';

class SosCountdownScreen extends ConsumerStatefulWidget {
  final String emergencyType;
  final double latitude;
  final double longitude;
  final String? additionalInfo;

  const SosCountdownScreen({
    super.key,
    this.emergencyType = 'OTHER',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.additionalInfo,
  });

  @override
  ConsumerState<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends ConsumerState<SosCountdownScreen>
    with TickerProviderStateMixin {
  /// Backend cancellation window (EMERGENCY_CANCELLATION_WINDOW_SECONDS, default 60).
  static const int _cancelWindowSeconds = 60;

  /// Safety net: if the server never reports a final state, stop waiting.
  static const int _maxSearchSeconds = 150;

  Timer? _timer;
  int _elapsedSeconds = 0;
  int _secondsLeft = _cancelWindowSeconds;
  bool _cancelled = false;
  bool _isCancelling = false;
  bool _isCreating = false;
  bool _createFailed = false;
  bool _navigated = false;
  String? _emergencyId;
  StreamSubscription<SocketMessage>? _socketSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Three staggered radar ring controllers — InDrive style
  late AnimationController _radar1Controller;
  late AnimationController _radar2Controller;
  late AnimationController _radar3Controller;

  // "Responder Found" flash overlay
  bool _responderFound = false;
  late AnimationController _foundController;
  late Animation<double> _foundOpacity;

  // Searching animation: mascot markers moving around the patient. Updated by
  // a 10 fps timer into a ValueNotifier so ONLY the map rebuilds.
  final ValueNotifier<Set<Marker>> _markers = ValueNotifier<Set<Marker>>({});
  Timer? _bikeTimer;
  int _bikeTick = 0;
  List<BitmapDescriptor>? _mascotFrames;
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _confirmedIcon;
  final List<_SimulatedBike> _simulatedBikes = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _radar1Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _radar2Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _radar3Controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    Future.delayed(const Duration(milliseconds: 666), () {
      if (mounted) _radar2Controller.repeat();
    });
    Future.delayed(const Duration(milliseconds: 1333), () {
      if (mounted) _radar3Controller.repeat();
    });

    _foundController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _foundOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _foundController, curve: Curves.easeIn),
    );

    _initSimulatedBikes();
    _loadMarkerIcons();
    _bikeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _updateBikePositions());

    _socketSub = SocketService.instance.messageStream.listen(_onSocketMessage);
    _startTimer();

    // Start SOS broadcast right after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendSOS());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bikeTimer?.cancel();
    _socketSub?.cancel();
    _pulseController.dispose();
    _radar1Controller.dispose();
    _radar2Controller.dispose();
    _radar3Controller.dispose();
    _foundController.dispose();
    _markers.dispose();
    super.dispose();
  }

  // ── Search animation ──────────────────────────────────────────────────────

  void _initSimulatedBikes() {
    for (int i = 0; i < 4; i++) {
      _simulatedBikes.add(_SimulatedBike(
        id: 'sim_$i',
        position: LatLng(
          widget.latitude + (_random.nextDouble() - 0.5) * 0.015,
          widget.longitude + (_random.nextDouble() - 0.5) * 0.015,
        ),
        target: LatLng(
          widget.latitude + (_random.nextDouble() - 0.5) * 0.015,
          widget.longitude + (_random.nextDouble() - 0.5) * 0.015,
        ),
      ));
    }
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final results = await Future.wait([
        AmbulanceMascot.frames(),
        MapUtils.getPatientMarker(),
        MapUtils.getConfirmedResponderMarker(),
      ]);
      if (!mounted) return;
      _mascotFrames = results[0] as List<BitmapDescriptor>;
      _userIcon = results[1] as BitmapDescriptor;
      _confirmedIcon = results[2] as BitmapDescriptor;
      _updateBikePositions();
    } catch (e) {
      debugPrint('Error loading marker icons: $e');
    }
  }

  Marker _userMarker() => Marker(
        markerId: const MarkerId('user'),
        position: LatLng(widget.latitude, widget.longitude),
        icon: _userIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

  void _updateBikePositions() {
    final frames = _mascotFrames;
    if (!mounted || _cancelled || frames == null || _responderFound) return;
    _bikeTick++;
    final frame = frames[(_bikeTick ~/ 5) % 2]; // siren flash every 500 ms

    final markers = <Marker>{_userMarker()};
    for (final bike in _simulatedBikes) {
      bike.moveTowardsTarget();
      if (bike.hasReachedTarget()) {
        bike.setNewTarget(widget.latitude, widget.longitude, _random);
      }
      markers.add(Marker(
        markerId: MarkerId(bike.id),
        position: bike.position,
        icon: frame,
        rotation: bike.rotation,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));
    }
    _markers.value = markers;
  }

  // ── Timer / status ────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _navigated) return;
      setState(() {
        _elapsedSeconds++;
        if (_secondsLeft > 0) _secondsLeft--;
      });

      final settings = ref.read(accessibilityProvider);
      if (settings.vibrationFeedback && _secondsLeft > 0) {
        final user = ref.read(currentUserProvider).valueOrNull;
        if (user?.patientType?.toUpperCase() == 'DEAF') {
          HapticFeedback.heavyImpact(); // Stronger feedback for Deaf patients
        } else {
          HapticFeedback.lightImpact();
        }
      }

      // Heartbeat polling every 5 s as a fallback for missed socket events.
      if (_elapsedSeconds % 5 == 0 && _emergencyId != null) {
        _pollStatus();
      }

      if (_elapsedSeconds >= _maxSearchSeconds) {
        timer.cancel();
        _finishNoResponder();
      }
    });
  }

  Future<void> _pollStatus() async {
    final id = _emergencyId;
    if (id == null) return;
    try {
      final repo = await ref.read(emergencyRepositoryProvider.future);
      final emergency = await repo.getEmergency(id);
      _handleStatus(emergency.status);
    } catch (e) {
      debugPrint('[SOS] status poll failed: $e');
    }
  }

  void _onSocketMessage(SocketMessage message) {
    final id = _emergencyId;
    if (id == null || message.data is! Map) return;
    final data = message.data as Map;

    if (message.event == SocketEvent.emergencyStatusChange) {
      if (data['emergencyId']?.toString() != id) return;
      _handleStatus((data['newStatus'] ?? data['status'])?.toString());
    } else if (message.event == SocketEvent.notification) {
      final inner = data['data'] is Map ? data['data'] as Map : data;
      if (inner['emergencyId']?.toString() != id) return;
      final status = inner['status']?.toString();
      if (status != null) _handleStatus(status);
    }
  }

  void _handleStatus(String? rawStatus) {
    if (!mounted || _navigated || _cancelled) return;
    final status = EmergencyStatus.normalize(rawStatus);
    if (EmergencyStatus.isAssigned(status)) {
      _onResponderAssigned();
    } else if (EmergencyStatus.isCancelled(status)) {
      _finishNoResponder();
    } else if (EmergencyStatus.isResolved(status)) {
      _navigateAway('/home');
    }
  }

  /// A real responder accepted: stop the simulation, flash, then navigate.
  void _onResponderAssigned() {
    if (_responderFound || _navigated) return;
    _timer?.cancel();
    _bikeTimer?.cancel();
    setState(() => _responderFound = true);
    _foundController.forward();
    HapticFeedback.heavyImpact();

    _markers.value = {
      _userMarker(),
      if (_confirmedIcon != null)
        Marker(
          markerId: const MarkerId('confirmed_responder'),
          position: LatLng(widget.latitude, widget.longitude),
          icon: _confirmedIcon!,
          anchor: const Offset(0.5, 0.5),
        ),
    };

    // Brief delay so the "Responder Found" flash is visible before navigating.
    Future.delayed(const Duration(milliseconds: 1200), () {
      final id = _emergencyId;
      if (mounted && id != null) _navigateAway('/emergency/$id/tracking');
    });
  }

  void _navigateAway(String location) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timer?.cancel();
    _bikeTimer?.cancel();
    context.go(location);
  }

  // ── SOS create ────────────────────────────────────────────────────────────

  Future<void> _sendSOS() async {
    if (_cancelled || _isCreating || _emergencyId != null) return;

    setState(() {
      _isCreating = true;
      _createFailed = false;
    });
    try {
      final params = CreateEmergencyParams(
        emergencyType: widget.emergencyType,
        latitude: widget.latitude,
        longitude: widget.longitude,
        additionalInfo: widget.additionalInfo,
      );

      final result = await ref.read(createEmergencyProvider(params).future);
      final emergency = result.emergency;
      if (!mounted) return;

      setState(() {
        _emergencyId = emergency.id;
        _isCreating = false;
      });
      SocketService.instance.joinEmergencyRoom(emergency.id);
      SocketService.instance.joinLocationRoom(emergency.id);

      // The patient tapped Cancel while the request was still being created.
      if (_cancelled) {
        await _cancelOnServer(emergency.id);
        return;
      }

      if (result.alreadyActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have an active emergency. Showing its status.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (EmergencyStatus.isAssigned(emergency.status)) {
          _navigateAway('/emergency/${emergency.id}/tracking');
          return;
        }
      }

      final user = ref.read(currentUserProvider).valueOrNull;
      final isDeaf = (user?.patientType?.toUpperCase() == 'DEAF') ||
          ref.read(accessibilityProvider).textOnlyMode;
      if (!isDeaf && !result.alreadyActive) {
        VoiceAlertService().speakMessage('Emergency request sent. Searching for nearby responders.');
      }
    } catch (e) {
      debugPrint('[SOS] Failed: $e');
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send SOS: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'CALL 1122', textColor: Colors.white, onPressed: _call1122),
        ),
      );
    }
  }

  Future<void> _call1122() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '1122'));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the dialer. Please dial 1122 manually.')),
        );
      }
    }
  }

  void _finishNoResponder() {
    if (_navigated || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No responder was available. If you still need help, call 1122.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'CALL 1122', textColor: Colors.white, onPressed: _call1122),
      ),
    );
    _navigateAway('/home');
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _confirmCancel() async {
    if (_isCancelling || _navigated) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel emergency?'),
        content: const Text('Responders will stop being notified. Only cancel if you are safe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep searching'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _cancel();
  }

  Future<void> _cancel() async {
    HapticFeedback.heavyImpact();
    final id = _emergencyId;

    if (id == null) {
      setState(() => _cancelled = true);
      _timer?.cancel();
      if (_isCreating) {
        // The create request is in flight: stay here (showing "Cancelling…")
        // and let _sendSOS cancel it on the server as soon as the id arrives.
        setState(() => _isCancelling = true);
        return;
      }
      // Creation failed — nothing reached the server.
      _showCancelledSnack();
      _navigateAway('/home');
      return;
    }

    await _cancelOnServer(id);
  }

  Future<void> _cancelOnServer(String id, {bool silent = false}) async {
    setState(() => _isCancelling = true);
    try {
      await ref.read(cancelEmergencyProvider(id).future);
      SocketService.instance.forgetEmergencyRooms(id);
      if (!mounted) return;
      setState(() => _cancelled = true);
      _timer?.cancel();
      if (!silent) _showCancelledSnack();
      _navigateAway('/home');
    } catch (e) {
      if (!mounted) return;
      // The SOS is still live — resume tracking its status.
      setState(() {
        _isCancelling = false;
        _cancelled = false;
      });
      if (_timer?.isActive != true) _startTimer();
      final message = e.toString().toLowerCase();
      if (message.contains('window') && message.contains('expired')) {
        _showCancelWindowExpired();
      } else if (message.contains('not active')) {
        // Already assigned/resolved on the server — show live status.
        _navigateAway('/emergency/$id/tracking');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not cancel: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCancelledSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('SOS alert cancelled', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showCancelWindowExpired() {
    setState(() => _secondsLeft = 0);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Too late to cancel'),
        content: const Text(
          'The cancellation window has closed and responders are already being '
          'dispatched. Stay where you are — help is on the way.',
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canCancel = _secondsLeft > 0 && !_responderFound;
    final statusText = _createFailed
        ? 'Could not reach the server'
        : _isCreating
            ? 'Sending your alert…'
            : canCancel
                ? 'Responders nearby are being notified'
                : 'Still searching for a responder…';

    return PopScope(
      // Back must not silently abandon an active SOS.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canCancel) _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          top: false, // Let the map bleed to the top
          child: Stack(
            children: [
              // Real Google Map
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.45,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: ValueListenableBuilder<Set<Marker>>(
                        valueListenable: _markers,
                        builder: (context, markers, _) => GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(widget.latitude, widget.longitude),
                            zoom: 15,
                          ),
                          markers: markers,
                          style: MapUtils.getDarkMapStyle(),
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ),
                    // ── Triple-ring InDrive-style radar ──────────────────────
                    ...[_radar1Controller, _radar2Controller, _radar3Controller]
                        .map((ctrl) => IgnorePointer(
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: ctrl,
                                  builder: (_, __) {
                                    final v = ctrl.value;
                                    return Container(
                                      width: 220 * v,
                                      height: 220 * v,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary.withValues(alpha: 0.10 * (1 - v)),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.70 * (1 - v)),
                                          width: 1.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )),

                    // ── Responder Found flash overlay ────────────────────────
                    if (_responderFound)
                      FadeTransition(
                        opacity: _foundOpacity,
                        child: Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AmbulanceMascotBadge(size: 72),
                                const SizedBox(height: 14),
                                const Text(
                                  'Responder Found!',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'En route to your location',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Deaf Patient Mode Banner
              if (ref.watch(currentUserProvider).valueOrNull?.patientType?.toUpperCase() == 'DEAF')
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hearing_disabled, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'DEAF PATIENT MODE — VISUAL ALERTS ON',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Main Countdown Body Surface
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: AppShadows.neumorphicOut,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Emergency SOS',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            statusText,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                          ),
                        ),

                        const Spacer(),

                        // Radial countdown (cancel window)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          ),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.5,
                              maxHeight: MediaQuery.of(context).size.width * 0.5,
                            ),
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                                          blurRadius: 40,
                                          spreadRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  CircularProgressIndicator(
                                    value: canCancel ? _secondsLeft / _cancelWindowSeconds : null,
                                    strokeWidth: 12,
                                    backgroundColor: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                                    color: const Color(0xFFD32F2F),
                                    strokeCap: StrokeCap.round,
                                  ),
                                  Center(
                                    child: Semantics(
                                      label: canCancel
                                          ? '$_secondsLeft seconds left to cancel'
                                          : 'Searching for responders',
                                      excludeSemantics: true,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (canCancel) ...[
                                            Text(
                                              '00:${_secondsLeft.toString().padLeft(2, '0')}',
                                              style: const TextStyle(
                                                fontSize: 44,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFD32F2F),
                                                letterSpacing: -1.5,
                                              ),
                                            ),
                                            const Text(
                                              'TO CANCEL',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFD32F2F),
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ] else
                                            const Icon(Icons.radar_rounded, size: 56, color: Color(0xFFD32F2F)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        if (canCancel)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _isCancelling ? null : _confirmCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD32F2F),
                                side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: _isCancelling
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFD32F2F)),
                                    )
                                  : const Text(
                                      'CANCEL EMERGENCY',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                    ),
                            ),
                          )
                        else if (!_responderFound)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _call1122,
                              icon: const Icon(Icons.phone_rounded),
                              label: const Text(
                                'CALL 1122 WHILE YOU WAIT',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                        if (_createFailed) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _isCreating ? null : _sendSOS,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry sending SOS'),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulatedBike {
  final String id;
  LatLng position;
  LatLng target;
  double rotation = 0;

  /// Degrees moved per 100 ms tick.
  static const double speed = 0.0003;

  _SimulatedBike({required this.id, required this.position, required this.target}) {
    _calculateRotation();
  }

  void moveTowardsTarget() {
    final latDiff = target.latitude - position.latitude;
    final lngDiff = target.longitude - position.longitude;
    final distance = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);

    if (distance > speed) {
      position = LatLng(
        position.latitude + (latDiff / distance) * speed,
        position.longitude + (lngDiff / distance) * speed,
      );
    }
  }

  bool hasReachedTarget() {
    final latDiff = target.latitude - position.latitude;
    final lngDiff = target.longitude - position.longitude;
    return math.sqrt(latDiff * latDiff + lngDiff * lngDiff) < speed * 2;
  }

  void setNewTarget(double centerLat, double centerLng, math.Random random) {
    target = LatLng(
      centerLat + (random.nextDouble() - 0.5) * 0.015,
      centerLng + (random.nextDouble() - 0.5) * 0.015,
    );
    _calculateRotation();
  }

  void _calculateRotation() {
    rotation = AnimatedMascotMarker.bearingBetween(position, target);
  }
}
