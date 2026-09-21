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
import '../../widgets/design_system/design_system.dart';
import '../../widgets/map/ambulance_mascot.dart';
import '../../../services/location/road_route_service.dart';
import '../../../services/location/location_service.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/emergency_status.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/audio/voice_alert_service.dart';

class SosCountdownScreen extends ConsumerStatefulWidget {
  final String emergencyType;
  final double latitude;
  final double longitude;
  final String? additionalInfo;
  final bool isMocked;

  /// The position is a recent fix: look for a fresher one before sending.
  final bool refineLocation;

  const SosCountdownScreen({
    super.key,
    this.emergencyType = 'OTHER',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.additionalInfo,
    this.isMocked = false,
    this.refineLocation = false,
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

  /// SRS FR4.3: the alert is only sent after this countdown, so an accidental
  /// SOS can be cancelled without anything reaching the server.
  static const int _preSendSeconds = 60;
  Timer? _preSendTimer;
  int _preSendLeft = _preSendSeconds;
  bool _sent = false;

  Timer? _timer;
  int _elapsedSeconds = 0;
  int _secondsLeft = _cancelWindowSeconds;
  bool _cancelled = false;
  bool _isCancelling = false;
  bool _isCreating = false;
  bool _createFailed = false;
  bool _navigated = false;
  /// The search ended without anyone accepting — the screen switches to a
  /// final state with what to do next instead of navigating away.
  bool _noResponder = false;
  String? _emergencyId;
  StreamSubscription<SocketMessage>? _socketSub;

  // Three staggered radar rings on the map (hidden when reduced motion is on).
  late AnimationController _radar1Controller;
  late AnimationController _radar2Controller;
  late AnimationController _radar3Controller;

  // "Responder found" confirmation overlay
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

  // InDrive-style search camera: fixed, slowly zooming out (no user panning).
  GoogleMapController? _searchMapController;
  Timer? _zoomTimer;
  double _searchZoom = 16.2;

  // Patient position used for the map and the SOS (may be refined during the countdown)
  late double _lat = widget.latitude;
  late double _lng = widget.longitude;
  late bool _isMocked = widget.isMocked;

  // The map is created after the page transition and fades in once drawn
  bool _showMap = false;
  bool _mapVisible = false;
  static const double _searchZoomMin = 14.2;

  @override
  void initState() {
    super.initState();

    _radar1Controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _radar2Controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _radar3Controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    Future.delayed(const Duration(milliseconds: 666), () {
      if (mounted) _radar2Controller.repeat();
    });
    Future.delayed(const Duration(milliseconds: 1333), () {
      if (mounted) _radar3Controller.repeat();
    });

    _foundController =
        AnimationController(vsync: this, duration: MfMotion.normal);
    _foundOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _foundController, curve: Curves.easeIn),
    );

    _initSimulatedBikes();
    _loadMarkerIcons();
    _bikeTimer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => _updateBikePositions());

    _socketSub = SocketService.instance.messageStream.listen(_onSocketMessage);
    _startPreSendCountdown();
    if (widget.refineLocation) _refineLocation();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showMapAfterTransition());
  }

  void _showMapAfterTransition() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      setState(() => _showMap = true);
      return;
    }
    void listener(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      if (mounted) setState(() => _showMap = true);
    }

    animation.addStatusListener(listener);
  }

  /// Opened with a recent fix: take a fresh one before the SOS goes out.
  void _refineLocation() {
    LocationService()
        .getCurrentLocation(timeLimit: const Duration(seconds: 30))
        .then((pos) {
      if (!mounted || _sent || _cancelled) return;
      final moved = RoadRouteService.distanceMeters(
          LatLng(_lat, _lng), LatLng(pos.latitude, pos.longitude));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _isMocked = pos.isMocked;
      });
      if (moved > 25) {
        _searchMapController
            ?.animateCamera(CameraUpdate.newLatLng(LatLng(_lat, _lng)));
      }
    }).catchError((Object e) {
      debugPrint('SOS location refine failed, using the recent fix: $e');
    });
  }

  // ── Pre-send countdown ────────────────────────────────────────────────────

  void _startPreSendCountdown() {
    _preSendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cancelled) {
        timer.cancel();
        return;
      }
      setState(() => _preSendLeft--);
      if (ref.read(accessibilityProvider).vibrationFeedback) {
        _preSendLeft <= 10
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.lightImpact();
      }
      if (_preSendLeft <= 0) _sendNow();
    });
  }

  /// Countdown finished or the patient chose "Send now".
  void _sendNow() {
    if (_sent || _cancelled) return;
    _preSendTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _sent = true);
    _startTimer();
    _startSearchZoom();
    _sendSOS();
  }

  /// Cancelled before sending: nothing was created on the server.
  void _cancelBeforeSend() {
    if (_sent) return;
    _preSendTimer?.cancel();
    setState(() => _cancelled = true);
    showMfSnackBar(context, 'SOS cancelled. Nothing was sent.',
        tone: MfTone.success);
    _navigateAway('/home');
  }

  @override
  void dispose() {
    _preSendTimer?.cancel();
    _timer?.cancel();
    _bikeTimer?.cancel();
    _zoomTimer?.cancel();
    _socketSub?.cancel();
    _radar1Controller.dispose();
    _radar2Controller.dispose();
    _radar3Controller.dispose();
    _foundController.dispose();
    _markers.dispose();
    super.dispose();
  }

  // ── Search animation ──────────────────────────────────────────────────────

  void _initSimulatedBikes() {
    final patient = LatLng(_lat, _lng);
    for (int i = 0; i < 4; i++) {
      // Start 0.9–1.6 km away in four directions, then drive the real road route in.
      final angle = (i * math.pi / 2) + _random.nextDouble() * 0.6;
      final km = 0.9 + _random.nextDouble() * 0.7;
      final start = LatLng(
        patient.latitude + (km / 111.0) * math.cos(angle),
        patient.longitude +
            (km / (111.0 * math.cos(patient.latitude * math.pi / 180))) *
                math.sin(angle),
      );
      final bike = _SimulatedBike(
          id: 'sim_$i',
          start: start,
          speedMetersPerTick: 4.0 + _random.nextDouble() * 2.5);
      _simulatedBikes.add(bike);
      RoadRouteService.route(start, patient).then((route) {
        if (mounted)
          bike.setRoute(route.points,
              startFraction: 0.45 + _random.nextDouble() * 0.4);
      });
    }
  }

  /// Slow, continuous zoom-out while searching — the search area "widens".
  void _startSearchZoom() {
    _zoomTimer?.cancel();
    if (MfMotion.reduced(context)) return;
    _zoomTimer = Timer.periodic(const Duration(milliseconds: 1200), (t) {
      final controller = _searchMapController;
      if (!mounted || controller == null || _responderFound || _cancelled) {
        t.cancel();
        return;
      }
      if (_searchZoom <= _searchZoomMin) {
        t.cancel();
        return;
      }
      _searchZoom = math.max(_searchZoomMin, _searchZoom - 0.06);
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(_lat, _lng), zoom: _searchZoom),
      ));
    });
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
        position: LatLng(_lat, _lng),
        icon: _userIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

  void _updateBikePositions() {
    final frames = _mascotFrames;
    if (!mounted || _cancelled || frames == null || _responderFound) return;
    _bikeTick++;
    final frame = frames[(_bikeTick ~/ 5) % 2]; // siren flash every 500 ms

    final markers = <Marker>{_userMarker()};
    for (final bike in _simulatedBikes) {
      if (!bike.hasRoute) continue;
      bike.advance();
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
    // While the patient's own cancel request is in flight, the server's CANCELLED
    // update is expected — it must not be shown as "no responder available".
    if (!mounted || _navigated || _cancelled || _isCancelling) return;
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
          position: LatLng(_lat, _lng),
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
    _preSendTimer?.cancel();
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
        latitude: _lat,
        longitude: _lng,
        additionalInfo: widget.additionalInfo,
        isMocked: _isMocked,
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
        showMfSnackBar(context,
            'You already have an active emergency. Showing its status.',
            tone: MfTone.info);
        if (EmergencyStatus.isAssigned(emergency.status)) {
          _navigateAway('/emergency/${emergency.id}/tracking');
          return;
        }
      }

      final user = ref.read(currentUserProvider).valueOrNull;
      final accessibility = ref.read(accessibilityProvider);
      final isDeaf = (user?.patientType?.toUpperCase() == 'DEAF') ||
          accessibility.textOnlyMode;
      // Spoken updates only when the patient turned on Voice Guidance.
      if (!isDeaf &&
          !result.alreadyActive &&
          accessibility.voiceGuidanceEnabled) {
        VoiceAlertService().speakMessage(
            'Emergency request sent. Searching for nearby responders.');
      }
    } catch (e) {
      debugPrint('[SOS] Failed: $e');
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createFailed = true;
      });
      // A deaf patient cannot act on "call 1122" — offer the card instead.
      final deaf = (ref.read(currentUserProvider).valueOrNull?.patientType?.toUpperCase() ==
              'DEAF') ||
          ref.read(accessibilityProvider).textOnlyMode;
      showMfSnackBar(
        context,
        'Could not send SOS: $e',
        tone: MfTone.danger,
        duration: const Duration(seconds: 6),
        actionLabel: deaf ? 'Show card' : 'Call 1122',
        onAction: deaf
            ? () => _showHelpCard(
                'I am deaf and I need an ambulance. Please call 1122 for me.')
            : _call1122,
      );
    }
  }

  Future<void> _call1122() async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: '1122'));
    } catch (_) {
      if (mounted) {
        showMfSnackBar(
            context, 'Could not open the dialer. Please dial 1122 manually.',
            tone: MfTone.danger);
      }
    }
  }

  /// Shows the bystander card with a message asking for help, so a deaf patient
  /// never has to speak to get someone nearby to call 1122.
  void _showHelpCard([String? message]) {
    HapticFeedback.mediumImpact();
    context.push('/home/show-card', extra: message);
  }

  /// No responder took the emergency. The patient stays on this screen with
  /// clear options instead of being dropped on the home screen with a message
  /// that a deaf patient cannot act on.
  void _finishNoResponder() {
    if (_navigated || !mounted || _noResponder) return;
    _timer?.cancel();
    _bikeTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _noResponder = true);
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _confirmCancel() async {
    if (_isCancelling || _navigated) return;
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Cancel SOS?',
      message:
          'Responders will stop being notified. Only cancel if you are safe.',
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep searching',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (confirmed && mounted) await _cancel();
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
        showMfSnackBar(context, 'Could not cancel: $e', tone: MfTone.danger);
      }
    }
  }

  void _showCancelledSnack() {
    showMfSnackBar(context, 'SOS alert cancelled', tone: MfTone.success);
  }

  void _showCancelWindowExpired() {
    setState(() => _secondsLeft = 0);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.info_outline_rounded,
            color: Theme.of(ctx).colorScheme.primary, size: 28),
        title: const Text('Too late to cancel'),
        content: const Text(
          'The cancellation window has closed and responders are already being '
          'dispatched. Stay where you are — help is on the way.',
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reducedMotion = MfMotion.reduced(context);
    final canCancel = _sent && _secondsLeft > 0 && !_responderFound;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isDeaf = (user?.patientType?.toUpperCase() == 'DEAF') ||
        ref.watch(accessibilityProvider.select((s) => s.textOnlyMode));
    final statusText = !_sent
        ? 'Your SOS will be sent in $_preSendLeft ${_preSendLeft == 1 ? 'second' : 'seconds'}'
        : _responderFound
            ? 'Responder found. Opening live tracking…'
            : _noResponder
                ? 'No responder accepted your SOS'
                : _createFailed
                    ? 'Could not reach the server'
                    : _isCreating
                        ? 'Sending your alert…'
                        : canCancel
                            ? 'Responders nearby are being notified'
                            : 'Still searching for a responder…';
    final mapHeight = MediaQuery.sizeOf(context).height * 0.38;

    return PopScope(
      // Back must not silently abandon an active SOS.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_sent) {
          _cancelBeforeSend();
        } else if (_noResponder) {
          _navigateAway('/home');
        } else if (canCancel) {
          _confirmCancel();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // ── Map with searching radar ────────────────────────────────────
            SizedBox(
              height: mapHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Map-coloured placeholder while the page slides in
                  const ColoredBox(color: Color(0xFFEFF3F2)),
                  if (_showMap)
                    AnimatedOpacity(
                      opacity: _mapVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<Set<Marker>>(
                          valueListenable: _markers,
                          builder: (context, markers, _) => GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(_lat, _lng),
                              zoom: _searchZoom,
                            ),
                            markers: markers,
                            style: MapUtils.getDarkMapStyle(),
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            // Camera is controlled by the search animation only
                            scrollGesturesEnabled: false,
                            zoomGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            tiltGesturesEnabled: false,
                            mapToolbarEnabled: false,
                            onMapCreated: (controller) {
                              _searchMapController = controller;
                              if (_sent) _startSearchZoom();
                              // Give the first tiles a moment, then fade the map in
                              Future.delayed(const Duration(milliseconds: 250),
                                  () {
                                if (mounted) setState(() => _mapVisible = true);
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  if (_sent && !reducedMotion && !_responderFound && !_noResponder)
                    ...[_radar1Controller, _radar2Controller, _radar3Controller]
                        .map(
                      (ctrl) => IgnorePointer(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: ctrl,
                            builder: (_, __) {
                              final v = ctrl.value;
                              final primary =
                                  MfColors.tone(context, MfTone.primary).solid;
                              return Container(
                                width: 200 * v,
                                height: 200 * v,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      primary.withValues(alpha: 0.08 * (1 - v)),
                                  border: Border.all(
                                    color: primary.withValues(
                                        alpha: 0.55 * (1 - v)),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  // ── Responder found confirmation ─────────────────────────
                  if (_responderFound)
                    FadeTransition(
                      opacity: _foundOpacity,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(MfSpace.md),
                            child: MfCard(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color:
                                          MfColors.tone(context, MfTone.success)
                                              .solid,
                                      size: 32),
                                  const SizedBox(width: MfSpace.sm),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Responder found',
                                            style: text.titleMedium),
                                        Text(
                                          'On the way to your location',
                                          style: text.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          MfSpace.sm, MfSpace.xs, MfSpace.sm, 0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _LiveSosChip(sent: _sent, ended: _noResponder),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Status panel ────────────────────────────────────────────────
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      MfSpace.gutter, MfSpace.lg, MfSpace.gutter, MfSpace.md),
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Emergency SOS',
                          textAlign: TextAlign.center,
                          style: text.headlineSmall),
                    ),
                    const SizedBox(height: MfSpace.xxs),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: text.bodyLarge
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: MfSpace.lg),
                    Center(
                        child: _sent
                            ? _buildCountdownRing(context, canCancel)
                            : _buildPreSendRing(context)),
                    if (!_sent) ...[
                      const SizedBox(height: MfSpace.md),
                      Text(
                        'Cancel now if this was a mistake — nothing has been sent yet.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    if (isDeaf && !_noResponder) ...[
                      const SizedBox(height: MfSpace.lg),
                      const MfInfoBanner(
                        icon: Icons.hearing_disabled_outlined,
                        tone: MfTone.primary,
                        title: 'Visual alerts are on',
                        message:
                            'You will get a flashing screen and vibration — no sound needed.',
                      ),
                    ],
                    // Waiting is the moment people feel lost: say plainly what
                    // is happening and what to do meanwhile.
                    if (_sent && !_responderFound && !_createFailed)
                      _buildWaitingGuidance(context, isDeaf: isDeaf),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: MfBottomActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_sent) ...[
                MfPrimaryButton(
                  label: 'Send SOS now',
                  icon: Icons.emergency_share_rounded,
                  tone: MfTone.danger,
                  height: MfSize.primaryButton + 8,
                  onPressed: _sendNow,
                ),
                const SizedBox(height: MfSpace.xs),
                MfSecondaryButton(
                  label: 'Cancel, I am safe',
                  icon: Icons.close_rounded,
                  onPressed: _cancelBeforeSend,
                ),
              ] else if (_noResponder) ...[
                // Nobody accepted. A deaf patient cannot use a phone call, so
                // the card they can show to someone nearby comes first.
                if (isDeaf)
                  MfPrimaryButton(
                    label: 'Show card asking for help',
                    icon: Icons.badge_outlined,
                    onPressed: () => _showHelpCard(
                        'I am deaf and I need an ambulance. Please call 1122 for me.'),
                  )
                else
                  MfPrimaryButton(
                    label: 'Call 1122 now',
                    icon: Icons.phone_rounded,
                    tone: MfTone.danger,
                    onPressed: _call1122,
                  ),
                const SizedBox(height: MfSpace.xs),
                MfSecondaryButton(
                  label: 'Send a new SOS',
                  icon: Icons.refresh_rounded,
                  tone: MfTone.danger,
                  onPressed: _retryAfterNoResponder,
                ),
                const SizedBox(height: MfSpace.xxs),
                MfTextButton(
                  label: isDeaf ? 'Call 1122' : 'Back to home',
                  icon: isDeaf ? Icons.phone_rounded : Icons.home_outlined,
                  onPressed: isDeaf ? _call1122 : () => _navigateAway('/home'),
                ),
                if (isDeaf)
                  MfTextButton(
                    label: 'Back to home',
                    icon: Icons.home_outlined,
                    onPressed: () => _navigateAway('/home'),
                  ),
              ] else if (canCancel) ...[
                MfSecondaryButton(
                  label: _isCancelling ? 'Cancelling…' : 'Cancel SOS',
                  icon: Icons.close_rounded,
                  tone: MfTone.danger,
                  large: true,
                  loading: _isCancelling,
                  onPressed: _isCancelling ? null : _confirmCancel,
                ),
                if (isDeaf) ...[
                  const SizedBox(height: MfSpace.xxs),
                  MfTextButton(
                    label: 'Show card to people nearby',
                    icon: Icons.badge_outlined,
                    onPressed: () => _showHelpCard(
                        'I am deaf. An ambulance is on the way to me.'),
                  ),
                ],
              ] else if (!_responderFound) ...[
                if (isDeaf) ...[
                  MfPrimaryButton(
                    label: 'Show card to people nearby',
                    icon: Icons.badge_outlined,
                    onPressed: () => _showHelpCard(
                        'I am deaf and I need help. An ambulance has been called.'),
                  ),
                  const SizedBox(height: MfSpace.xxs),
                  MfTextButton(
                    label: 'Ask someone to call 1122',
                    icon: Icons.phone_rounded,
                    onPressed: _call1122,
                  ),
                ] else
                  MfPrimaryButton(
                    label: 'Call 1122 while you wait',
                    icon: Icons.phone_rounded,
                    tone: MfTone.danger,
                    onPressed: _call1122,
                  ),
              ],
              if (_createFailed) ...[
                const SizedBox(height: MfSpace.xs),
                MfTextButton(
                  label: 'Retry sending SOS',
                  icon: Icons.refresh_rounded,
                  onPressed: _isCreating ? null : _sendSOS,
                ),
              ],
              if (_responderFound)
                const MfLoading(label: 'Opening live tracking'),
            ],
          ),
        ),
      ),
    );
  }

  /// Plain-language guidance for the wait — and, when the search ended with
  /// nobody accepting, what to do instead. Written so it works with no sound.
  Widget _buildWaitingGuidance(BuildContext context, {required bool isDeaf}) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final (String title, List<(IconData, String)> steps) = _noResponder
        ? (
            'What to do now',
            [
              (
                Icons.badge_outlined,
                isDeaf
                    ? 'Show the card below to anyone nearby and ask them to call 1122.'
                    : 'Call 1122 — they dispatch government ambulances.',
              ),
              (Icons.refresh_rounded, 'Or send a new SOS: other responders may be online now.'),
              (Icons.people_outline_rounded, 'Your linked caregivers were already alerted and can help.'),
            ],
          )
        : (
            'While you wait',
            [
              (Icons.place_outlined, 'Stay where you are if you can. The responder is coming to this exact spot.'),
              (
                Icons.lock_open_rounded,
                'If you are indoors, unlock the door or ask someone to wait at the gate.',
              ),
              if (isDeaf)
                (
                  Icons.badge_outlined,
                  'You can show the card to people nearby — it explains that you are deaf and need help.',
                )
              else
                (Icons.volume_up_outlined, 'Keep your phone with you. You will be told the moment someone accepts.'),
              (
                Icons.people_outline_rounded,
                'Your linked caregivers have already been alerted with your location.',
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(top: MfSpace.lg),
      child: MfCard(
        tone: _noResponder ? MfTone.warning : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: text.titleMedium)),
            if (!_noResponder) ...[
              const SizedBox(height: MfSpace.xxs),
              Text(
                'Responders near you are being alerted one by one. Most accept within two minutes.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ] else ...[
              const SizedBox(height: MfSpace.xxs),
              Text(
                'Nobody was available to take this emergency. You are not being searched for any more.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: MfSpace.sm),
            for (final (icon, line) in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: MfSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: MfSpace.sm),
                    Expanded(child: Text(line, style: text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Sends a fresh SOS after nobody accepted the previous one.
  void _retryAfterNoResponder() {
    if (!mounted) return;
    setState(() {
      _noResponder = false;
      _emergencyId = null;
      _createFailed = false;
      _elapsedSeconds = 0;
      _secondsLeft = _cancelWindowSeconds;
    });
    _startTimer();
    _sendSOS();
  }

  /// 60-second ring shown before anything is sent.
  Widget _buildPreSendRing(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sos = MfColors.sos(context);
    const ringSize = 200.0;

    return Semantics(
      liveRegion: true,
      label: 'Sending SOS in $_preSendLeft seconds',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: ringSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: _preSendLeft / _preSendSeconds),
              duration: MfMotion.reduced(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                backgroundColor: cs.surfaceContainerHighest,
                color: sos,
                strokeCap: StrokeCap.round,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MfSpace.lg),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_preSendLeft ~/ 60).toString().padLeft(2, '0')}:${(_preSendLeft % 60).toString().padLeft(2, '0')}',
                      style: text.displayMedium?.copyWith(
                        color: sos,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text('Sending SOS',
                        style: text.labelLarge
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cancel-window countdown ring; indeterminate "searching" ring afterwards.
  Widget _buildCountdownRing(BuildContext context, bool canCancel) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final sos = MfColors.sos(context);
    const ringSize = 200.0;

    return Semantics(
      label: _noResponder
          ? 'Search ended, no responder available'
          : canCancel
              ? '$_secondsLeft seconds left to cancel'
              : 'Searching for responders',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: ringSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: canCancel
                  ? _secondsLeft / _cancelWindowSeconds
                  : (_responderFound || _noResponder ? 1 : null),
              strokeWidth: 8,
              backgroundColor: cs.surfaceContainerHighest,
              color: _responderFound
                  ? MfColors.tone(context, MfTone.success).solid
                  : _noResponder
                      ? MfColors.tone(context, MfTone.warning).solid
                      : sos,
              strokeCap: StrokeCap.round,
            ),
            Padding(
              padding: const EdgeInsets.all(MfSpace.lg),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canCancel) ...[
                      Text(
                        '00:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: text.displayMedium?.copyWith(
                          color: sos,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text('left to cancel',
                          style: text.labelLarge
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ] else if (_noResponder) ...[
                      Icon(Icons.search_off_rounded,
                          size: 48,
                          color: MfColors.tone(context, MfTone.warning).foreground),
                      const SizedBox(height: MfSpace.xxs),
                      Text('Search ended', style: text.titleMedium),
                    ] else if (_responderFound) ...[
                      Icon(Icons.check_rounded,
                          size: 56,
                          color: MfColors.tone(context, MfTone.success).solid),
                      Text('Found', style: text.titleMedium),
                    ] else ...[
                      Icon(Icons.person_search_outlined,
                          size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: MfSpace.xxs),
                      Text('Searching', style: text.titleMedium),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "SOS active" label on top of the map.
class _LiveSosChip extends StatelessWidget {
  final bool sent;

  /// The search finished with no responder — the SOS is no longer live.
  final bool ended;
  const _LiveSosChip({required this.sent, this.ended = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: MfRadius.smAll,
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MfSpace.xxs),
        child: ended
            ? const MfStatusChip(
                label: 'Search ended',
                tone: MfTone.warning,
                icon: Icons.search_off_rounded)
            : sent
                ? const MfStatusChip(
                    label: 'SOS active',
                    tone: MfTone.danger,
                    icon: Icons.sos_rounded)
                : const MfStatusChip(
                    label: 'Not sent yet',
                    tone: MfTone.warning,
                    icon: Icons.timer_outlined),
      ),
    );
  }
}

class _SimulatedBike {
  final String id;
  final double speedMetersPerTick;
  LatLng position;
  double rotation = 0;

  List<LatLng> _route = const [];
  double _length = 0;
  double _progress = 0;

  _SimulatedBike(
      {required this.id,
      required LatLng start,
      required this.speedMetersPerTick})
      : position = start;

  bool get hasRoute => _route.length >= 2;

  void setRoute(List<LatLng> points, {double startFraction = 0}) {
    _route = points;
    _length = RoadRouteService.lengthMeters(points);
    _progress = _length * startFraction;
    position = RoadRouteService.pointAlong(_route, _progress);
  }

  /// Moves along the road; loops back to the start near the patient.
  void advance() {
    if (!hasRoute) return;
    _progress += speedMetersPerTick;
    // Loop over the last part of the route so the bikes stay in view near the patient
    if (_progress >= _length - 60) _progress = _length * 0.4;
    final next = RoadRouteService.pointAlong(_route, _progress);
    final ahead = RoadRouteService.pointAlong(_route, _progress + 12);
    if (RoadRouteService.distanceMeters(next, ahead) > 0.5) {
      rotation = AnimatedMascotMarker.bearingBetween(next, ahead);
    }
    position = next;
  }
}
