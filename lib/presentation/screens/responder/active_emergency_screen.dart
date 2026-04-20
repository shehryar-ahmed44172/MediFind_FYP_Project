import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../../services/audio/voice_alert_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/location/location_service.dart';
import '../../../domain/entities/emergency.dart' as emergency_entity;
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class ActiveEmergencyScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const ActiveEmergencyScreen({Key? key, required this.emergencyId}) : super(key: key);

  @override
  ConsumerState<ActiveEmergencyScreen> createState() =>
      _ActiveEmergencyScreenState();
}

class _ActiveEmergencyScreenState extends ConsumerState<ActiveEmergencyScreen> {
  String _currentStatus = 'ACCEPTED';
  StreamSubscription<Position>? _locationSubscription;
  
  // Plan v6: Patient tracking coordinates
  double? _patientLat;
  double? _patientLng;

  final List<Map<String, dynamic>> _statusSteps = [
    {'status': 'ACCEPTED', 'label': 'Request Accepted', 'icon': Icons.check_circle_outline},
    {'status': 'EN_ROUTE', 'label': 'En Route to Patient', 'icon': Icons.directions_car_outlined},
    {'status': 'ARRIVED', 'label': 'Arrived at Scene', 'icon': Icons.location_on_outlined},
    {'status': 'RESOLVED', 'label': 'Emergency Resolved', 'icon': Icons.check_circle_rounded},
  ];

  @override
  void initState() {
    super.initState();
    // Automatically announce when the active view opens
    Future.microtask(() async {
      final emergency = await ref.read(getEmergencyProvider(widget.emergencyId).future);
      if (emergency != null) {
        final profile = await ref.read(getMedicalProfileProvider(emergency.userId).future);
        
        if (profile != null && profile.disabilityType?.toLowerCase().contains('deaf') == true) {
           // For deaf patients, we play the detailed medical report
           await VoiceAlertService().speakAutomatedEmergencyReport(
             emergency: emergency as emergency_entity.Emergency,
             medical: profile,
           );
        } else {
           // For normal patients, play standard arrival announcement
           await VoiceAlertService().announceResponderAssigned('the Patient');
        }
      }
    });

    _startLiveTracking();
  }

  void _startLiveTracking() {
    _locationSubscription = LocationService().startLocationUpdates(
      intervalInSeconds: 5,
    ).listen((position) {
      if (_currentStatus != 'RESOLVED') {
        SocketService.instance.sendLocationUpdate(
          position.latitude,
          position.longitude,
        );
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIdx =
        _statusSteps.indexWhere((s) => s['status'] == _currentStatus);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Active Emergency'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient Info Card
            _buildPatientInfo(context, theme),
            const SizedBox(height: 16),

            // Map placeholder (Google Maps would go here)
            Container(
              height: 250, // Increased for pin visibility
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShadows.neumorphicIn,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Grid Simulation
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(),
                      ),
                    ),
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 32, color: AppColors.primaryOpacity),
                          Text('Navigating to Patient...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    
                    // Patient Pin (Plan v6: Tracking target)
                    Positioned(
                      top: 100,
                      left: 150,
                      child: _buildMapPin(Icons.person_pin_circle_rounded, AppColors.primaryDark),
                    ),
                    
                    // Responder Pin (Self - Plan v6: Simulation)
                    Positioned(
                      bottom: 40,
                      right: 60,
                      child: _buildMapPin(Icons.directions_car_filled_rounded, Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Timeline
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
                    const Text('Status Timeline',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._statusSteps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final step = entry.value;
                      final isDone = idx <= currentIdx;
                      final isCurrent = idx == currentIdx;
                      return _StatusStep(
                        icon: step['icon'],
                        label: step['label'],
                        isDone: isDone,
                        isCurrent: isCurrent,
                        isLast: idx == _statusSteps.length - 1,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (_currentStatus != 'RESOLVED') ...[
              ElevatedButton.icon(
                onPressed: () {
                  final nextIdx = currentIdx + 1;
                  if (nextIdx < _statusSteps.length) {
                    _updateStatus(_statusSteps[nextIdx]['status']);
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  currentIdx + 1 < _statusSteps.length
                      ? 'Mark: ${_statusSteps[currentIdx + 1]['label']}'
                      : 'Completed',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.neumorphicIn,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Emergency Resolved!',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/responder'),
                child: const Text('Return to Dashboard'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfo(BuildContext context, ThemeData theme) {
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));

    return emergencyAsync.when(
      data: (emergency) {
        if (emergency == null) return const Text('No active emergency data');
        final profileAsync = ref.watch(getMedicalProfileProvider(emergency.userId));

        return Container(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_outlined, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Patient Info',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    profileAsync.when(
                      data: (profile) => (profile?.disabilityType?.toLowerCase().contains('deaf') == true)
                          ? Tooltip(
                              message: 'Deaf Patient: Automated Report Available',
                              child: IconButton(
                                icon: const Icon(Icons.record_voice_over, color: Colors.orange),
                                onPressed: () async {
                                  await VoiceAlertService().speakAutomatedEmergencyReport(
                                    emergency: emergency as emergency_entity.Emergency,
                                    medical: profile!,
                                  );
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const Divider(),
                Text('Patient ID: ${emergency.userId.substring(0, 8)}...', style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text('Emergency: ${emergency.emergencyType.replaceAll('_', ' ')}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Location: ${emergency.latitude}, ${emergency.longitude}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _StatusStep({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? Colors.green : Colors.grey.shade200,
                border: isCurrent
                    ? Border.all(color: Colors.green, width: 3)
                    : null,
              ),
              child: Icon(icon,
                  color: isDone ? Colors.white : Colors.grey.shade400,
                  size: 18),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: color),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isDone ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
