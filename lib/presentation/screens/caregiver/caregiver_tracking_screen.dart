import 'dart:async';

import '../../widgets/call/call_launcher.dart';
import '../../../services/call/call_service.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/utils/emergency_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/socket/socket_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_dashboard_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/map/ambulance_mascot.dart';
import '../../widgets/map/tracking_camera.dart';
import '../../widgets/map/route_line.dart';
import '../../widgets/map/map_loading_cover.dart';
import '../../theme/app_theme.dart';

class CaregiverTrackingScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const CaregiverTrackingScreen({super.key, required this.emergencyId});

  @override
  ConsumerState<CaregiverTrackingScreen> createState() => _CaregiverTrackingScreenState();
}

class _CaregiverTrackingScreenState extends ConsumerState<CaregiverTrackingScreen> {
  GoogleMapController? _mapController;
  final _mapCover = MapCoverController();
  StreamSubscription<SocketMessage>? _socketSub;
  /// Animated motorbike-ambulance marker for the assigned responder.
  /// Road route from the responder to the patient.
  final RouteLine _route = RouteLine(color: AppColors.primary);
  final TrackingCamera _camera = TrackingCamera();

  AnimatedMascotMarker _mascot = AnimatedMascotMarker(
    markerId: const MarkerId('responder'),
    infoWindow: const InfoWindow(title: 'Responder'),
  );

  CaregiverEmergencyDetails? _details;
  bool _loading = true;
  Object? _error;

  /// Live status (socket overrides the fetched one).
  String? _liveStatus;
  double? _responderLat;
  double? _responderLng;
  int? _socketEtaMinutes;
  String? _responderId;
  String? _responderName;
  String? _responderPhone;

  /// Extra context from the server, e.g. "finding another responder".
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    SocketService.instance.joinEmergencyRoom(widget.emergencyId);
    SocketService.instance.joinLocationRoom(widget.emergencyId);
    _socketSub = SocketService.instance.messageStream.listen(_onSocketMessage);
    _route.route.addListener(_onRouteChanged);
    MapUtils.getPatientMarker().then((_) {
      if (mounted) setState(() {});
    });
    _load(silent: true); // _loading already starts true
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _mascot.dispose();
    _route.dispose();
    _mapCover.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Replaces the mascot (e.g. responder changed) so it doesn't glide from
  /// the previous responder's position. Old one is disposed after this frame.
  void _resetMascot() {
    final old = _mascot;
    _mascot = AnimatedMascotMarker(
      markerId: const MarkerId('responder'),
      infoWindow: const InfoWindow(title: 'Responder'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final client = ref.read(apiClientProvider);
    try {
      final details = await fetchCaregiverEmergencyDetails(client, widget.emergencyId);
      if (!mounted) return;
      setState(() {
        _details = details;
        // Keep a finer-grained live status (EN_ROUTE/ARRIVED from tracking
        // events) unless the server reports a different phase.
        const liveOnly = {'EN_ROUTE', 'ARRIVED', 'TREATING', 'TRANSPORTED'};
        final keepLive = !details.isTerminal &&
            details.status != 'ACTIVE' &&
            liveOnly.contains(_liveStatus);
        if (!keepLive) _liveStatus = details.status;
        _loading = false;
        _error = null;
        if (details.responderId != null) _responderId = details.responderId;
        if (details.responderName != null) _responderName = details.responderName;
        if (details.responderPhone != null) _responderPhone = details.responderPhone;
        if (details.status != 'ACTIVE') _statusMessage = null;
        if (_responderLat == null &&
            details.responderLatitude != null &&
            details.responderLongitude != null) {
          _responderLat = details.responderLatitude;
          _responderLng = details.responderLongitude;
        }
      });
      if (_responderLatLng != null) {
        _mascot.moveTo(_responderLatLng!);
        _route.update(_responderLatLng, _patientLatLng);
      }
      if (details.isTerminal) return;

      // Latest tracked responder position (more accurate than Responder.current*).
      final latest = await fetchCaregiverLatestTracking(client, widget.emergencyId);
      final lat = double.tryParse('${latest?['latitude']}');
      final lng = double.tryParse('${latest?['longitude']}');
      if (mounted && lat != null && lng != null) {
        setState(() {
          _responderLat = lat;
          _responderLng = lng;
        });
        _mascot.moveTo(LatLng(lat, lng));
        _route.update(LatLng(lat, lng), _patientLatLng);
        _fitCamera();
      }

      if (_responderPhone == null && _responderId != null) {
        final phone = await fetchCaregiverResponderPhone(client, _responderId!);
        if (mounted && phone != null) setState(() => _responderPhone = phone);
      }
    } catch (e) {
      debugPrint('Caregiver tracking: failed to load ${widget.emergencyId}: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _details == null) _error = e;
      });
    }
  }

  void _onSocketMessage(SocketMessage message) {
    final raw = message.data;
    if (raw is! Map || !mounted) return;
    final data = Map<String, dynamic>.from(raw);

    // In-app notifications (RESPONDER_ASSIGNED, EMERGENCY_RESOLVED, PATIENT_SAFE,
    // PATIENT_EMERGENCY updates) carry the emergency id in a nested `data` map.
    if (message.event == SocketEvent.notification) {
      final inner = data['data'];
      if (inner is! Map) return;
      if (inner['emergencyId']?.toString() != widget.emergencyId) return;
      const refreshTypes = {'RESPONDER_ASSIGNED', 'PATIENT_SAFE', 'EMERGENCY_RESOLVED', 'PATIENT_EMERGENCY'};
      if (!refreshTypes.contains(data['type']?.toString())) return;
      _load(silent: true);
      return;
    }

    if (data['emergencyId']?.toString() != widget.emergencyId) return;

    switch (message.event) {
      case SocketEvent.responderLocationUpdate:
        final lat = double.tryParse('${data['latitude']}');
        final lng = double.tryParse('${data['longitude']}');
        if (lat == null || lng == null) return;
        final eta = int.tryParse('${data['estimatedArrivalMinutes'] ?? data['etaMinutes'] ?? data['eta']}') ??
            double.tryParse('${data['estimatedArrivalMinutes'] ?? data['etaMinutes'] ?? data['eta']}')?.round();
        final trackingStatus = data['status']?.toString().toUpperCase();
        setState(() {
          _responderLat = lat;
          _responderLng = lng;
          if (eta != null) _socketEtaMinutes = eta;
          if (data['responderId'] != null) _responderId ??= data['responderId'].toString();
          if (trackingStatus != null &&
              (trackingStatus == 'EN_ROUTE' || trackingStatus == 'ARRIVED') &&
              !isTerminalEmergencyStatus(_currentStatus)) {
            _liveStatus = trackingStatus;
          }
        });
        _mascot.moveTo(LatLng(lat, lng));
        _route.update(LatLng(lat, lng), _patientLatLng);
        _fitCamera();
        break;

      case SocketEvent.emergencyStatusChange:
        final newStatus = (data['newStatus'] ?? data['status'])?.toString().toUpperCase();
        setState(() {
          if (newStatus != null && newStatus.isNotEmpty) _liveStatus = newStatus;
          _statusMessage = null;
          if (newStatus == 'ACTIVE') {
            _statusMessage = 'The assigned responder is no longer available. Finding another responder...';
            // Responder dropped out; backend re-broadcasts the request.
            _responderId = null;
            _responderName = null;
            _responderPhone = null;
            _responderLat = null;
            _responderLng = null;
            _socketEtaMinutes = null;
            _resetMascot();
          }
          if (data['responderId'] != null) _responderId = data['responderId'].toString();
          if (data['responderName'] != null) _responderName = data['responderName'].toString();
          final phone = data['responderPhone']?.toString().trim();
          if (phone != null && phone.isNotEmpty) _responderPhone = phone;
        });
        _load(silent: true);
        break;

      case SocketEvent.responderArrived:
        setState(() {
          if (!isTerminalEmergencyStatus(_currentStatus)) _liveStatus = 'ARRIVED';
        });
        break;

      default:
        break;
    }
  }

  String get _currentStatus => (_liveStatus ?? _details?.status ?? 'ACTIVE').toUpperCase();

  LatLng? get _patientLatLng {
    final d = _details;
    if (d == null || !d.hasLocation) return null;
    return LatLng(d.latitude!, d.longitude!);
  }

  LatLng? get _responderLatLng =>
      (_responderLat != null && _responderLng != null) ? LatLng(_responderLat!, _responderLng!) : null;

  /// ETA text: socket value, else Haversine estimate, else unavailable.
  String get _etaText {
    final status = _currentStatus;
    if (status == 'ARRIVED') return 'Responder has arrived';
    if (_socketEtaMinutes != null && _socketEtaMinutes! <= GeoUtils.maxPlausibleEtaMin) {
      return _socketEtaMinutes! <= 0 ? 'Arriving now' : 'ETA: ~$_socketEtaMinutes min';
    }
    final p = _patientLatLng;
    final r = _responderLatLng;
    if (p != null && r != null) {
      final km = haversineKm(r.latitude, r.longitude, p.latitude, p.longitude);
      if (!GeoUtils.isPlausible(km)) return 'Locating the responder…';
      return 'ETA: ~${estimateEtaMinutes(km)} min (${km.toStringAsFixed(1)} km away)';
    }
    return 'ETA unavailable';
  }

  Future<void> _fitCamera() async {
    final r = _responderLatLng;
    if (r == null) return;
    await _camera.keepInView(_mapController, responder: r, patient: _patientLatLng);
  }

  /// The mascot glides along the road route instead of cutting across blocks.
  void _onRouteChanged() {
    final route = _route.route.value;
    _mascot.setPath(route == null || route.isFallback ? null : route.points);
  }

  /// Patient marker only; the responder mascot is added by the map's builder.
  Set<Marker> _buildStaticMarkers() {
    final markers = <Marker>{};
    final p = _patientLatLng;
    if (p != null) {
      markers.add(Marker(
        markerId: const MarkerId('patient'),
        position: p,
        infoWindow: InfoWindow(title: _details?.patientName ?? 'Patient location'),
        icon: MapUtils.patientMarkerOrDefault,
        anchor: const Offset(0.5, 1.0),
      ));
    }
    return markers;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/caregiver');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final header = MfFloatingHeader(
      title: 'Live tracking',
      subtitle: _details?.patientName,
      onBack: _goBack,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: _loading ? null : () => _load(),
        ),
      ],
    );

    if (_details == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Column(
          children: [
            header,
            Expanded(
              child: _loading
                  ? const MfLoading(label: 'Loading emergency')
                  : MfErrorState(
                      title: _error is CaregiverAccessDeniedException
                          ? 'No access to this emergency'
                          : 'Emergency unavailable',
                      message: _error is CaregiverAccessDeniedException
                          ? "You don't have access to this emergency. Only caregivers linked to the patient can track it."
                          : _error == null
                              ? 'Emergency details are unavailable.'
                              : 'Could not load this emergency. Check your connection and try again.',
                      onRetry: () => _load(),
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(context)),
          Positioned.fill(child: MapLoadingCover(controller: _mapCover, child: const SizedBox.expand())),
          Positioned(top: 0, left: 0, right: 0, child: header),
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.22,
            maxChildSize: 0.92,
            builder: (context, scrollController) => _buildPanel(context, scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final patientLatLng = _patientLatLng;
    if (patientLatLng == null) {
      return ColoredBox(
        color: cs.surfaceContainer,
        child: const SafeArea(
          child: Align(
            alignment: Alignment(0, -0.5),
            child: MfEmptyState(
              compact: true,
              icon: Icons.location_off_outlined,
              title: 'Location unavailable',
            ),
          ),
        ),
      );
    }
    final staticMarkers = _buildStaticMarkers();
    final showResponder = !isTerminalEmergencyStatus(_currentStatus) && _responderLatLng != null;
    final size = MediaQuery.sizeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_mascot.marker, _route.polylines]),
      builder: (context, _) {
        final mascotMarker = _mascot.marker.value;
        return GoogleMap(
        initialCameraPosition: CameraPosition(target: patientLatLng, zoom: 14),
        markers: {
          ...staticMarkers,
          if (mascotMarker != null && showResponder)
            mascotMarker.copyWith(
              infoWindowParam: InfoWindow(title: _responderName ?? 'Responder'),
            ),
        },
        polylines: showResponder ? _route.polylines.value : const <Polyline>{},
        style: MapUtils.getLightMapStyle(),
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        // Keep markers clear of the floating header and the bottom panel.
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + MfSize.headerHeight,
          bottom: size.height * 0.5,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          _mapCover.markReady();
          _fitCamera();
        },
      );
      },
    );
  }

  Widget _buildPanel(BuildContext context, ScrollController scrollController) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final details = _details!;
    final status = _currentStatus;
    final terminal = isTerminalEmergencyStatus(status);
    final resolved = isResolvedEmergencyStatus(status);
    final patientLatLng = _patientLatLng;
    final type = EmergencyTypes.label(details.emergencyType);
    final patientName = details.patientName ?? 'Patient';
    final etaUnavailable = _etaText == 'ETA unavailable';

    return Material(
      color: cs.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(MfRadius.lg)),
        side: BorderSide(color: cs.outlineVariant, width: MfColors.isHighContrast(context) ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            MfSpace.gutter,
            0,
            MfSpace.gutter,
            MfSpace.lg + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const MfSheetHandle(),

            // Status
            Semantics(
              liveRegion: true,
              label: 'Emergency status: ${caregiverStatusLabel(status)}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          resolved
                              ? 'Emergency resolved'
                              : status == 'CANCELLED'
                                  ? 'Emergency cancelled'
                                  : caregiverStatusLabel(status),
                          style: text.titleLarge,
                        ),
                      ),
                      const SizedBox(width: MfSpace.xs),
                      MfStatusChip.emergency(status),
                    ],
                  ),
                  const SizedBox(height: MfSpace.xxs),
                  Text(
                    'Emergency type: $type',
                    style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (!terminal) ...[
                    const SizedBox(height: MfSpace.xxs),
                    Text(
                      _etaText,
                      style: text.titleSmall?.copyWith(
                        color: etaUnavailable ? cs.onSurfaceVariant : MfColors.tone(context, MfTone.primary).foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (_statusMessage != null && status == 'ACTIVE') ...[
              const SizedBox(height: MfSpace.sm),
              MfInfoBanner(
                icon: Icons.sync_rounded,
                tone: MfTone.warning,
                title: 'Finding another responder',
                message: _statusMessage,
              ),
            ],

            if (status != 'CANCELLED') ...[
              const SizedBox(height: MfSpace.md),
              MfStatusTimeline.emergency(status: status, perspective: MfTimelinePerspective.caregiver),
            ],

            if (terminal) ...[
              const SizedBox(height: MfSpace.md),
              MfInfoBanner(
                icon: resolved ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                tone: resolved ? MfTone.success : MfTone.neutral,
                title: 'Live tracking has ended',
                message: resolved
                    ? 'This emergency has been resolved${details.resolvedAt != null ? ' (${caregiverRelativeTime(details.resolvedAt)})' : ''}. Live tracking has ended.'
                    : 'This emergency was cancelled. Live tracking has ended.',
              ),
            ],

            // Responder
            if (!terminal && _responderId != null) ...[
              const SizedBox(height: MfSpace.md),
              MfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        MfAvatar(name: _responderName, size: 44),
                        const SizedBox(width: MfSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Responder assigned',
                                style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              Text(_responderName ?? 'Name not available', style: text.titleMedium),
                              if (!etaUnavailable)
                                Text(
                                  _etaText,
                                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_responderId != null && !isTerminalEmergencyStatus(_currentStatus)) ...[
                      const SizedBox(height: MfSpace.sm),
                      MfPrimaryButton(
                        label: 'Call ${_responderName ?? 'emergency responder'}',
                        icon: Icons.call_outlined,
                        semanticLabel: 'Call responder',
                        onPressed: () => startInAppCall(
                          context,
                          CallPeer(id: _responderId!, name: _responderName ?? 'Responder', phoneNumber: _responderPhone),
                          CallMedia.audio,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Patient
            const SizedBox(height: MfSpace.md),
            MfCard(
              child: Row(
                children: [
                  MfAvatar(name: patientName, size: 44),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patient', style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                        Text(patientName, style: text.titleMedium),
                        if (details.createdAt != null)
                          Text(
                            'SOS started ${caregiverRelativeTime(details.createdAt)}',
                            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Details
            const SizedBox(height: MfSpace.md),
            const MfSectionTitle('Emergency details'),
            MfListGroup(
              children: [
                MfKeyValueRow(icon: Icons.person_outline_rounded, label: 'Patient', value: patientName),
                MfKeyValueRow(icon: Icons.emergency_outlined, label: 'Type', value: type),
                if (details.createdAt != null)
                  MfKeyValueRow(
                    icon: Icons.schedule_rounded,
                    label: 'Started',
                    value: caregiverRelativeTime(details.createdAt),
                  ),
                MfKeyValueRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: patientLatLng == null
                      ? 'Unavailable'
                      : '${patientLatLng.latitude.toStringAsFixed(4)}, ${patientLatLng.longitude.toStringAsFixed(4)}',
                ),
                MfKeyValueRow(
                  icon: Icons.medical_services_outlined,
                  label: 'Responder',
                  value: _responderName ??
                      (_responderId != null
                          ? 'Assigned'
                          : terminal
                              ? 'None'
                              : 'Searching...'),
                ),
              ],
            ),

            // Read-only note
            const SizedBox(height: MfSpace.md),
            const MfInfoBanner(
              icon: Icons.info_outline_rounded,
              tone: MfTone.neutral,
              title: 'View only',
              message: 'You cannot modify responder assignment.',
            ),
          ],
        ),
      ),
    );
  }
}
