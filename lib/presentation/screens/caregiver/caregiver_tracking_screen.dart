import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/emergency.dart';
import '../../../services/socket/socket_service.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_utils.dart';
import 'dart:async';

class CaregiverTrackingScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const CaregiverTrackingScreen({Key? key, required this.emergencyId})
      : super(key: key);

  @override
  ConsumerState<CaregiverTrackingScreen> createState() => _CaregiverTrackingScreenState();
}

class _CaregiverTrackingScreenState extends ConsumerState<CaregiverTrackingScreen> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  BitmapDescriptor? _ambulanceIcon;
  final Set<Marker> _markers = {};
  
  double? _responderLat;
  double? _responderLng;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    final icon = await MapUtils.getAmbulanceMarker();
    if (mounted) {
      setState(() {
        _ambulanceIcon = icon;
      });
    }
  }

  void _updateMarkers(Emergency emergency) {
    _markers.clear();
    
    // Patient Marker
    _markers.add(
      Marker(
        markerId: const MarkerId('patient'),
        position: LatLng(emergency.latitude, emergency.longitude),
        infoWindow: const InfoWindow(title: 'Patient Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    );

    // Responder Marker
    if (_responderLat != null && _responderLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('responder'),
          position: LatLng(_responderLat!, _responderLng!),
          icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Responder'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));
    
    // Listen for Socket events to refresh data
    ref.listen(socketStreamProvider, (previous, next) {
      if (next.hasValue) {
        final message = next.value!;
        final data = message.data as Map<String, dynamic>;
        
        if (message.event == SocketEvent.emergencyStatusChange) {
          ref.invalidate(getEmergencyProvider(widget.emergencyId));
        } else if (message.event == SocketEvent.responderLocationUpdate) {
          setState(() {
            _responderLat = double.tryParse(data['latitude'].toString());
            _responderLng = double.tryParse(data['longitude'].toString());
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        centerTitle: true,
      ),
      body: emergencyAsync.when(
        data: (emergency) {
          if (emergency == null) return const Center(child: Text('Emergency not found'));
          _updateMarkers(emergency as Emergency);
          return _buildDynamicContent(context, theme, emergency);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildDynamicContent(BuildContext context, ThemeData theme, Emergency emergency) {
    final profileAsync = ref.watch(getMedicalProfileProvider(emergency.userId));
    final responderAsync = emergency.responderId != null 
        ? ref.watch(userProfileProvider(emergency.responderId!))
        : const AsyncValue.data(null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Row(
              children: [
                Icon(
                  emergency.status == 'RESOLVED' ? Icons.check_circle : Icons.local_hospital_rounded,
                  color: emergency.status == 'RESOLVED' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emergency.status == 'RESOLVED' ? 'Emergency Resolved' : 'Responder ${_getStatusLabel(emergency.status)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: emergency.status == 'RESOLVED' ? Colors.green : Colors.orange)),
                      const SizedBox(height: 4),
                      Text('Emergency Type: ${emergency.emergencyType.replaceAll('_', ' ')}',
                          style: const TextStyle(fontSize: 13)),
                      if (emergency.status != 'RESOLVED')
                        const Text('ETA: ~8 minutes', 
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real Map Integration
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(emergency.latitude, emergency.longitude),
                  zoom: 14,
                ),
                markers: _markers,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (controller) {
                  _controller.complete(controller);
                  _mapController = controller;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info Cards
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emergency Details',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  profileAsync.when(
                    data: (profile) {
                      final patientAsync = ref.watch(userProfileProvider(emergency.userId));
                      return _InfoTile(
                          icon: Icons.person,
                          label: 'Patient',
                          value: patientAsync.when(
                            data: (u) => u?.fullName ?? 'Patient',
                            loading: () => '...',
                            error: (_, __) => 'Patient',
                          ));
                    },
                    loading: () => const _InfoTile(icon: Icons.person, label: 'Patient', value: 'Loading...'),
                    error: (_, __) => const _InfoTile(icon: Icons.person, label: 'Patient', value: 'Error'),
                  ),
                  _InfoTile(
                      icon: Icons.emergency,
                      label: 'Type',
                      value: emergency.emergencyType.replaceAll('_', ' ')),
                  _InfoTile(
                      icon: Icons.location_on,
                      label: 'Location',
                      value: '${emergency.latitude.toStringAsFixed(4)}, ${emergency.longitude.toStringAsFixed(4)}'),
                  responderAsync.when(
                    data: (responder) => _InfoTile(
                        icon: Icons.timelapse,
                        label: 'Responder',
                        value: responder?.fullName ?? (emergency.responderId != null ? 'Assigned' : 'Searching...')),
                    loading: () => const _InfoTile(icon: Icons.person, label: 'Responder', value: 'Loading...'),
                    error: (_, __) => const _InfoTile(icon: Icons.person, label: 'Responder', value: 'Error'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Read-only note for caregivers
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: AppShadows.neumorphicIn,
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'View only. You cannot modify responder assignment.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Call Responder Shortcut
          if (emergency.responderId != null) 
            ElevatedButton.icon(
              onPressed: () {
                // Feature for calling responder. 
              },
              icon: const Icon(Icons.call),
              label: const Text('Call Emergency Responder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'EN_ROUTE': return 'En Route';
      case 'ARRIVED': return 'Arrived';
      case 'ACCEPTED': return 'Assigned';
      default: return 'Assigned';
    }
  }

}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
