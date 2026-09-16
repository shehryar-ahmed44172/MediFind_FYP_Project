import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_dashboard_provider.dart';
import '../../../services/socket/socket_service.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/map/ambulance_mascot.dart';

/// Live map of linked patients' ACTIVE emergencies (Live map tab root; the
/// shell draws the header). The map fills the tab; the legend and the list of
/// active emergencies float over it.
class CaregiverMapScreen extends ConsumerWidget {
  const CaregiverMapScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(caregiverEmergencyHistoryProvider);
    try {
      await ref.read(caregiverActiveEmergenciesProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final activeAsync = ref.watch(caregiverActiveEmergenciesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: activeAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (active) {
          if (active.isEmpty) {
            return _buildMessageState(
              onRefresh: () => _refresh(ref),
              child: const MfEmptyState(
                icon: Icons.verified_user_outlined,
                title: 'No active emergencies',
                message: 'Your linked patients are safe. If a patient triggers an SOS, '
                    'their location will appear here.',
              ),
            );
          }
          return _buildMapLayout(context, ref, active);
        },
        loading: () => const MfLoading(label: 'Loading live map'),
        error: (e, _) => _buildMessageState(
          onRefresh: () => _refresh(ref),
          child: MfErrorState(
            title: 'Could not load emergencies',
            message: 'Check your connection and try again.',
            onRetry: () => _refresh(ref),
          ),
        ),
      ),
    );
  }

  Widget _buildMapLayout(
    BuildContext context,
    WidgetRef ref,
    List<CaregiverEmergencyDetails> active,
  ) {
    final located = active.where((e) => e.hasLocation).toList();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxPanelHeight = MediaQuery.sizeOf(context).height * 0.42;

    return Stack(
      children: [
        // Map fills the tab.
        Positioned.fill(
          child: located.isEmpty
              ? ColoredBox(
                  color: cs.surfaceContainer,
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: MfEmptyState(
                      compact: true,
                      icon: Icons.location_off_outlined,
                      title: 'Location unavailable',
                      message: 'Location data is not available for the active emergencies yet.',
                    ),
                  ),
                )
              : _ActiveEmergencyMap(emergencies: located),
        ),

        // Legend
        if (located.isNotEmpty)
          const Positioned(
            top: MfSpace.sm,
            left: MfSpace.sm,
            child: _MapLegend(),
          ),

        // Active emergencies panel
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: cs.surface,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(MfRadius.lg)),
              side: BorderSide(color: cs.outlineVariant, width: MfColors.isHighContrast(context) ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text('Active emergencies', style: text.titleMedium),
                          ),
                        ),
                        MfStatusChip(
                          label: '${active.length} active',
                          tone: MfTone.danger,
                          icon: Icons.sos_rounded,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: RefreshIndicator(
                      onRefresh: () => _refresh(ref),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.xs, MfSpace.gutter, MfSpace.md),
                        itemCount: active.length,
                        separatorBuilder: (_, __) => const SizedBox(height: MfSpace.sm),
                        itemBuilder: (context, index) => _buildEmergencyCard(context, active[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyCard(BuildContext context, CaregiverEmergencyDetails e) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final type = e.emergencyType.replaceAll('_', ' ');
    final name = e.patientName ?? 'Linked patient';
    return MfCard(
      tone: MfTone.danger,
      padding: const EdgeInsets.all(MfSpace.sm),
      onTap: () => context.push('/caregiver/tracking/${e.id}'),
      semanticLabel: '$name, $type, ${caregiverStatusLabel(e.status)}',
      child: Row(
        children: [
          MfAvatar(name: name, size: 40),
          const SizedBox(width: MfSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  e.createdAt != null ? '$type  ·  Started ${caregiverRelativeTime(e.createdAt)}' : type,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: MfSpace.xxs),
                MfStatusChip.emergency(e.status),
              ],
            ),
          ),
          const SizedBox(width: MfSpace.xs),
          MfPrimaryButton(
            label: 'Track',
            icon: Icons.my_location_rounded,
            tone: MfTone.danger,
            expanded: false,
            height: MfSize.minTouch,
            semanticLabel: 'Track $name live',
            onPressed: () => context.push('/caregiver/tracking/${e.id}'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Explains the two marker types on the map.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sos = MfColors.sos(context);
    final primary = MfColors.tone(context, MfTone.primary).foreground;
    return MfCard(
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm, vertical: MfSpace.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: 18, color: sos),
          const SizedBox(width: MfSpace.xxs),
          Text('Patient', style: text.labelMedium),
          const SizedBox(width: MfSpace.sm),
          Icon(Icons.two_wheeler_rounded, size: 18, color: primary),
          const SizedBox(width: MfSpace.xxs),
          Text('Responder', style: text.labelMedium),
        ],
      ),
    );
  }
}

/// Google map with a patient marker per active emergency and an animated
/// motorbike-ambulance mascot for each emergency's responder.
class _ActiveEmergencyMap extends ConsumerStatefulWidget {
  final List<CaregiverEmergencyDetails> emergencies;
  const _ActiveEmergencyMap({required this.emergencies});

  @override
  ConsumerState<_ActiveEmergencyMap> createState() => _ActiveEmergencyMapState();
}

class _ActiveEmergencyMapState extends ConsumerState<_ActiveEmergencyMap> {
  final Map<String, AnimatedMascotMarker> _mascots = {};
  final Set<String> _trackingFetched = {};
  StreamSubscription<SocketMessage>? _socketSub;
  Listenable _mascotListenable = Listenable.merge(const []);
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _socketSub = SocketService.instance.messageStream.listen(_onSocketMessage);
    _syncEmergencies();
  }

  @override
  void didUpdateWidget(covariant _ActiveEmergencyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEmergencies();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    for (final m in _mascots.values) {
      m.dispose();
    }
    super.dispose();
  }

  /// Creates mascots for new emergencies, drops ones no longer active and
  /// fetches each responder's last known position once.
  void _syncEmergencies() {
    final ids = widget.emergencies.map((e) => e.id).toSet();
    final removed = _mascots.keys.where((id) => !ids.contains(id)).toList();
    final stale = <AnimatedMascotMarker>[];
    for (final id in removed) {
      stale.add(_mascots.remove(id)!);
      _trackingFetched.remove(id);
    }
    for (final e in widget.emergencies) {
      SocketService.instance.joinLocationRoom(e.id);
      _mascots.putIfAbsent(
        e.id,
        () => AnimatedMascotMarker(
          markerId: MarkerId('responder_${e.id}'),
          infoWindow: InfoWindow(title: e.responderName ?? 'Responder'),
        ),
      );
      if (e.responderId != null && _trackingFetched.add(e.id)) {
        _fetchLatest(e.id);
      }
    }
    _mascotListenable = Listenable.merge(_mascots.values.map((m) => m.marker).toList());
    if (stale.isNotEmpty) {
      // Dispose after the builder has switched to the new listenable.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final m in stale) {
          m.dispose();
        }
      });
    }
  }

  Future<void> _fetchLatest(String emergencyId) async {
    final latest = await fetchCaregiverLatestTracking(ref.read(apiClientProvider), emergencyId);
    final lat = double.tryParse('${latest?['latitude']}');
    final lng = double.tryParse('${latest?['longitude']}');
    if (!mounted || lat == null || lng == null) return;
    _mascots[emergencyId]?.moveTo(LatLng(lat, lng));
  }

  void _onSocketMessage(SocketMessage message) {
    if (message.event != SocketEvent.responderLocationUpdate) return;
    final data = message.data;
    if (data is! Map) return;
    final id = data['emergencyId']?.toString();
    final mascot = id == null ? null : _mascots[id];
    if (mascot == null) return;
    final lat = double.tryParse('${data['latitude']}');
    final lng = double.tryParse('${data['longitude']}');
    if (lat == null || lng == null) return;
    mascot.moveTo(LatLng(lat, lng));
  }

  Future<void> _fitAll(GoogleMapController controller) async {
    final located = widget.emergencies;
    if (_fitted || located.length < 2) return;
    double minLat = located.first.latitude!, maxLat = minLat;
    double minLng = located.first.longitude!, maxLng = minLng;
    for (final e in located) {
      if (e.latitude! < minLat) minLat = e.latitude!;
      if (e.latitude! > maxLat) maxLat = e.latitude!;
      if (e.longitude! < minLng) minLng = e.longitude!;
      if (e.longitude! > maxLng) maxLng = e.longitude!;
    }
    if (minLat == maxLat && minLng == maxLng) return;
    try {
      // Give the map a frame to lay out before fitting bounds.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        60,
      ));
      _fitted = true;
    } catch (e) {
      debugPrint('Caregiver map: bounds fit skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final located = widget.emergencies;
    final patientMarkers = located
        .map((e) => Marker(
              markerId: MarkerId(e.id),
              position: LatLng(e.latitude!, e.longitude!),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: e.patientName ?? 'Linked patient',
                snippet: '${caregiverStatusLabel(e.status)} - tap to track',
                onTap: () => context.push('/caregiver/tracking/${e.id}'),
              ),
            ))
        .toSet();

    // Only the map rebuilds at animation rate.
    return ListenableBuilder(
      listenable: _mascotListenable,
      builder: (context, _) => GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(located.first.latitude!, located.first.longitude!),
          zoom: 13,
        ),
        style: MapUtils.getLightMapStyle(),
        markers: {
          ...patientMarkers,
          for (final m in _mascots.values)
            if (m.marker.value != null) m.marker.value!,
        },
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        // Keep markers clear of the legend and the emergencies panel overlays.
        padding: EdgeInsets.only(
          top: MfSize.primaryButton,
          bottom: MediaQuery.sizeOf(context).height * 0.3,
        ),
        onMapCreated: _fitAll,
      ),
    );
  }
}
