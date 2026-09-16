import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/socket/socket_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/map/ambulance_mascot.dart';

class CaregiverTrackingScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const CaregiverTrackingScreen({super.key, required this.emergencyId});

  @override
  ConsumerState<CaregiverTrackingScreen> createState() => _CaregiverTrackingScreenState();
}

class _CaregiverTrackingScreenState extends ConsumerState<CaregiverTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<SocketMessage>? _socketSub;
  /// Animated motorbike-ambulance marker for the assigned responder.
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
    _load(silent: true); // _loading already starts true
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _mascot.dispose();
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
      if (_responderLatLng != null) _mascot.moveTo(_responderLatLng!);
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
    if (_socketEtaMinutes != null) {
      return _socketEtaMinutes! <= 0 ? 'Arriving now' : 'ETA: ~$_socketEtaMinutes min';
    }
    final p = _patientLatLng;
    final r = _responderLatLng;
    if (p != null && r != null) {
      final km = haversineKm(r.latitude, r.longitude, p.latitude, p.longitude);
      return 'ETA: ~${estimateEtaMinutes(km)} min (${km.toStringAsFixed(1)} km away)';
    }
    return 'ETA unavailable';
  }

  Future<void> _fitCamera() async {
    final controller = _mapController;
    final p = _patientLatLng;
    final r = _responderLatLng;
    if (controller == null || r == null) return;
    try {
      if (p == null) {
        await controller.animateCamera(CameraUpdate.newLatLng(r));
        return;
      }
      final bounds = LatLngBounds(
        southwest: LatLng(
          p.latitude < r.latitude ? p.latitude : r.latitude,
          p.longitude < r.longitude ? p.longitude : r.longitude,
        ),
        northeast: LatLng(
          p.latitude > r.latitude ? p.latitude : r.latitude,
          p.longitude > r.longitude ? p.longitude : r.longitude,
        ),
      );
      if (bounds.southwest == bounds.northeast) {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(p, 15));
      } else {
        await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    } catch (e) {
      debugPrint('Caregiver tracking: camera update skipped: $e');
    }
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    return markers;
  }

  Future<void> _callResponder() async {
    final phone = _responderPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) _showSnack('Could not open the phone dialer.');
    } catch (e) {
      debugPrint('Caregiver tracking: call failed: $e');
      if (mounted) _showSnack('Could not open the phone dialer.');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: _goBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _details == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_details == null) {
      return _ErrorState(
        icon: _error is CaregiverAccessDeniedException ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
        message: _error is CaregiverAccessDeniedException
            ? "You don't have access to this emergency. Only caregivers linked to the patient can track it."
            : _error == null
                ? 'Emergency details are unavailable.'
                : 'Could not load this emergency. Check your connection and try again.',
        onRetry: () => _load(),
      );
    }

    final details = _details!;
    final status = _currentStatus;
    final terminal = isTerminalEmergencyStatus(status);
    final resolved = isResolvedEmergencyStatus(status);
    final statusColor = resolved
        ? AppColors.success
        : status == 'CANCELLED'
            ? Colors.grey.shade700
            : status == 'ARRIVED'
                ? AppColors.success
                : AppColors.warning;
    final patientLatLng = _patientLatLng;
    final staticMarkers = _buildStaticMarkers();
    final showResponder = !terminal && _responderLatLng != null;
    final type = details.emergencyType.replaceAll('_', ' ');

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status banner
            Semantics(
              liveRegion: true,
              label: 'Emergency status: ${caregiverStatusLabel(status)}',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.neumorphicOut,
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      resolved
                          ? Icons.check_circle_rounded
                          : status == 'CANCELLED'
                              ? Icons.cancel_rounded
                              : Icons.local_hospital_rounded,
                      color: statusColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolved
                                ? 'Emergency resolved'
                                : status == 'CANCELLED'
                                    ? 'Emergency cancelled'
                                    : caregiverStatusLabel(status),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: statusColor,
                            ),
                          ),
                          if (_statusMessage != null && status == 'ACTIVE') ...[
                            const SizedBox(height: 4),
                            Text(_statusMessage!, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                          ],
                          const SizedBox(height: 4),
                          Text('Emergency type: $type', style: const TextStyle(fontSize: 13)),
                          if (!terminal) ...[
                            const SizedBox(height: 4),
                            Text(
                              _etaText,
                              style: TextStyle(
                                color: _etaText == 'ETA unavailable'
                                    ? Colors.grey.shade700
                                    : AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (status != 'CANCELLED') ...[
              const SizedBox(height: 12),
              _StatusTimeline(status: status),
            ],

            if (!terminal && _responderId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.neumorphicOut,
                ),
                child: Row(
                  children: [
                    const AmbulanceMascotBadge(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Responder assigned',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            _responderName ?? 'Name not available',
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (_responderPhone != null)
                      IconButton(
                        onPressed: _callResponder,
                        tooltip: 'Call responder',
                        icon: const Icon(Icons.call_rounded, color: AppColors.success),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      ),
                  ],
                ),
              ),
            ],

            if (terminal) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  resolved
                      ? 'This emergency has been resolved${details.resolvedAt != null ? ' (${caregiverRelativeTime(details.resolvedAt)})' : ''}. Live tracking has ended.'
                      : 'This emergency was cancelled. Live tracking has ended.',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Map
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.neumorphicOut,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: patientLatLng == null
                    ? Center(
                        child: Text(
                          'Location unavailable',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      )
                    : ValueListenableBuilder<Marker?>(
                        valueListenable: _mascot.marker,
                        builder: (_, mascotMarker, __) => GoogleMap(
                          initialCameraPosition: CameraPosition(target: patientLatLng, zoom: 14),
                          markers: {
                            ...staticMarkers,
                            if (mascotMarker != null && showResponder)
                              mascotMarker.copyWith(
                                infoWindowParam: InfoWindow(title: _responderName ?? 'Responder'),
                              ),
                          },
                          myLocationEnabled: false,
                          zoomControlsEnabled: false,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _fitCamera();
                          },
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Details
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.neumorphicOut,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emergency Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _InfoTile(icon: Icons.person, label: 'Patient', value: details.patientName ?? 'Patient'),
                  _InfoTile(icon: Icons.emergency, label: 'Type', value: type),
                  if (details.createdAt != null)
                    _InfoTile(
                      icon: Icons.schedule,
                      label: 'Started',
                      value: caregiverRelativeTime(details.createdAt),
                    ),
                  _InfoTile(
                    icon: Icons.location_on,
                    label: 'Location',
                    value: patientLatLng == null
                        ? 'Unavailable'
                        : '${patientLatLng.latitude.toStringAsFixed(4)}, ${patientLatLng.longitude.toStringAsFixed(4)}',
                  ),
                  _InfoTile(
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
            ),
            const SizedBox(height: 12),

            // Read-only note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: AppShadows.neumorphicIn,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View only. You cannot modify responder assignment.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (!terminal && _responderPhone != null)
              ElevatedButton.icon(
                onPressed: _callResponder,
                icon: const Icon(Icons.call),
                label: Text(
                  'Call ${_responderName ?? 'Emergency Responder'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.icon, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searching -> Assigned -> On the way -> Arrived -> Resolved.
class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = ['Searching', 'Assigned', 'On the way', 'Arrived', 'Resolved'];

  int get _index {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
      case 'ASSIGNED':
      case 'RESPONDER_ASSIGNED':
        return 1;
      case 'EN_ROUTE':
        return 2;
      case 'ARRIVED':
      case 'TREATING':
      case 'TRANSPORTED':
        return 3;
      case 'RESOLVED':
      case 'COMPLETED':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _index;
    return Semantics(
      label: 'Progress: step ${current + 1} of ${_steps.length}, ${_steps[current]}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= current ? AppColors.success : Colors.grey.shade300),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < current
                              ? AppColors.success
                              : i == current
                                  ? (current == _steps.length - 1 ? AppColors.success : AppColors.warning)
                                  : Colors.grey.shade300,
                        ),
                        child: i < current || current == _steps.length - 1
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == _steps.length - 1
                              ? Colors.transparent
                              : (i < current ? AppColors.success : Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _steps[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == current ? FontWeight.bold : FontWeight.normal,
                      color: i <= current ? Colors.grey.shade900 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
