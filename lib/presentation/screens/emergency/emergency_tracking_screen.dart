import 'dart:async';
import '../../widgets/call/call_launcher.dart';
import '../../../services/call/call_service.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_feedback_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../domain/entities/emergency.dart';
import '../../../domain/entities/user.dart';
import '../../../services/audio/voice_alert_service.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_utils.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/map/ambulance_mascot.dart';
import '../../widgets/map/tracking_camera.dart';
import '../../widgets/map/route_line.dart';
import '../../widgets/map/map_loading_cover.dart';
import '../../../core/utils/emergency_status.dart';
import '../../widgets/responder/responder_rating.dart';

class EmergencyTrackingScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const EmergencyTrackingScreen({super.key, required this.emergencyId});

  @override
  ConsumerState<EmergencyTrackingScreen> createState() => _EmergencyTrackingScreenState();
}

class _EmergencyTrackingScreenState extends ConsumerState<EmergencyTrackingScreen> {
  GoogleMapController? _mapController;
  final _mapCover = MapCoverController();

  double? _responderLat;
  double? _responderLong;
  String? _responderName;
  String? _responderPhone;
  String? _responderProfileImage;
  double?  _responderRating;
  /// 0 = nobody has rated this responder yet, so the card says "New".
  int?     _responderTotalRatings;
  String? _responderType;
  String? _motorbikeNumber;
  String? _vehicleType;
  String? _organization;
  String? _responderId;

  /// Server status: ACTIVE (searching), ASSIGNED, EN_ROUTE, ARRIVED, ... RESOLVED.
  String _currentStatus = 'ACTIVE';
  bool _statusLoaded = false;
  String _eta = 'Waiting for responder';
  int _selectedStars = 0;
  bool _ratingSubmitted = false;
  bool _leftForTerminal = false;

  StreamSubscription<SocketMessage>? _socketSub;

  // AI-personalized quick replies for deaf patients (loaded lazily on first open)
  List<Map<String, dynamic>>? _aiQuickReplies;

  /// Animated motorbike-ambulance marker for the assigned responder.
  /// Road route from the responder to the patient (SRS FR6.2).
  final RouteLine _route = RouteLine(color: AppColors.primary);
  final TrackingCamera _camera = TrackingCamera();

  AnimatedMascotMarker _responderMarker = AnimatedMascotMarker(
    markerId: const MarkerId('responder'),
    infoWindow: const InfoWindow(title: 'Responder'),
  );

  /// Patient SOS pin (falls back to a default red marker until loaded).
  BitmapDescriptor? _patientIcon;

  // ── Simulation overlay state ─────────────────────────────────────────────
  bool _simActive = false;
  LatLng? _patientLatLng;
  ScreenCoordinate? _responderScreenCoord;
  ScreenCoordinate? _patientScreenCoord;
  double _currentBearing = 90; // default east
  LatLng? _prevResponderLatLng;

  @override
  void initState() {
    super.initState();
    final socketService = SocketService.instance;
    socketService.joinEmergencyRoom(widget.emergencyId);
    socketService.joinLocationRoom(widget.emergencyId);
    _socketSub = socketService.messageStream.listen(_onSocketMessage);
    _route.route.addListener(_onRouteChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(socketStreamProvider);
      _prefetchAiQuickReplies();
      // Simulation mode (testing) is started/stopped outside build().
      ref.listenManual<bool>(simulationModeProvider, (_, isSim) {
        if (isSim) _startSimulation();
      }, fireImmediately: true);
    });

    MapUtils.getPatientMarker().then((icon) {
      if (mounted) setState(() => _patientIcon = icon);
    }).catchError((Object e) {
      debugPrint('Tracking: could not load patient marker: $e');
    });

    _loadInitialState();
  }

  @override
  void dispose() {
    _mapCover.dispose();
    _simTimer?.cancel();
    _simTimer = null;
    _socketSub?.cancel();
    _responderMarker.dispose();
    _route.dispose();
    super.dispose();
  }

  /// Initial status + assigned responder from the server, so reopening this
  /// screen (or opening it from a notification) doesn't show "searching".
  Future<void> _loadInitialState() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getEmergencyRaw(widget.emergencyId);
      if (!mounted) return;

      String? responderId = data['assignedResponderId']?.toString();
      String? responderName = data['assignedResponderName']?.toString();
      final requests = data['emergencyRequests'];
      if (requests is List) {
        for (final r in requests.whereType<Map>()) {
          final st = r['status']?.toString().toUpperCase();
          if (st == 'ACCEPTED' || st == 'COMPLETED') {
            responderId ??= r['responderId']?.toString();
            final responder = r['responder'];
            if (responder is Map && responder['user'] is Map) {
              responderName ??= (responder['user'] as Map)['fullName']?.toString();
            }
            if (responder is Map) {
              _responderType ??= responder['responderType']?.toString();
              _vehicleType ??= responder['vehicleType']?.toString();
              _motorbikeNumber ??= responder['motorbikeNumber']?.toString();
              _organization ??= responder['organization']?.toString();
            }
            break;
          }
        }
      }

      final previousStatus = _currentStatus;
      setState(() {
        final serverStatus = EmergencyStatus.normalize(data['status']?.toString());
        if (!_statusLoaded && serverStatus.isNotEmpty) _currentStatus = serverStatus;
        _statusLoaded = true;
        _responderId ??= responderId;
        _responderName ??= responderName;
        if (_responderId != null && _eta == 'Waiting for responder') _eta = 'Calculating…';
      });
      if (_currentStatus == 'ARRIVED' && previousStatus != 'ARRIVED') {
        _raiseArrivedVisualAlert();
      }
      _handleTerminalStatus();

      if (responderId != null) {
        _loadResponderProfile(responderId);
        _loadLatestResponderPosition();
      }
    } catch (e) {
      debugPrint('Tracking: could not load emergency details: $e');
      if (mounted) setState(() => _statusLoaded = true);
    }
  }

  Future<void> _loadResponderProfile(String responderId) async {
    try {
      final profile = await ref.read(apiClientProvider).getUserProfile(responderId);
      if (!mounted || profile == null) return;
      setState(() {
        _responderName ??= profile.fullName;
        if (profile.phoneNumber.isNotEmpty) _responderPhone ??= profile.phoneNumber;
        _responderProfileImage ??= profile.profileImageUrl;
        _responderRating ??= profile.rating;
        _responderTotalRatings ??= profile.totalRatings;
        _responderType ??= profile.responderType;
        _vehicleType ??= profile.vehicleType;
        _organization ??= profile.organization;
      });
    } catch (e) {
      debugPrint('Tracking: could not load responder profile: $e');
    }
  }

  Future<void> _loadLatestResponderPosition() async {
    try {
      final latest = await ref.read(apiClientProvider).getLatestTracking(widget.emergencyId);
      if (!mounted || latest is! Map) return;
      final lat = double.tryParse(latest['latitude']?.toString() ?? '');
      final lng = double.tryParse(latest['longitude']?.toString() ?? '');
      if (lat != null && lng != null && _responderLat == null) {
        _applyResponderPosition(lat, lng, null);
      }
    } catch (_) {
      // No tracking yet (404) — the socket will deliver positions.
    }
  }

  void _applyResponderPosition(double lat, double lng, dynamic etaMinutes) {
    final patient = _patientLatLng;
    final serverEta = etaMinutes == null ? null : num.tryParse(etaMinutes.toString());
    String eta;
    if (serverEta != null) {
      eta = serverEta <= 0
          ? 'Arriving'
          : (serverEta > GeoUtils.maxPlausibleEtaMin ? 'Locating' : '${serverEta.round()} min');
    } else if (patient != null) {
      final km = GeoUtils.haversineKm(lat, lng, patient.latitude, patient.longitude);
      final minutes = GeoUtils.etaMinutes(km);
      eta = !GeoUtils.isPlausible(km) ? 'Locating' : (minutes == 0 ? 'Arriving' : '$minutes min');
    } else {
      eta = _eta;
    }
    setState(() {
      _responderLat = lat;
      _responderLong = lng;
      _eta = eta;
    });
    _responderMarker.moveTo(LatLng(lat, lng));
    _route.update(LatLng(lat, lng), patient);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateToResponder();
        if (_simActive) _updateOverlayPositions();
      }
    });
  }

  /// "Responder arrived" full-screen visual alert.
  ///
  /// The app-wide [DeafVisualAlertLayer] renders it. For DEAF-type patients
  /// `emergency_provider` already sets the alert from the socket, so this only
  /// covers NORMAL patients who turned on text-only mode.
  void _raiseArrivedVisualAlert() {
    final user = ref.read(currentUserProvider).valueOrNull;
    final settings = ref.read(accessibilityProvider);
    final isDeafType = user?.patientType?.toUpperCase() == 'DEAF';
    if (isDeafType || !settings.textOnlyMode) return;
    ref.read(visualEmergencyAlertProvider.notifier).state =
        'RESPONDER ARRIVED: Look around for ${_responderName ?? 'help'}.';
  }

  void _onSocketMessage(SocketMessage message) {
    if (!mounted || _simActive || message.data is! Map) return;
    final data = Map<String, dynamic>.from(message.data as Map);
    // Only events for THIS emergency.
    if (message.event == SocketEvent.notification) {
      final inner = data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : data;
      if (inner['emergencyId']?.toString() != widget.emergencyId) return;
      final type = data['type']?.toString();
      if (type == 'RESPONDER_ASSIGNED' || type == 'EMERGENCY_RESOLVED') {
        _loadInitialState();
      }
      return;
    }
    if (data['emergencyId']?.toString() != widget.emergencyId) return;

    final settings = ref.read(accessibilityProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    final isDeafPatient = (user?.patientType?.toUpperCase() == 'DEAF') || settings.textOnlyMode;

    if (message.event == SocketEvent.emergencyStatusChange) {
      final newStatus = EmergencyStatus.normalize(
        (data['newStatus'] ?? data['status'])?.toString() ?? _currentStatus,
      );

      // Responder dropped out → back to searching, clear their details.
      if (newStatus == 'ACTIVE' && EmergencyStatus.isAssigned(_currentStatus)) {
        final old = _responderMarker;
        setState(() {
          _currentStatus = 'ACTIVE';
          _responderId = null;
          _responderName = null;
          _responderPhone = null;
          _responderProfileImage = null;
          _responderRating = null;
          _responderTotalRatings = null;
          _responderLat = null;
          _responderLong = null;
          _eta = 'Waiting for responder';
          _responderMarker = AnimatedMascotMarker(
            markerId: const MarkerId('responder'),
            infoWindow: const InfoWindow(title: 'Responder'),
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
        _onRouteChanged();
        showMfSnackBar(
          context,
          data['message']?.toString() ?? 'Finding another responder for you…',
          tone: MfTone.info,
        );
        return;
      }

      // Voice alerts for progress — only with Voice Guidance on; deaf patients
      // rely on visual/haptic cues.
      if (newStatus != _currentStatus && !isDeafPatient && settings.voiceGuidanceEnabled) {
        if (newStatus == 'ASSIGNED' || newStatus == 'EN_ROUTE') {
          VoiceAlertService().speakMessage('A responder has been assigned and is on the way.');
        } else if (newStatus == 'ARRIVED') {
          VoiceAlertService().speakMessage('The responder has arrived at your location.');
        }
      }

      setState(() {
        _currentStatus = newStatus;
        if (data['responderId']           != null) _responderId           = data['responderId'].toString();
        if (data['responderName']         != null) _responderName         = data['responderName'].toString();
        if (data['responderPhone']        != null) _responderPhone        = data['responderPhone'].toString();
        if (data['responderProfileImage'] != null) _responderProfileImage = data['responderProfileImage'].toString();
        if (data['responderRating']       != null) _responderRating       = double.tryParse(data['responderRating'].toString());
        if (data['responderTotalRatings'] != null) _responderTotalRatings = int.tryParse(data['responderTotalRatings'].toString());
        if (data['responderType']         != null) _responderType         = data['responderType'].toString();
        if (data['motorbikeNumber']       != null) _motorbikeNumber       = data['motorbikeNumber'].toString();
        if (data['vehicleType']           != null) _vehicleType           = data['vehicleType'].toString();
        if (data['organization']          != null) _organization          = data['organization'].toString();
        if (_responderId != null && _eta == 'Waiting for responder') _eta = 'Calculating…';
      });

      if (newStatus == 'ARRIVED') {
        _raiseArrivedVisualAlert();
        if (isDeafPatient && settings.vibrationFeedback) {
          HapticFeedbackService.sosPattern();
        }
      }
      _handleTerminalStatus();
    } else if (message.event == SocketEvent.responderLocationUpdate) {
      final lat = double.tryParse(data['latitude']?.toString() ?? '');
      final lng = double.tryParse(data['longitude']?.toString() ?? '');
      if (lat == null || lng == null) return;
      _applyResponderPosition(lat, lng, data['estimatedArrivalMinutes'] ?? data['etaMinutes']);
    } else if (message.event == SocketEvent.responderArrived) {
      if (_currentStatus != 'ARRIVED') {
        setState(() => _currentStatus = 'ARRIVED');
        _raiseArrivedVisualAlert();
      }
    }
  }

  /// Cancelled elsewhere (auto-cancel, another device): leave with a message.
  void _handleTerminalStatus() {
    if (!mounted || _leftForTerminal || !EmergencyStatus.isCancelled(_currentStatus)) return;
    _leftForTerminal = true;
    SocketService.instance.forgetEmergencyRooms(widget.emergencyId);
    showMfSnackBar(
      context,
      'This emergency was cancelled. If you still need help, call 1122.',
      tone: MfTone.warning,
    );
    context.go('/home');
  }

  Set<Marker> _patientMarkers(Emergency emergency) {
    _patientLatLng = LatLng(emergency.latitude, emergency.longitude);
    // During simulation the Flutter overlay widgets replace the markers.
    if (_simActive) return {};
    return {
      Marker(
        markerId: const MarkerId('patient'),
        position: _patientLatLng!,
        infoWindow: const InfoWindow(title: 'SOS location'),
        icon: _patientIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  /// The mascot glides along the road route instead of cutting across blocks.
  void _onRouteChanged() {
    final r = _route.route.value;
    _responderMarker.setPath(r == null || r.isFallback ? null : r.points);
  }

  void _animateToResponder() {
    if (_responderLat == null || _responderLong == null) return;
    _camera.keepInView(
      _mapController,
      responder: LatLng(_responderLat!, _responderLong!),
      patient: _patientLatLng,
    );
  }

  // Recomputes screen-pixel positions for both overlay widgets after any
  // camera move or GPS update. Only active during simulation.
  Future<void> _updateOverlayPositions() async {
    if (!mounted || _mapController == null) return;

    if (_patientLatLng != null) {
      try {
        final c = await _mapController!.getScreenCoordinate(_patientLatLng!);
        if (mounted) setState(() => _patientScreenCoord = c);
      } catch (_) {}
    }

    if (_responderLat != null && _responderLong != null) {
      try {
        final c = await _mapController!.getScreenCoordinate(
          LatLng(_responderLat!, _responderLong!),
        );
        if (mounted) setState(() => _responderScreenCoord = c);
      } catch (_) {}
    }
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude  * math.pi / 180;
    final lat2 = to.latitude    * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
               math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilityProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isDeafPatient = (user?.patientType?.toUpperCase() == 'DEAF') || settings.textOnlyMode;
    _simActive = ref.watch(simulationModeProvider); // keep marker logic in sync
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));

    final theme = AppTheme.buildTheme(settings);

    return Theme(
      data: theme,
      child: emergencyAsync.when(
        data: (emergency) => Scaffold(
          body: _buildBody(context, emergency, user, isDeafPatient),
        ),
        loading: () => MfScaffold(
          title: 'Live tracking',
          onBack: () => context.go('/home'),
          body: const MfLoading(label: 'Loading emergency status'),
        ),
        error: (e, _) => MfScaffold(
          title: 'Live tracking',
          onBack: () => context.go('/home'),
          body: MfErrorState(
            title: 'Could not load emergency status',
            message: '$e',
            onRetry: () {
              ref.invalidate(getEmergencyProvider(widget.emergencyId));
              _loadInitialState();
            },
          ),
          bottomBar: MfSecondaryButton(
            label: 'Back to home',
            icon: Icons.home_outlined,
            onPressed: () => context.go('/home'),
          ),
        ),
      ),
    );
  }

  Timer? _simTimer;
  void _startSimulation() {
    if (_simTimer != null) return;
    _simTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !ref.read(simulationModeProvider)) {
        timer.cancel();
        _simTimer = null;
        return;
      }

      final emergency = ref.read(getEmergencyProvider(widget.emergencyId)).valueOrNull;
      if (emergency != null) {
        // Compute new position before setState so we can calc bearing cleanly.
        final newLat = (_responderLat  ?? emergency.latitude  + 0.01) - 0.0005;
        final newLng = (_responderLong ?? emergency.longitude + 0.01) - 0.0005;
        final currPos = LatLng(newLat, newLng);

        // Bearing: direction from previous position → new position.
        if (_prevResponderLatLng != null) {
          _currentBearing = _calculateBearing(_prevResponderLatLng!, currPos);
        }
        _prevResponderLatLng = currPos;

        setState(() {
          _responderLat     = newLat;
          _responderLong    = newLng;
          _eta              = '4 min';
          _responderName    = 'Ali Hassan';
          _responderRating  = 4.8;
          _responderTotalRatings = 37; // simulation only
          _responderType    = 'PARAMEDIC';
          _vehicleType      = 'MOTORBIKE_AMBULANCE';
          _motorbikeNumber  = 'LHR-2847';
          _organization     = 'Rescue 1122';
          _currentStatus    = 'EN_ROUTE';
        });

        // Refresh overlay screen-coordinates after each simulated move.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animateToResponder();
            _updateOverlayPositions();
          }
        });
      }
    });
  }

  // ── Quick messages (AAC board) ──────────────────────────────────────────────
  // Eight universal emergency phrases with icons.
  // Tapping one sends it instantly to the assigned responder via emergency chat.

  static const List<Map<String, dynamic>> _emergencyPhrases = [
    {'icon': Icons.emergency_outlined,        'text': 'I need immediate help!'},
    {'icon': Icons.hearing_disabled_outlined, 'text': 'I am Deaf — use text chat.'},
    {'icon': Icons.favorite_outline_rounded,  'text': 'I have chest pain.'},
    {'icon': Icons.air_rounded,               'text': 'I cannot breathe.'},
    {'icon': Icons.bolt_rounded,              'text': 'I am having a seizure.'},
    {'icon': Icons.local_hospital_outlined,   'text': 'Please call an ambulance.'},
    {'icon': Icons.monitor_heart_outlined,    'text': 'I am diabetic — feeling faint.'},
    {'icon': Icons.warning_amber_rounded,     'text': 'I have a drug allergy.'},
  ];

  void _prefetchAiQuickReplies() {
    ref.read(apiClientProvider).getDeafQuickReplies(widget.emergencyId).then((replies) {
      if (mounted && replies.isNotEmpty) setState(() => _aiQuickReplies = replies);
    }).catchError((_) {
      // Static phrases remain the fallback
    });
  }

  void _showQuickMessageBoard(BuildContext context) {
    // Load AI replies from backend on first open; use static phrases as fallback
    if (_aiQuickReplies == null) {
      final apiClient = ref.read(apiClientProvider);
      apiClient.getDeafQuickReplies(widget.emergencyId).then((replies) {
        if (mounted) setState(() => _aiQuickReplies = replies);
      }).catchError((_) {
        // Keep null — falls back to static phrases
      });
    }

    final phrases = _aiQuickReplies ?? _emergencyPhrases;
    final isAi = _aiQuickReplies != null;

    showMfBottomSheet<void>(
      context,
      title: 'Quick messages',
      subtitle: isAi
          ? 'Personalized for your emergency. Tap a message to send it.'
          : 'Tap a message to send it to your responder.',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAi) ...[
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: MfStatusChip(label: 'AI suggested', tone: MfTone.primary, icon: Icons.auto_awesome_outlined),
            ),
            const SizedBox(height: MfSpace.sm),
          ],
          MfListGroup(
            children: phrases.map((phrase) {
              final text = phrase['text'] as String;
              final iconData = isAi
                  ? _iconFromName(phrase['icon'] as String? ?? '')
                  : (phrase['icon'] as IconData);
              return MfIconTile(
                icon: iconData,
                label: text,
                trailing: Icon(Icons.send_rounded, color: Theme.of(ctx).colorScheme.primary),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendQuickMessage(text);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Maps backend icon name strings (Material icon names) to Flutter IconData
  IconData _iconFromName(String name) {
    const map = <String, IconData>{
      'emergency': Icons.emergency_outlined,
      'hearing_disabled': Icons.hearing_disabled_outlined,
      'favorite': Icons.favorite_outline_rounded,
      'air': Icons.air_rounded,
      'bolt': Icons.bolt_rounded,
      'local_hospital': Icons.local_hospital_outlined,
      'monitor_heart': Icons.monitor_heart_outlined,
      'warning_amber': Icons.warning_amber_rounded,
      'medication': Icons.medication_outlined,
      'bloodtype': Icons.bloodtype_outlined,
      'accessible': Icons.accessible_rounded,
      'help': Icons.help_outline_rounded,
      'sick': Icons.sick_outlined,
      'thermostat': Icons.thermostat_rounded,
    };
    return map[name] ?? Icons.chat_bubble_outline_rounded;
  }

  Future<void> _sendQuickMessage(String message) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final room = await repo.createOrGetEmergencyChatRoom(widget.emergencyId);
      final sent = await ref.read(chatMessagesProvider(room.id).notifier).sendMessage(message);
      if (!sent) throw Exception('message was not delivered');
      if (mounted) {
        showMfSnackBar(context, 'Sent: $message', tone: MfTone.success, duration: const Duration(seconds: 3));
      }
    } catch (e) {
      if (mounted) {
        showMfSnackBar(context, 'Could not send: $e', tone: MfTone.danger);
      }
    }
  }

  // ── Layout ──────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, Emergency emergency, User? user, bool isDeafPatient) {
    final cs = Theme.of(context).colorScheme;
    final reducedMotion = MfMotion.reduced(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final mapHeight = height * 0.55;
        final sheetSize = ((height - mapHeight + MfRadius.lg) / height).clamp(0.3, 0.6);

        return Stack(
          children: [
            // 1. Map (top ~55%, extends under the sheet's rounded corner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mapHeight + MfRadius.lg,
              // Only the map rebuilds while the responder mascot animates.
              child: ListenableBuilder(
                listenable: Listenable.merge([_responderMarker.marker, _route.polylines]),
                builder: (context, _) {
                  final responderMarker = _responderMarker.marker.value;
                  return GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(emergency.latitude, emergency.longitude),
                    zoom: 15,
                  ),
                  markers: {
                    ..._patientMarkers(emergency),
                    if (responderMarker != null && !_simActive && EmergencyStatus.isAssigned(_currentStatus))
                      responderMarker,
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  buildingsEnabled: false,
                  indoorViewEnabled: false,
                  tiltGesturesEnabled: false,
                  style: MapUtils.getDarkMapStyle(),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    _mapCover.markReady();
                  },
                  polylines: EmergencyStatus.isAssigned(_currentStatus) && !_simActive
                      ? _route.polylines.value
                      : const <Polyline>{},
                  onCameraIdle: () {
                    // After any camera animation finishes, recalculate overlay positions
                    // so the Flutter widgets stay pinned to the correct lat/lng.
                    if (mounted && _simActive) _updateOverlayPositions();
                  },
                );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mapHeight + MfRadius.lg,
              child: MapLoadingCover(controller: _mapCover, child: const SizedBox.expand()),
            ),

            // ── Simulation overlays ──────────────────────────────────────────
            // Flutter widgets replace the Google Maps markers during simulation.
            // IgnorePointer ensures they never block touch on the map.
            if (_simActive && _patientScreenCoord != null)
              Positioned(
                left: _patientScreenCoord!.x.toDouble() - _PatientPin.width / 2,
                top: _patientScreenCoord!.y.toDouble() - _PatientPin.height,
                child: IgnorePointer(
                  child: _PatientPin(imageUrl: user?.profileImageUrl, name: user?.fullName),
                ),
              ),

            if (_simActive && _responderScreenCoord != null)
              AnimatedPositioned(
                duration: MfMotion.of(context, const Duration(milliseconds: 600)),
                curve: Curves.easeInOut,
                left: _responderScreenCoord!.x.toDouble() - AmbulanceMascot.logicalSize / 2,
                top: _responderScreenCoord!.y.toDouble() - AmbulanceMascot.logicalSize / 2,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: _currentBearing * math.pi / 180,
                    child: const AmbulanceMascotBadge(size: AmbulanceMascot.logicalSize),
                  ),
                ),
              ),

            // 2. Floating header over the map
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MfFloatingHeader(
                title: EmergencyStatus.label(_currentStatus),
                subtitle: _responderId != null || _responderName != null ? 'ETA: $_eta' : 'Live emergency tracking',
                onBack: () => context.go('/home'),
                titleTrailing: const MfStatusChip(
                  label: 'Live',
                  tone: MfTone.success,
                  icon: Icons.fiber_manual_record_rounded,
                ),
              ),
            ),

            // 3. Map control: recenter on responder
            Positioned(
              right: MfSpace.sm,
              top: mapHeight - MfSize.minTouch - MfSpace.sm,
              child: Material(
                color: cs.surface,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: MfRadius.mdAll,
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: MfIconButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Show responder on map',
                  onPressed: _animateToResponder,
                ),
              ),
            ),

            // 4. Bottom panel
            DraggableScrollableSheet(
              initialChildSize: sheetSize,
              minChildSize: sheetSize,
              maxChildSize: 0.92,
              builder: (context, scrollController) =>
                  _buildSheet(context, scrollController, isDeafPatient),
            ),

            // Deaf patients: visual pulse border while help is close.
            if (isDeafPatient && (_currentStatus == 'EN_ROUTE' || _currentStatus == 'ARRIVED'))
              Positioned.fill(
                child: IgnorePointer(
                  child: _AnimatedPulseBorder(
                    color: _currentStatus == 'ARRIVED'
                        ? MfColors.tone(context, MfTone.success).solid
                        : MfColors.tone(context, MfTone.primary).solid,
                    animate: !reducedMotion,
                  ),
                ),
              ),

            // 5. Resolution / completion screen (RESOLVED or legacy COMPLETED)
            if (EmergencyStatus.isResolved(_currentStatus))
              Positioned.fill(child: _buildResolutionOverlay(context)),
          ],
        );
      },
    );
  }

  Widget _buildSheet(BuildContext context, ScrollController scrollController, bool isDeafPatient) {
    final cs = Theme.of(context).colorScheme;
    final terminal = EmergencyStatus.isTerminal(_currentStatus);
    final hasResponder = _responderId != null || _responderName != null;
    // Contact with the responder ends with the emergency
    // In-app calls with the responder while the emergency is open (Deaf: video only)
    final canCall = _responderId != null && !terminal;
    final canCancel = _currentStatus == 'ACTIVE' || _currentStatus == 'PENDING';

    final secondaryActions = <Widget>[
      if (hasResponder && !terminal)
        MfSecondaryButton(
          label: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          semanticLabel: 'Chat with responder',
          onPressed: _openChat,
        ),
      if (canCall && !isDeafPatient)
        MfSecondaryButton(
          label: 'Call',
          icon: Icons.phone_outlined,
          semanticLabel: 'Voice call the responder',
          onPressed: () => startInAppCall(context, _responderCallPeer(), CallMedia.audio),
        ),
      if (canCall)
        MfSecondaryButton(
          label: isDeafPatient ? 'Video call' : 'Video',
          icon: Icons.videocam_outlined,
          semanticLabel: 'Video call the responder',
          onPressed: () => startInAppCall(context, _responderCallPeer(), CallMedia.video),
        ),
      if (isDeafPatient)
        MfSecondaryButton(
          label: 'Show card',
          icon: Icons.badge_outlined,
          semanticLabel: 'Show deaf communication card',
          onPressed: () => context.push('/home/show-card'),
        ),
    ];

    return Material(
      color: cs.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(MfRadius.lg)),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, 0, MfSpace.gutter, MfSpace.lg),
        children: [
          const MfSheetHandle(),

          if (isDeafPatient) ...[
            const MfInfoBanner(
              icon: Icons.hearing_disabled_outlined,
              tone: MfTone.primary,
              title: 'Deaf mode: visual updates on',
              message: 'Status changes flash on screen and vibrate.',
            ),
            const SizedBox(height: MfSpace.sm),
          ],

          _buildResponderCard(context),
          const SizedBox(height: MfSpace.md),

          // ── Actions ──
          if (isDeafPatient && !terminal) ...[
            MfPrimaryButton(
              label: _aiQuickReplies != null ? 'Quick message · AI suggested' : 'Quick message',
              icon: _aiQuickReplies != null ? Icons.auto_awesome_outlined : Icons.textsms_outlined,
              semanticLabel: 'Send a quick message to your responder',
              onPressed: () => _showQuickMessageBoard(context),
            ),
            const SizedBox(height: MfSpace.xs),
          ],
          if (secondaryActions.length == 2 || secondaryActions.length == 3)
            Row(
              children: [
                for (var i = 0; i < secondaryActions.length; i++) ...[
                  if (i > 0) const SizedBox(width: MfSpace.xs),
                  Expanded(child: secondaryActions[i]),
                ],
              ],
            )
          else
            for (final action in secondaryActions)
              Padding(
                padding: const EdgeInsets.only(bottom: MfSpace.xs),
                child: action,
              ),

          const SizedBox(height: MfSpace.md),
          const MfSectionTitle('Live status'),
          const SizedBox(height: MfSpace.xs),
          MfStatusTimeline.emergency(
            status: _currentStatus,
            perspective: MfTimelinePerspective.patient,
          ),

          if (canCancel) ...[
            const SizedBox(height: MfSpace.lg),
            MfSecondaryButton(
              label: 'Cancel SOS',
              icon: Icons.close_rounded,
              tone: MfTone.danger,
              onPressed: _showCancelDialog,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponderCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasResponder = _responderName != null;

    String? distance;
    final patient = _patientLatLng;
    if (_responderLat != null && _responderLong != null && patient != null) {
      distance = GeoUtils.formatDistance(
        GeoUtils.haversineKm(_responderLat!, _responderLong!, patient.latitude, patient.longitude),
      );
    }

    final vehicleLabel = (_vehicleType == 'MOTORBIKE_AMBULANCE' || _vehicleType == null)
        ? 'Motorbike ambulance'
        : _vehicleType!.replaceAll('_', ' ');

    return MfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(MfSpace.md),
            child: Row(
              children: [
                if (hasResponder || _responderProfileImage != null)
                  MfAvatar(imageUrl: _responderProfileImage, name: _responderName, size: 56)
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.surfaceContainer,
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    padding: const EdgeInsets.all(MfSpace.md),
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                  ),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MfStatusChip.emergency(_currentStatus),
                      const SizedBox(height: MfSpace.xxs),
                      Text(
                        _responderName ?? 'Finding a responder…',
                        style: text.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_responderType != null || _responderRating != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Wrap(
                            spacing: MfSpace.xs,
                            runSpacing: MfSpace.xxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_responderType != null)
                                Text(
                                  _formatLabel(_responderType!),
                                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              if (_responderRating != null)
                                ResponderRatingChip(
                                  rating: _responderRating,
                                  totalRatings: _responderTotalRatings,
                                  style: text.labelLarge,
                                ),
                            ],
                          ),
                        ),
                      if (_organization != null)
                        Text(
                          _organization!,
                          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(MfSpace.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MfColors.tone(context, MfTone.primary).container,
                    borderRadius: MfRadius.smAll,
                  ),
                  child: Icon(Icons.two_wheeler_rounded, size: 22, color: MfColors.tone(context, MfTone.primary).foreground),
                ),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicleLabel, style: text.titleSmall),
                      Text(
                        'Emergency response vehicle',
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MfSpace.xs),
                Semantics(
                  label: 'Bike plate ${_motorbikeNumber ?? 'not available'}',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: MfSpace.xs, vertical: MfSpace.xxs),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: MfRadius.smAll,
                      border: Border.all(color: cs.onSurface, width: 1.5),
                    ),
                    child: Text(
                      (_motorbikeNumber ?? 'N/A').toUpperCase(),
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MfSpace.xxs),
            child: Row(
              children: [
                Expanded(child: MfKeyValueRow(label: 'ETA', value: _eta, icon: Icons.schedule_rounded)),
                Expanded(
                  child: MfKeyValueRow(
                    label: 'Distance',
                    value: distance ?? '—',
                    icon: Icons.place_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatLabel(String raw) {
    final words = raw.replaceAll('_', ' ').toLowerCase().split(' ').where((w) => w.isNotEmpty);
    final joined = words.join(' ');
    return joined.isEmpty ? raw : joined[0].toUpperCase() + joined.substring(1);
  }

  CallPeer _responderCallPeer() => CallPeer(
        id: _responderId!,
        name: _responderName ?? 'Responder',
        imageUrl: _responderProfileImage,
        phoneNumber: _responderPhone,
      );

  void _openChat() async {
    // Show a loading indicator while we create/get the chat room
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MfLoading(),
    );

    try {
      final repo = ref.read(chatRepositoryProvider);
      final room = await repo.createOrGetEmergencyChatRoom(widget.emergencyId);
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        context.push('/chat/${room.id}', extra: _responderName ?? 'Responder');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        showMfSnackBar(context, 'Could not open chat: $e', tone: MfTone.danger);
      }
    }
  }

  Widget _buildResolutionOverlay(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final success = MfColors.tone(context, MfTone.success);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MfSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: success.container,
                        shape: BoxShape.circle,
                        border: Border.all(color: success.border),
                      ),
                      child: Icon(Icons.check_circle_outline_rounded, color: success.solid, size: 44),
                    ),
                  ),
                  const SizedBox(height: MfSpace.lg),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text('Emergency resolved', textAlign: TextAlign.center, style: text.headlineSmall),
                  ),
                  const SizedBox(height: MfSpace.xs),
                  Text(
                    'Help has been provided and the situation is now under control.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: MfSpace.xl),

                  if (!_ratingSubmitted && _responderId != null) ...[
                    MfCard(
                      padding: const EdgeInsets.all(MfSpace.md),
                      child: Column(
                        children: [
                          Text('Rate your responder', textAlign: TextAlign.center, style: text.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            'How was your experience?',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: MfSpace.sm),
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: List.generate(5, (i) {
                              final star = i + 1;
                              final filled = _selectedStars >= star;
                              return IconButton(
                                tooltip: star == 1 ? '1 star' : '$star stars',
                                isSelected: filled,
                                constraints: const BoxConstraints(minWidth: MfSize.minTouch, minHeight: MfSize.minTouch),
                                onPressed: () => setState(() => _selectedStars = star),
                                icon: Icon(
                                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: filled ? MfColors.warning(context) : cs.outline,
                                  size: 36,
                                ),
                              );
                            }),
                          ),
                          if (_selectedStars > 0) ...[
                            const SizedBox(height: MfSpace.sm),
                            MfPrimaryButton(
                              label: 'Submit rating',
                              onPressed: () async {
                                final responderId = _responderId!;
                                final stars = _selectedStars;
                                setState(() => _ratingSubmitted = true);
                                try {
                                  await ref.read(rateResponderProvider(RateResponderParams(
                                    responderId: responderId,
                                    emergencyId: widget.emergencyId,
                                    stars: stars,
                                  )).future);
                                } catch (_) {}
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: MfSpace.sm),
                    Center(
                      child: MfTextButton(
                        label: 'Skip',
                        onPressed: () => context.go('/home'),
                      ),
                    ),
                  ] else ...[
                    if (_ratingSubmitted) ...[
                      const MfInfoBanner(
                        icon: Icons.check_circle_outline_rounded,
                        tone: MfTone.success,
                        title: 'Thanks for your feedback',
                      ),
                      const SizedBox(height: MfSpace.md),
                    ],
                    MfPrimaryButton(
                      label: 'Back to home',
                      icon: Icons.home_outlined,
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Cancel SOS?',
      message: 'Are you sure you want to cancel the active emergency?',
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep waiting',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(cancelEmergencyProvider(widget.emergencyId).future);
      SocketService.instance.forgetEmergencyRooms(widget.emergencyId);
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      showMfSnackBar(
        context,
        msg.contains('expired')
            ? 'Too late to cancel. Responders are already being dispatched.'
            : msg.contains('not active')
                ? 'A responder has already accepted, so this can no longer be cancelled.'
                : 'Could not cancel: $e',
        tone: MfTone.danger,
      );
    }
  }
}

/// Patient location pin used on the map during simulation mode.
class _PatientPin extends StatelessWidget {
  static const double width = 52;
  static const double height = 64;

  final String? imageUrl;
  final String? name;
  const _PatientPin({this.imageUrl, this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sos = MfColors.sos(context);
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
              border: Border.all(color: sos, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
            ),
            child: MfAvatar(imageUrl: imageUrl, name: name, size: 40),
          ),
          Container(width: 2, height: 10, color: sos),
          Container(
            width: 8,
            height: 4,
            decoration: BoxDecoration(
              color: sos.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.all(Radius.elliptical(4, 2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen-edge border for deaf patients. Pulses gently unless reduced motion
/// is on, in which case it is shown as a static border.
class _AnimatedPulseBorder extends StatefulWidget {
  final Color color;
  final bool animate;
  const _AnimatedPulseBorder({required this.color, this.animate = true});

  @override
  State<_AnimatedPulseBorder> createState() => _AnimatedPulseBorderState();
}

class _AnimatedPulseBorderState extends State<_AnimatedPulseBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _opacity = Tween<double>(begin: 0.15, end: 0.6).animate(_controller);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedPulseBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: widget.color.withValues(alpha: 0.5), width: 8),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.color.withValues(alpha: _opacity.value),
            width: 8,
          ),
        ),
      ),
    );
  }
}
