import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_dashboard_provider.dart';
import '../../../services/socket/socket_service.dart';
import '../../widgets/map/ambulance_mascot.dart';

/// Live map of linked patients' ACTIVE emergencies.
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
    final theme = Theme.of(context);
    final activeAsync = ref.watch(caregiverActiveEmergenciesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: activeAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (active) {
          if (active.isEmpty) {
            return _buildMessageState(
              onRefresh: () => _refresh(ref),
              icon: Icons.verified_user_outlined,
              iconColor: AppColors.success,
              title: 'No active emergencies',
              body: 'Your linked patients are safe. If a patient triggers an SOS, '
                  'their location will appear here.',
            );
          }
          return _buildMapLayout(context, ref, theme, active);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildMessageState(
          onRefresh: () => _refresh(ref),
          icon: Icons.cloud_off_rounded,
          iconColor: AppColors.error,
          title: 'Could not load emergencies',
          body: 'Check your connection and try again.',
          action: ElevatedButton.icon(
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
          ),
        ),
      ),
    );
  }

  Widget _buildMapLayout(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    List<CaregiverEmergencyDetails> active,
  ) {
    final located = active.where((e) => e.hasLocation).toList();

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: located.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Location data is not available for the active emergencies yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    )
                  : _ActiveEmergencyMap(emergencies: located),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Active emergencies (${active.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refresh(ref),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: active.length,
                      itemBuilder: (context, index) => _buildEmergencyCard(context, active[index], theme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyCard(BuildContext context, CaregiverEmergencyDetails e, ThemeData theme) {
    final type = e.emergencyType.replaceAll('_', ' ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.sosMassiveGlow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/caregiver/tracking/${e.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  child: const Icon(Icons.emergency_rounded, color: AppColors.error),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.patientName ?? 'Linked patient',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$type - ${caregiverStatusLabel(e.status)}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (e.createdAt != null)
                        Text(
                          'Started ${caregiverRelativeTime(e.createdAt)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => context.push('/caregiver/tracking/${e.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(72, 48),
                  ),
                  child: const Text('Track', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required Future<void> Function() onRefresh,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    Widget? action,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 120),
          Icon(icon, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          if (action != null) ...[
            const SizedBox(height: 24),
            Center(child: action),
          ],
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
        markers: {
          ...patientMarkers,
          for (final m in _mascots.values)
            if (m.marker.value != null) m.marker.value!,
        },
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        onMapCreated: _fitAll,
      ),
    );
  }
}
