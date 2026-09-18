import 'dart:async';
import '../../widgets/call/call_launcher.dart';
import '../../../services/call/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/emergency_status.dart';
import '../../../core/utils/exceptions.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/entities/emergency.dart' as emergency_entity;
import '../../../services/audio/voice_alert_service.dart';
import '../../../services/location/location_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/map/ambulance_mascot.dart';
import '../../theme/app_theme.dart';
import '../../../core/utils/map_utils.dart';
import '../../widgets/map/route_line.dart';
import '../../widgets/map/map_loading_cover.dart';
import 'widgets/responder_widgets.dart';

/// How a responder closed an emergency (sent to the resolve API).
class _ResolveOutcome {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final bool noteRequired;
  const _ResolveOutcome(this.value, this.label, this.description, this.icon, {this.noteRequired = false});
}

const _resolveOutcomes = [
  _ResolveOutcome('TREATED', 'Treated on site', 'Care was given and no transport was needed', Icons.healing_outlined),
  _ResolveOutcome('TRANSPORTED', 'Transported to hospital', 'The patient was taken to a hospital', Icons.local_hospital_outlined),
  _ResolveOutcome('FALSE_ALARM', 'False alarm', 'There was no medical emergency', Icons.report_outlined, noteRequired: true),
  _ResolveOutcome('PATIENT_NOT_FOUND', 'Patient not found', 'The patient could not be located at the scene', Icons.person_search_outlined, noteRequired: true),
];

const _resolveNoteMaxLength = 300;

class ActiveEmergencyScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const ActiveEmergencyScreen({super.key, required this.emergencyId});

  @override
  ConsumerState<ActiveEmergencyScreen> createState() => _ActiveEmergencyScreenState();
}

class _ActiveEmergencyScreenState extends ConsumerState<ActiveEmergencyScreen> {
  GoogleMapController? _mapController;
  final _mapCover = MapCoverController();

  /// UI step: ACCEPTED → EN_ROUTE → ARRIVED → RESOLVED (or CANCELLED).
  String _currentStatus = 'ACCEPTED';
  bool _statusLoaded = false;
  bool _isUpdatingStatus = false;
  bool _isCancelling = false;
  bool _followMe = true;
  bool _isPlayingVoice = false;
  String? _locationError;

  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<SocketMessage>? _socketSub;

  double? _myLat;
  double? _myLng;

  /// Road route from me to the patient, plus the patient's position.
  final RouteLine _route = RouteLine(color: AppColors.primary);
  LatLng? _patientPosition;

  /// Animated motorbike-ambulance marker for "me".
  Timer? _followTimer;

  final AnimatedMascotMarker _meMarker = AnimatedMascotMarker(
    markerId: const MarkerId('me'),
    infoWindow: const InfoWindow(title: 'You'),
  );

  bool _showFullMedicalDetails = false;

  static const List<({String status, String label, String action, IconData icon})> _statusSteps = [
    (status: 'ACCEPTED', label: 'Accepted', action: 'Accept', icon: Icons.check_circle_outline_rounded),
    (status: 'EN_ROUTE', label: 'On the way', action: 'Start driving: mark on the way', icon: Icons.two_wheeler_rounded),
    (status: 'ARRIVED', label: 'Arrived', action: 'Mark arrived at scene', icon: Icons.location_on_outlined),
    (status: 'RESOLVED', label: 'Resolved', action: 'Resolve emergency', icon: Icons.task_alt_rounded),
  ];

  /// One-tap messages for deaf patients (sent straight into the chat).
  static const _deafQuickMessages = [
    'I am on my way.',
    'I have arrived. Please open the door.',
    'Where exactly are you?',
    'Stay still. Help is here.',
  ];

  /// Full quick-message list (sheet).
  static const _allQuickMessages = [
    'I am on my way.',
    'I am almost there.',
    'I have arrived. Please open the door.',
    'Where exactly are you in the building?',
    'Stay still. Help is here.',
    'Can you move, or is the pain too severe?',
    'I have pain medication with me.',
    'I am contacting the hospital now.',
  ];

  static const double _avgSpeedKmh = 40;

  @override
  void initState() {
    super.initState();
    SocketService.instance.joinEmergencyRoom(widget.emergencyId);
    _socketSub = SocketService.instance.messageStream.listen(_onSocketMessage);
    _route.route.addListener(_onRouteChanged);
    // Pan with the gliding marker instead of jumping to each raw GPS fix
    _followTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final pos = _meMarker.displayPosition;
      if (!mounted || !_followMe || _mapController == null || pos == null) return;
      // Stay on the patient while my GPS fix is implausible (hundreds of km away)
      final target = _isPlausibleFrom(pos) ? pos : _patientPosition;
      if (target == null) return;
      _mapController!.animateCamera(CameraUpdate.newLatLng(target), duration: const Duration(milliseconds: 1000)).catchError((_) {});
    });
    _loadInitialStatus();
    Future.microtask(() async {
      final voiceEnabled = ref.read(accessibilityProvider).voiceGuidanceEnabled;
      if (!voiceEnabled) return; // Responder has disabled voice alerts

      try {
        final emergency = await ref.read(getEmergencyProvider(widget.emergencyId).future);
        final profile = await ref.read(getMedicalProfileProvider(emergency.userId).future);
        if (profile != null &&
            (profile.patientType.toUpperCase() == 'DEAF' || emergency.patientType.toUpperCase() == 'DEAF')) {
          await VoiceAlertService().speakAutomatedEmergencyReport(
            emergency: emergency,
            medical: profile,
          );
        } else {
          await VoiceAlertService().announceResponderAssigned('the Patient');
        }
      } catch (e) {
        debugPrint('Voice briefing skipped: $e');
      }
    });
    _warmPatientMarker();
    _startLiveTracking();
  }

  /// Maps a server emergency/tracking status onto the responder's UI steps.
  static String? _uiStatusFor(String? raw) {
    final status = EmergencyStatus.normalize(raw);
    if (EmergencyStatus.isResolved(status)) return 'RESOLVED';
    if (EmergencyStatus.isCancelled(status)) return 'CANCELLED';
    switch (status) {
      case 'EN_ROUTE':
        return 'EN_ROUTE';
      case 'ARRIVED':
      case 'TREATING':
      case 'TRANSPORTED':
        return 'ARRIVED';
      case 'ASSIGNED':
      case 'ACCEPTED':
      case 'RESPONDER_ASSIGNED':
        return 'ACCEPTED';
      default:
        return null;
    }
  }

  int _rank(String uiStatus) => _statusSteps.indexWhere((s) => s.status == uiStatus);

  /// Initial status from the server (emergency status + latest tracking
  /// status, which carries EN_ROUTE) instead of assuming "ACCEPTED".
  Future<void> _loadInitialStatus() async {
    String status = 'ACCEPTED';
    try {
      final repo = await ref.read(emergencyRepositoryProvider.future);
      final emergency = await repo.getEmergency(widget.emergencyId);
      status = _uiStatusFor(emergency.status) ?? status;

      if (status == 'ACCEPTED') {
        try {
          final latest = await ref.read(apiClientProvider).getLatestTracking(widget.emergencyId);
          final trackingStatus = latest is Map ? _uiStatusFor(latest['status']?.toString()) : null;
          if (trackingStatus != null && _rank(trackingStatus) > _rank(status)) {
            status = trackingStatus;
          }
        } catch (_) {
          // No tracking yet — keep the emergency status.
        }
      }
    } catch (e) {
      debugPrint('Could not load emergency status: $e');
    }
    if (!mounted) return;
    setState(() {
      // Don't regress a status the socket already advanced.
      if (!_statusLoaded || _rank(status) > _rank(_currentStatus) || status == 'CANCELLED') {
        _currentStatus = status;
      }
      _statusLoaded = true;
    });
  }

  void _onSocketMessage(SocketMessage message) {
    if (message.event != SocketEvent.emergencyStatusChange || message.data is! Map) return;
    final data = message.data as Map;
    if (data['emergencyId']?.toString() != widget.emergencyId) return;
    final ui = _uiStatusFor((data['newStatus'] ?? data['status'])?.toString());
    if (ui == null || !mounted) return;

    if (ui == 'CANCELLED' && _currentStatus != 'CANCELLED') {
      setState(() => _currentStatus = 'CANCELLED');
      showMfSnackBar(context, 'The patient cancelled this emergency.', tone: MfTone.warning);
    } else if (ui != 'CANCELLED' && _rank(ui) > _rank(_currentStatus)) {
      setState(() => _currentStatus = ui);
    }
  }

  void _warmPatientMarker() {
    MapUtils.getPatientMarker().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _startLiveTracking() {
    _locationSubscription = LocationService().startLocationUpdates(
      intervalInSeconds: 5,
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _myLat = position.latitude;
        _myLng = position.longitude;
        _locationError = null;
      });
      final me = LatLng(position.latitude, position.longitude);
      _meMarker.moveTo(me);
      // No route from a bad GPS fix hundreds of km away (it would draw a line off the map)
      if (_isPlausibleFrom(me)) {
        _route.update(me, _patientPosition);
      } else {
        _route.clear();
      }

      if (!EmergencyStatus.isTerminal(_currentStatus)) {
        SocketService.instance.sendLocationUpdate(
          widget.emergencyId,
          position.latitude,
          position.longitude,
          _currentStatus,
        );
      }

    }, onError: (Object e) {
      if (mounted) {
        setState(() => _locationError = e is AppException ? e.message : LocationService.unavailableMessage);
      }
    });
  }

  void _animateToMe() {
    final pos = _meMarker.displayPosition ?? (_myLat != null && _myLng != null ? LatLng(_myLat!, _myLng!) : null);
    if (_mapController != null && pos != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  /// The mascot glides along the road route instead of cutting across blocks.
  void _onRouteChanged() {
    final r = _route.route.value;
    _meMarker.setPath(r == null || r.isFallback ? null : r.points);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _followTimer?.cancel();
    _socketSub?.cancel();
    _meMarker.dispose();
    _route.dispose();
    _mapCover.dispose();
    if (_isPlayingVoice) VoiceAlertService().stop();
    super.dispose();
  }

  bool _isPlausibleFrom(LatLng me) {
    final p = _patientPosition;
    if (p == null) return true;
    return GeoUtils.isPlausible(GeoUtils.haversineKm(me.latitude, me.longitude, p.latitude, p.longitude));
  }

  double? _distanceKm(emergency_entity.Emergency emergency) {
    if (_myLat == null || _myLng == null) return null;
    final km = GeoUtils.haversineKm(_myLat!, _myLng!, emergency.latitude, emergency.longitude);
    return GeoUtils.isPlausible(km) ? km : null;
  }

  Future<void> _openNavigation(emergency_entity.Emergency emergency) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${emergency.latitude},${emergency.longitude}'
      '&travelmode=driving',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      if (mounted) showMfSnackBar(context, 'Could not open Google Maps.', tone: MfTone.danger);
    }
  }

  // ── Voice alert ──────────────────────────────────────────────────────────
  /// Manual "Play voice alert": always available, independent of the voice
  /// guidance setting (which only controls the automatic briefing).
  Future<void> _toggleVoiceAlert(emergency_entity.Emergency emergency) async {
    if (_isPlayingVoice) {
      setState(() => _isPlayingVoice = false);
      await VoiceAlertService().stop();
      return;
    }
    setState(() => _isPlayingVoice = true);
    try {
      final profile = await ref.read(getMedicalProfileProvider(emergency.userId).future);
      if (profile != null) {
        await VoiceAlertService().speakAutomatedEmergencyReport(emergency: emergency, medical: profile);
      } else {
        await VoiceAlertService().speakEmergencyAlert(emergency);
      }
    } catch (e) {
      debugPrint('Voice alert failed: $e');
      if (mounted) showMfSnackBar(context, 'Could not play the voice alert.', tone: MfTone.danger);
    } finally {
      if (mounted) setState(() => _isPlayingVoice = false);
    }
  }

  // ── Status ───────────────────────────────────────────────────────────────
  Future<void> _updateStatus(String newStatus, {String? outcome, String? note}) async {
    if (_isUpdatingStatus) return;

    final previous = _currentStatus;
    setState(() {
      _currentStatus = newStatus; // optimistic
      _isUpdatingStatus = true;
    });
    try {
      if (newStatus == 'RESOLVED') {
        final repo = await ref.read(emergencyRepositoryProvider.future);
        await repo.resolveEmergency(widget.emergencyId, outcome: outcome, note: note);
        ref.invalidate(getEmergencyProvider(widget.emergencyId));
        ref.invalidate(getActiveEmergenciesProvider);
        // Resolving makes the responder available again on the server
        ref.invalidate(currentUserProvider);
        SocketService.instance.forgetEmergencyRooms(widget.emergencyId);
      } else {
        await ref.read(updateEmergencyStatusProvider(
          UpdateEmergencyStatusParams(
            emergencyId: widget.emergencyId,
            status: newStatus,
            latitude: _myLat,
            longitude: _myLng,
          ),
        ).future);
      }
      if (mounted) {
        showMfSnackBar(context, 'Status updated: ${EmergencyStatus.label(newStatus)}', tone: MfTone.success);
      }
    } catch (e) {
      debugPrint('Status update failed: $e');
      if (mounted) {
        setState(() => _currentStatus = previous); // revert
        showMfSnackBar(
          context,
          'Could not update status. ${e.toString().replaceAll('Exception:', '').trim()}',
          tone: MfTone.danger,
          actionLabel: 'Retry',
          onAction: () => _updateStatus(newStatus, outcome: outcome, note: note),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _advanceStatus() async {
    final nextIdx = _rank(_currentStatus) + 1;
    if (nextIdx >= _statusSteps.length) return;
    final next = _statusSteps[nextIdx].status;
    if (next == 'RESOLVED') {
      await _startResolveFlow();
    } else {
      await _updateStatus(next);
    }
  }

  /// "How did this emergency end?" → optional confirm → resolve API.
  Future<void> _startResolveFlow() async {
    final result = await showMfBottomSheet<({String outcome, String note})>(
      context,
      title: 'How did this emergency end?',
      subtitle: 'Choose one. This is recorded with the emergency.',
      builder: (ctx) => const _ResolveOutcomeForm(),
    );
    if (result == null || !mounted) return;

    if (result.outcome == 'FALSE_ALARM') {
      final confirmed = await showMfConfirmDialog(
        context,
        icon: Icons.report_outlined,
        title: 'Report a false alarm?',
        message: "This will be recorded on the patient's account.",
        confirmLabel: 'Report false alarm',
        cancelLabel: 'Go back',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    await _updateStatus('RESOLVED', outcome: result.outcome, note: result.note);
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showMfConfirmDialog(
      context,
      icon: Icons.cancel_outlined,
      title: 'Cancel your response?',
      message: 'The request will be sent to other nearby responders. The patient will be told a new responder is being found.',
      confirmLabel: 'Cancel response',
      cancelLabel: 'Keep responding',
      destructive: true,
    );
    if (confirmed && mounted) _handleCancellation();
  }

  Future<void> _handleCancellation() async {
    setState(() => _isCancelling = true);
    try {
      await ref.read(cancelResponderAssignmentProvider(widget.emergencyId).future);
      if (mounted) {
        showMfSnackBar(context, 'Response cancelled. Returning to dashboard.');
        context.go('/responder');
      }
    } catch (e) {
      if (mounted) {
        showMfSnackBar(
          context,
          'Could not cancel. ${e.toString().replaceAll('Exception:', '').trim()}',
          tone: MfTone.danger,
          actionLabel: 'Retry',
          onAction: _handleCancellation,
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  // ── Chat ─────────────────────────────────────────────────────────────────
  Future<ChatRoom> _emergencyChatRoom(emergency_entity.Emergency emergency) {
    final repo = ref.read(chatRepositoryProvider);
    // Responder creates the room with patientId as targetUserId + emergencyId
    return repo.createOrGetChatRoom(
      emergency.userId,
      emergencyId: widget.emergencyId,
    );
  }

  String _patientName(emergency_entity.Emergency emergency) {
    final name = ref.read(userProfileProvider(emergency.userId)).valueOrNull?.fullName.trim();
    return (name == null || name.isEmpty) ? 'Patient' : name;
  }

  Future<void> _openEmergencyChat(emergency_entity.Emergency emergency) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MfLoading(label: 'Opening chat'),
    );
    try {
      final room = await _emergencyChatRoom(emergency);
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/chat/${room.id}', extra: _patientName(emergency));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showMfSnackBar(
        context,
        'Could not open chat. Check your connection.',
        tone: MfTone.danger,
        actionLabel: 'Retry',
        onAction: () => _openEmergencyChat(emergency),
      );
    }
  }

  /// Sends a predefined message straight into the emergency chat.
  Future<void> _sendQuickMessage(emergency_entity.Emergency emergency, String text) async {
    try {
      final room = await _emergencyChatRoom(emergency);
      await ref.read(chatRepositoryProvider).sendMessage(room.id, text, type: MessageType.TEXT);
      if (!mounted) return;
      showMfSnackBar(
        context,
        'Sent: "$text"',
        tone: MfTone.success,
        actionLabel: 'Open chat',
        onAction: () {
          if (mounted) context.push('/chat/${room.id}', extra: _patientName(emergency));
        },
      );
    } catch (e) {
      if (!mounted) return;
      showMfSnackBar(
        context,
        'Message not sent. Check your connection.',
        tone: MfTone.danger,
        actionLabel: 'Retry',
        onAction: () => _sendQuickMessage(emergency, text),
      );
    }
  }

  void _showQuickMessages(emergency_entity.Emergency emergency) {
    showMfBottomSheet<void>(
      context,
      title: 'Quick messages',
      subtitle: "Tap a message to send it to the patient's chat",
      builder: (ctx) => MfCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _allQuickMessages.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
              ListTile(
                minVerticalPadding: MfSpace.sm,
                title: Text(_allQuickMessages[i]),
                trailing: const Icon(Icons.send_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendQuickMessage(emergency, _allQuickMessages[i]);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Set<Marker> _patientMarkers(emergency_entity.Emergency emergency) => {
        Marker(
          markerId: const MarkerId('patient'),
          position: LatLng(emergency.latitude, emergency.longitude),
          infoWindow: const InfoWindow(title: 'Patient location'),
          icon: MapUtils.patientMarkerOrDefault,
          anchor: const Offset(0.5, 1.0),
        ),
      };

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));
    final isCancelled = _currentStatus == 'CANCELLED';
    final isResolved = _currentStatus == 'RESOLVED';
    final isClosed = isCancelled || isResolved;

    final patientName = emergencyAsync.valueOrNull == null
        ? null
        : ref.watch(userProfileProvider(emergencyAsync.value!.userId)).valueOrNull?.fullName;

    return Scaffold(
      appBar: MfHeader(
        title: 'Active emergency',
        subtitle: patientName,
        onBack: () => context.go('/responder'),
        actions: [
          if (emergencyAsync.hasValue && !isClosed)
            MfIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Open chat with patient',
              onPressed: () => _openEmergencyChat(emergencyAsync.value!),
            ),
        ],
      ),
      bottomNavigationBar: emergencyAsync.hasValue ? _buildBottomActions(emergencyAsync.value!) : null,
      body: emergencyAsync.when(
        data: (emergency) => _buildBody(emergency),
        loading: () => const MfLoading(label: 'Loading emergency'),
        error: (e, _) => MfErrorState(
          title: 'Could not load this emergency',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(getEmergencyProvider(widget.emergencyId)),
        ),
      ),
    );
  }

  Widget _buildBottomActions(emergency_entity.Emergency emergency) {
    final isCancelled = _currentStatus == 'CANCELLED';
    final isResolved = _currentStatus == 'RESOLVED';
    if (isCancelled || isResolved) {
      return MfBottomActionBar(
        child: MfPrimaryButton(
          label: 'Return to dashboard',
          icon: Icons.dashboard_outlined,
          onPressed: () => context.go('/responder'),
        ),
      );
    }
    final nextIdx = _rank(_currentStatus) + 1;
    final next = nextIdx < _statusSteps.length ? _statusSteps[nextIdx] : null;
    return MfBottomActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (next != null)
            MfPrimaryButton(
              label: next.action,
              icon: next.icon,
              tone: next.status == 'RESOLVED' ? MfTone.success : MfTone.primary,
              loading: _isUpdatingStatus || !_statusLoaded,
              onPressed: _advanceStatus,
            ),
          const SizedBox(height: MfSpace.xs),
          MfSecondaryButton(
            label: 'Navigate with Google Maps',
            icon: Icons.navigation_outlined,
            onPressed: () => _openNavigation(emergency),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(emergency_entity.Emergency emergency) {
    final isDeafPatient = emergency.patientType.toUpperCase() == 'DEAF';
    final isCancelled = _currentStatus == 'CANCELLED';
    final isResolved = _currentStatus == 'RESOLVED';
    final isClosed = isCancelled || isResolved;
    final distanceKm = _distanceKm(emergency);
    final etaMin = distanceKm == null ? null : GeoUtils.etaMinutes(distanceKm, speedKmh: _avgSpeedKmh);
    final etaText = etaMin == null ? 'Locating you' : (etaMin == 0 ? 'Arriving' : '$etaMin min');
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.38).clamp(240.0, 420.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
      children: [
        // ── Deaf patient: communicate by text only ─────────────────────
        if (isDeafPatient && !isClosed) ...[
          ResponderDeafCommsCard(
            message: 'Do not call. Use visual cues and text chat.',
            quickMessages: _deafQuickMessages,
            onQuickMessage: (m) => _sendQuickMessage(emergency, m),
            onOpenChat: () => _openEmergencyChat(emergency),
            onMoreMessages: () => _showQuickMessages(emergency),
          ),
          const SizedBox(height: MfSpace.md),
        ],
        if (isCancelled) ...[
          const MfInfoBanner(
            icon: Icons.block_rounded,
            tone: MfTone.neutral,
            title: 'Emergency cancelled',
            message: 'The patient cancelled this emergency. No further action is needed.',
          ),
          const SizedBox(height: MfSpace.md),
        ],
        if (isResolved) ...[
          const MfInfoBanner(
            icon: Icons.task_alt_rounded,
            tone: MfTone.success,
            title: 'Emergency resolved',
            message: 'The patient and their caregivers have been notified. Thank you.',
          ),
          const SizedBox(height: MfSpace.md),
        ],
        if (_locationError != null) ...[
          MfInfoBanner(
            icon: Icons.location_off_outlined,
            tone: MfTone.warning,
            title: 'Location unavailable',
            message: _locationError,
          ),
          const SizedBox(height: MfSpace.md),
        ],

        // ── Map ────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: MfRadius.mdAll,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: MfRadius.mdAll,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: SizedBox(
              height: mapHeight,
              child: Stack(
                children: [
                  // Only the map rebuilds when the mascot animates.
                  ListenableBuilder(
                    listenable: Listenable.merge([_meMarker.marker, _route.polylines]),
                    builder: (context, _) {
                      final me = _meMarker.marker.value;
                      if (_patientPosition == null) {
                        _patientPosition = LatLng(emergency.latitude, emergency.longitude);
                        final meNow = _meMarker.position;
                        if (meNow != null && _isPlausibleFrom(meNow)) _route.update(meNow, _patientPosition);
                      }
                      return GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(emergency.latitude, emergency.longitude),
                          zoom: 15,
                        ),
                        markers: {..._patientMarkers(emergency), if (me != null && _distanceKm(emergency) != null) me},
                        polylines: EmergencyStatus.isTerminal(_currentStatus)
                            ? const <Polyline>{}
                            : _route.polylines.value,
                        style: MapUtils.getLightMapStyle(),
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _mapCover.markReady();
                        },
                      );
                    },
                  ),
                  Positioned.fill(child: MapLoadingCover(controller: _mapCover, child: const SizedBox.expand())),
                  Positioned(
                    top: MfSpace.xs,
                    right: MfSpace.xs,
                    child: _MapSurface(
                      child: MfIconButton(
                        tooltip: _followMe ? 'Stop following my location' : 'Follow my location',
                        icon: _followMe ? Icons.my_location_rounded : Icons.location_searching_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          setState(() => _followMe = !_followMe);
                          if (_followMe) _animateToMe();
                        },
                      ),
                    ),
                  ),
                  if (!isClosed)
                    Positioned(
                      left: MfSpace.xs,
                      bottom: MfSpace.xs,
                      child: Semantics(
                        liveRegion: true,
                        label: 'Estimated arrival $etaText. '
                            '${distanceKm == null ? 'Waiting for GPS' : '${GeoUtils.formatDistance(distanceKm)} away'}',
                        excludeSemantics: true,
                        child: _MapSurface(
                          padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm, vertical: MfSpace.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: MfSpace.xs),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(etaText, style: Theme.of(context).textTheme.titleMedium),
                                  Text(
                                    distanceKm == null ? 'Waiting for GPS' : '${GeoUtils.formatDistance(distanceKm)} away',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: MfSpace.md),

        // ── Progress ───────────────────────────────────────────────────
        MfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: MfSectionTitle('Response progress', padding: EdgeInsets.zero)),
                  if (_statusLoaded) MfStatusChip.emergency(_currentStatus),
                ],
              ),
              const SizedBox(height: MfSpace.md),
              MfStatusTimeline(
                currentIndex: isCancelled ? 0 : _rank(_currentStatus).clamp(0, _statusSteps.length - 1),
                cancelled: isCancelled,
                completed: isResolved,
                steps: [for (final s in _statusSteps) MfTimelineStep(s.label, s.icon)],
              ),
            ],
          ),
        ),
        const SizedBox(height: MfSpace.lg),

        // ── Patient ────────────────────────────────────────────────────
        _buildPatientInfo(emergency),
        const SizedBox(height: MfSpace.lg),

        // ── Communication ──────────────────────────────────────────────
        if (!isClosed) ...[
          const MfSectionTitle('Communication'),
          Row(
            children: [
              Expanded(
                child: MfSecondaryButton(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => _openEmergencyChat(emergency),
                ),
              ),
              const SizedBox(width: MfSpace.xs),
              Expanded(
                child: MfSecondaryButton(
                  label: 'Quick messages',
                  icon: Icons.quickreply_outlined,
                  onPressed: () => _showQuickMessages(emergency),
                ),
              ),
            ],
          ),
          const SizedBox(height: MfSpace.xs),
          // In-app calls with the patient (Deaf patient: video only, chat stays primary)
          Builder(builder: (context) {
            final patient = ref.watch(userProfileProvider(emergency.userId)).valueOrNull;
            final phone = patient?.phoneNumber.trim() ?? '';
            final deaf = emergency.patientType.toUpperCase() == 'DEAF';
            final peer = CallPeer(
              id: emergency.userId,
              name: patient?.fullName ?? 'Patient',
              imageUrl: patient?.profileImageUrl,
              phoneNumber: phone.isEmpty ? null : phone,
            );
            return Row(
              children: [
                if (!deaf) ...[
                  Expanded(
                    child: MfSecondaryButton(
                      label: 'Call patient',
                      icon: Icons.phone_outlined,
                      semanticLabel: 'Voice call the patient',
                      onPressed: () => startInAppCall(context, peer, CallMedia.audio),
                    ),
                  ),
                  const SizedBox(width: MfSpace.xs),
                ],
                Expanded(
                  child: MfSecondaryButton(
                    label: 'Video call',
                    icon: Icons.videocam_outlined,
                    semanticLabel: 'Video call the patient',
                    onPressed: () => startInAppCall(context, peer, CallMedia.video),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: MfSpace.xs),
        ],
        MfSecondaryButton(
          icon: _isPlayingVoice ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
          label: _isPlayingVoice ? 'Stop voice alert' : 'Play voice alert',
          onPressed: () => _toggleVoiceAlert(emergency),
        ),

        if (!isClosed) ...[
          const SizedBox(height: MfSpace.xl),
          MfSecondaryButton(
            label: 'Cancel my response',
            icon: Icons.cancel_outlined,
            tone: MfTone.danger,
            loading: _isCancelling,
            onPressed: _isUpdatingStatus ? null : _confirmCancellation,
          ),
        ],
      ],
    );
  }

  Widget _buildPatientInfo(emergency_entity.Emergency emergency) {
    final profileAsync = ref.watch(getMedicalProfileProvider(emergency.userId));
    final patientAsync = ref.watch(userProfileProvider(emergency.userId));
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDeafEmergency = emergency.patientType.toUpperCase() == 'DEAF';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MfSectionTitle('Patient'),
        MfCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(MfSpace.sm),
                child: Row(
                  children: [
                    ResponderTypePictogram(type: emergency.emergencyType),
                    const SizedBox(width: MfSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          patientAsync.when(
                            data: (u) => Text(u?.fullName ?? 'Anonymous patient', style: text.titleMedium),
                            loading: () => const MfSkeleton(width: 140, height: 18),
                            error: (_, __) => Text('Anonymous patient', style: text.titleMedium),
                          ),
                          Text(
                            '${EmergencyTypes.label(emergency.emergencyType)} emergency',
                            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (isDeafEmergency) const ResponderDeafBadge(),
                  ],
                ),
              ),
              const Divider(height: 1),
              profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return const Padding(
                      padding: EdgeInsets.all(MfSpace.sm),
                      child: MfInfoBanner(
                        icon: Icons.info_outline_rounded,
                        tone: MfTone.neutral,
                        title: 'No medical profile linked',
                      ),
                    );
                  }

                  final allergies = profile.allergies.isNotEmpty ? profile.allergies.join(', ') : 'None recorded';
                  final chronic = profile.chronicDiseases.isNotEmpty ? profile.chronicDiseases.join(', ') : 'None recorded';
                  final medications = profile.medications.isNotEmpty
                      ? profile.medications.map((m) => m.name).join(', ')
                      : 'None recorded';
                  final history = profile.medicalHistory?.isNotEmpty == true ? profile.medicalHistory! : 'None recorded';
                  final hasAllergies = profile.allergies.isNotEmpty;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MfKeyValueRow(
                        icon: Icons.bloodtype_outlined,
                        label: 'Blood group',
                        value: profile.bloodType.isEmpty ? 'Unknown' : profile.bloodType,
                      ),
                      MfKeyValueRow(
                        icon: Icons.warning_amber_rounded,
                        label: 'Allergies',
                        value: allergies,
                        valueColor: hasAllergies ? MfColors.sos(context) : null,
                      ),
                      if (_showFullMedicalDetails) ...[
                        MfKeyValueRow(icon: Icons.monitor_heart_outlined, label: 'Chronic conditions', value: chronic),
                        MfKeyValueRow(icon: Icons.medication_outlined, label: 'Medications', value: medications),
                        MfKeyValueRow(icon: Icons.history_edu_outlined, label: 'Medical history', value: history),
                      ],
                      const Divider(height: 1),
                      MfTextButton(
                        label: _showFullMedicalDetails ? 'Show less' : 'Show full medical summary',
                        icon: _showFullMedicalDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        onPressed: () => setState(() => _showFullMedicalDetails = !_showFullMedicalDetails),
                      ),
                    ],
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.all(MfSpace.sm),
                  child: MfSkeleton.list(count: 2, itemHeight: 40),
                ),
                error: (e, _) => MfErrorState(
                  compact: true,
                  title: 'Could not load medical profile',
                  onRetry: () => ref.invalidate(getMedicalProfileProvider(emergency.userId)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MfSpace.xs),
        Row(
          children: [
            Icon(Icons.place_outlined, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: MfSpace.xxs),
            Expanded(
              child: Text(
                'Patient location: ${emergency.latitude.toStringAsFixed(5)}, ${emergency.longitude.toStringAsFixed(5)}',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bordered surface chip for controls drawn over the map.
class _MapSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _MapSurface({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: MfRadius.mdAll,
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// Outcome picker for resolving an emergency. Pops `(outcome, note)`.
class _ResolveOutcomeForm extends StatefulWidget {
  const _ResolveOutcomeForm();

  @override
  State<_ResolveOutcomeForm> createState() => _ResolveOutcomeFormState();
}

class _ResolveOutcomeFormState extends State<_ResolveOutcomeForm> {
  String? _outcome;
  final _noteController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  _ResolveOutcome? get _selected => _resolveOutcomes.where((o) => o.value == _outcome).firstOrNull;

  String? get _outcomeError => _submitted && _outcome == null ? 'Choose how the emergency ended' : null;

  String? get _noteError {
    if (!_submitted) return null;
    if ((_selected?.noteRequired ?? false) && _noteController.text.trim().isEmpty) {
      return 'Please add a short note for this outcome';
    }
    return null;
  }

  void _submit() {
    setState(() => _submitted = true);
    if (_outcomeError != null || _noteError != null) return;
    Navigator.pop(context, (outcome: _outcome!, note: _noteController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final noteRequired = _selected?.noteRequired ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in _resolveOutcomes) ...[
          _OutcomeOption(
            outcome: o,
            selected: _outcome == o.value,
            onTap: () => setState(() => _outcome = o.value),
          ),
          const SizedBox(height: MfSpace.xs),
        ],
        if (_outcomeError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MfSpace.xs),
            child: Text(_outcomeError!, style: text.bodySmall?.copyWith(color: cs.error)),
          ),
        const SizedBox(height: MfSpace.xs),
        TextField(
          controller: _noteController,
          maxLength: _resolveNoteMaxLength,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_submitted) setState(() {});
          },
          decoration: InputDecoration(
            labelText: noteRequired ? 'Note (required)' : 'Note (optional)',
            hintText: noteRequired ? 'Briefly describe what happened' : 'Anything the team should know',
            errorText: _noteError,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: MfSpace.sm),
        MfPrimaryButton(
          label: 'Resolve emergency',
          icon: Icons.task_alt_rounded,
          tone: MfTone.success,
          onPressed: _submit,
        ),
        const SizedBox(height: MfSpace.xs),
        MfSecondaryButton(label: 'Not yet', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

class _OutcomeOption extends StatelessWidget {
  final _ResolveOutcome outcome;
  final bool selected;
  final VoidCallback onTap;

  const _OutcomeOption({required this.outcome, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = MfColors.tone(context, MfTone.primary);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '${outcome.label}. ${outcome.description}',
      excludeSemantics: true,
      child: Material(
        color: selected ? Color.alphaBlend(t.container, cs.surface) : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: MfRadius.mdAll,
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm, vertical: MfSpace.xs),
              child: Row(
                children: [
                  Icon(outcome.icon, color: selected ? t.foreground : cs.onSurfaceVariant),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(outcome.label, style: text.titleSmall),
                        Text(outcome.description, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
