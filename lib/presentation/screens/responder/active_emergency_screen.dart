import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../../services/audio/voice_alert_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/location/location_service.dart';
import '../../../domain/entities/emergency.dart' as emergency_entity;
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_utils.dart';

class ActiveEmergencyScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const ActiveEmergencyScreen({super.key, required this.emergencyId});

  @override
  ConsumerState<ActiveEmergencyScreen> createState() =>
      _ActiveEmergencyScreenState();
}

class _ActiveEmergencyScreenState extends ConsumerState<ActiveEmergencyScreen> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  String _currentStatus = 'ACCEPTED';
  StreamSubscription<Position>? _locationSubscription;
  
  double? _myLat;
  double? _myLng;
  
  BitmapDescriptor? _ambulanceIcon;
  final Set<Marker> _markers = {};

  final List<Map<String, dynamic>> _statusSteps = [
    {'status': 'ACCEPTED', 'label': 'Request Accepted', 'icon': Icons.check_circle_outline},
    {'status': 'EN_ROUTE', 'label': 'En Route to Patient', 'icon': Icons.directions_car_outlined},
    {'status': 'ARRIVED', 'label': 'Arrived at Scene', 'icon': Icons.location_on_outlined},
    {'status': 'RESOLVED', 'label': 'Emergency Resolved', 'icon': Icons.check_circle_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    Future.microtask(() async {
      final emergency = await ref.read(getEmergencyProvider(widget.emergencyId).future);
      final profile = await ref.read(getMedicalProfileProvider(emergency.userId).future);
      if (profile != null && (profile.patientType.toUpperCase() == 'DEAF' || emergency.patientType.toUpperCase() == 'DEAF')) {
         await VoiceAlertService().speakAutomatedEmergencyReport(
           emergency: emergency,
           medical: profile,
         );
      } else {
         await VoiceAlertService().announceResponderAssigned('the Patient');
      }
        });
    _startLiveTracking();
  }

  Future<void> _loadMarkerIcons() async {
    final icon = await MapUtils.getAmbulanceMarker();
    if (mounted) {
      setState(() {
        _ambulanceIcon = icon;
      });
    }
  }

  void _startLiveTracking() {
    _locationSubscription = LocationService().startLocationUpdates(
      intervalInSeconds: 5,
    ).listen((position) {
      if (mounted) {
        setState(() {
          _myLat = position.latitude;
          _myLng = position.longitude;
        });
        
        if (_currentStatus != 'RESOLVED') {
          SocketService.instance.sendLocationUpdate(
            position.latitude,
            position.longitude,
          );
        }
        
        _animateToMe();
      }
    });
  }

  void _animateToMe() {
    if (_mapController != null && _myLat != null && _myLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(_myLat!, _myLng!)),
      );
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _currentStatus = newStatus);
    try {
      if (newStatus == 'RESOLVED') {
        await ref.read(resolveEmergencyProvider(widget.emergencyId).future);
      } else {
        await ref.read(updateEmergencyStatusProvider(
          UpdateEmergencyStatusParams(emergencyId: widget.emergencyId, status: newStatus)
        ).future);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated: ${newStatus.replaceAll('_', ' ')}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Status update failed: $e');
    }
  }

  Future<void> _confirmCancellation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Response?'),
        content: const Text('Are you sure you want to cancel your response to this emergency? The request will be re-broadcasted to other responders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, Stay')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _handleCancellation();
    }
  }

  Future<void> _handleCancellation() async {
    try {
      await ref.read(cancelResponderAssignmentProvider(widget.emergencyId).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response cancelled. Returning to dashboard.')),
        );
        context.go('/responder');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _updateMarkers(emergency_entity.Emergency emergency) {
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

    // Responder (ME) Marker
    if (_myLat != null && _myLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(_myLat!, _myLng!),
          icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIdx = _statusSteps.indexWhere((s) => s['status'] == _currentStatus);
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Active Emergency'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/responder'),
        ),
      ),
      body: emergencyAsync.when(
        data: (emergency) {
          _updateMarkers(emergency);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPatientInfo(context, theme, emergency),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppShadows.neumorphicOut,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(emergency.latitude, emergency.longitude),
                        zoom: 14,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      onMapCreated: (controller) {
                        if (!_controller.isCompleted) {
                          _controller.complete(controller);
                        }
                        _mapController = controller;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                    const Text('Status Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._statusSteps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final step = entry.value;
                      return _StatusStep(
                        icon: step['icon'],
                        label: step['label'],
                        isDone: idx <= currentIdx,
                        isCurrent: idx == currentIdx,
                        isLast: idx == _statusSteps.length - 1,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_currentStatus != 'RESOLVED') ...[
              ElevatedButton.icon(
                onPressed: () {
                  final nextIdx = currentIdx + 1;
                  if (nextIdx < _statusSteps.length) _updateStatus(_statusSteps[nextIdx]['status']);
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  currentIdx + 1 < _statusSteps.length ? 'Mark: ${_statusSteps[currentIdx + 1]['label']}' : 'Completed',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.neumorphicIn),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_rounded, color: Colors.green), SizedBox(width: 8), Text('Emergency Resolved!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16))]),
              ),
              const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/responder'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Return to Dashboard'),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _confirmCancellation(context),
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                label: const Text('Cancel Response', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPatientInfo(BuildContext context, ThemeData theme, emergency_entity.Emergency emergency) {
    final profileAsync = ref.watch(getMedicalProfileProvider(emergency.userId));
    final patientAsync = ref.watch(userProfileProvider(emergency.userId));
    
    return Container(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.neumorphicOut),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [Icon(Icons.person_outlined, color: AppColors.primary), SizedBox(width: 8), Text('Patient Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                profileAsync.when(
                  data: (profile) => (profile?.patientType.toUpperCase() == 'DEAF' || emergency.patientType.toUpperCase() == 'DEAF')
                      ? IconButton(
                          icon: const Icon(Icons.record_voice_over, color: Colors.orange),
                          onPressed: () async {
                            await VoiceAlertService().speakAutomatedEmergencyReport(emergency: emergency, medical: profile!);
                          },
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const Divider(),
            patientAsync.when(
              data: (u) => Text('Patient Name: ${u?.fullName ?? 'Anonymous'}', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              loading: () => const Text('Loading patient name...', style: TextStyle(fontSize: 16)),
              error: (_, __) => const Text('Patient Name: Anonymous', style: TextStyle(fontSize: 16)),
            ),
                const SizedBox(height: 4),
                Text('Emergency: ${emergency.emergencyType.replaceAll('_', ' ')}', 
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                
                // Medical Details Section
                profileAsync.when(
                  data: (profile) {
                    if (profile == null) return const Text('No medical profile linked.', style: TextStyle(color: Colors.grey));
                    
                    final allergies = profile.allergies.isNotEmpty ? profile.allergies.join(', ') : 'None';
                    final chronic = profile.chronicDiseases.isNotEmpty ? profile.chronicDiseases.join(', ') : 'None';
                    final medications = profile.medications.isNotEmpty ? profile.medications.map((m) => m.name).join(', ') : 'None';
                    final history = profile.medicalHistory?.isNotEmpty == true ? profile.medicalHistory! : 'None';

                    final isDeaf = profile.patientType.toUpperCase() == 'DEAF' || emergency.patientType.toUpperCase() == 'DEAF';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medical_services, size: 18, color: Colors.blue.shade900),
                              const SizedBox(width: 8),
                              const Text('Complete Medical Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Blood Type', profile.bloodType),
                          _buildDetailRow('Allergies', allergies),
                          _buildDetailRow('Chronic', chronic),
                          _buildDetailRow('Medications', medications),
                          _buildDetailRow('History', history),
                          
                          if (isDeaf) ...[
                            const Divider(),
                            Row(
                              children: [
                                Icon(Icons.hearing_disabled, size: 16, color: Colors.blue.shade900),
                                const SizedBox(width: 8),
                                Text('ACCESSIBILITY ALERT: DEAF PATIENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Patient is deaf. Please use text chat for communication. Avoid calling unless absolutely necessary.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load profile: $e', style: const TextStyle(color: Colors.red)),
                ),
                const SizedBox(height: 12),
                Text('Location: ${emergency.latitude.toStringAsFixed(5)}, ${emergency.longitude.toStringAsFixed(5)}', 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  const _StatusStep({required this.icon, required this.label, required this.isDone, required this.isCurrent, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = isDone ? Colors.green : Colors.grey.shade300;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDone ? Colors.green : Colors.grey.shade200, border: isCurrent ? Border.all(color: Colors.green, width: 3) : null),
              child: Icon(icon, color: isDone ? Colors.white : Colors.grey.shade400, size: 18),
            ),
            if (!isLast) Container(width: 2, height: 32, color: color),
          ],
        ),
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isDone ? Colors.black : Colors.grey))),
      ],
    );
  }
}
