import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../../services/audio/voice_alert_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../services/location/location_service.dart';
import '../../../domain/entities/emergency.dart' as emergency_entity;
import '../../providers/chat_provider.dart';
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

  // Phase 2: Collapsible medical details state
  bool _showFullMedicalDetails = false;

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
      final voiceEnabled = ref.read(accessibilityProvider).voiceGuidanceEnabled;
      if (!voiceEnabled) return; // Responder has disabled voice alerts

      final emergency = await ref.read(getEmergencyProvider(widget.emergencyId).future);
      final profile = await ref.read(getMedicalProfileProvider(emergency.userId).future);
      if (profile != null &&
          (profile.patientType.toUpperCase() == 'DEAF' ||
              emergency.patientType.toUpperCase() == 'DEAF')) {
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
            widget.emergencyId,
            position.latitude,
            position.longitude,
            _currentStatus,
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
            backgroundColor: AppColors.primaryBlue, // Logo-matched success indicator
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
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)) // Use defined error color
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
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _openEmergencyChat(BuildContext context, emergency_entity.Emergency emergency) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final repo = ref.read(chatRepositoryProvider);
      // Responder creates room with patientId as targetUserId + emergencyId
      final room = await repo.createOrGetChatRoom(
        emergency.userId, // patientId
        emergencyId: widget.emergencyId,
      );
      if (mounted) {
        Navigator.pop(context);
        context.push('/chat/${room.id}', extra: 'Patient');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e'), backgroundColor: AppColors.error),
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
          final isDeafPatient = emergency.patientType.toUpperCase() == 'DEAF';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── DEAF PATIENT alert — shown prominently at top ──────
                if (isDeafPatient) ...[
                  _buildDeafAlertBanner(context, theme, emergency),
                  const SizedBox(height: 12),
                ],
                _buildPatientInfo(context, theme, emergency),
                const SizedBox(height: 16),
                // Phase 1: Increased map height from 300 to 450px
                Container(
                  height: 450,
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppShadows.neumorphicOut,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        GoogleMap(
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
                        // Phase 2 (added here but Phase 1 focus is map size): ETA floating badge
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'ETA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(
                                  '5 minutes',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue, // Logo-matched sky blue
                                  ),
                                ),
                                Text(
                                  '4.2 km away',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
            // Phase 2: Horizontal Status Timeline (more compact)
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
                    const Text(
                      'Response Progress',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // Horizontal timeline with progress line
                    Row(
                      children: List.generate(_statusSteps.length, (idx) {
                        final step = _statusSteps[idx];
                        final isDone = idx <= currentIdx;
                        final isCurrent = idx == currentIdx;

                        return Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Step circle with status color
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone ? AppColors.primaryBlue : Colors.grey.shade300, // Logo-matched sky blue
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryBlue.withOpacity(0.5), // Logo-matched glow
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  step['icon'] as IconData,
                                  color: isDone ? Colors.white : Colors.grey.shade600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Step label (short for space)
                              Text(
                                step['label']
                                    .toString()
                                    .split(' ')
                                    .take(2)
                                    .join('\n'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDone ? Colors.black : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                    // Progress line below circles
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        // Background line (all steps)
                        Container(
                          height: 2,
                          color: Colors.grey.shade300,
                        ),
                        // Progress line (completed steps)
                        Container(
                          height: 2,
                          width: currentIdx > 0
                              ? (currentIdx / (_statusSteps.length - 1)) * 300
                              : 0,
                          color: AppColors.primaryBlue, // Logo-matched progress indicator
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_currentStatus != 'RESOLVED') ...[
              // Phase 3: Enhanced action buttons with better visual hierarchy
              ElevatedButton.icon(
                onPressed: () {
                  final nextIdx = currentIdx + 1;
                  if (nextIdx < _statusSteps.length) _updateStatus(_statusSteps[nextIdx]['status']);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(
                  currentIdx + 1 < _statusSteps.length
                      ? 'Mark: ${_statusSteps[currentIdx + 1]['label'].split(' ').first}'
                      : 'Mark Resolved',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue, // Logo-matched primary action color
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Phase 3: Communication shortcuts row
              Row(
                children: [
                  // Chat button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openEmergencyChat(context, emergency),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF0C637E), width: 1.5),
                        foregroundColor: const Color(0xFF0C637E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Predefined messages button (Phase 3)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showPredefinedMessages(context, emergency);
                      },
                      icon: const Icon(Icons.message_outlined, size: 18),
                      label: const Text('Quick Msg', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primaryBlue, width: 1.5), // Logo-matched
                        foregroundColor: AppColors.primaryBlue, // Logo-matched
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.neumorphicIn),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue), SizedBox(width: 8), Text('Emergency Resolved!', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16))]),
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
                icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                label: const Text('Cancel Response', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.error, width: 1.5),
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

  /// Prominent banner shown when patient is deaf — tells responder to switch
  /// to text communication and gives a 1-tap shortcut to open the chat.
  Widget _buildDeafAlertBanner(BuildContext context, ThemeData theme, emergency_entity.Emergency emergency) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warning.withOpacity(0.12) : Color.lerp(AppColors.warning, Colors.white, 0.95)!,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.warning.withOpacity(0.45) : Color.lerp(AppColors.warning, Colors.white, 0.70)!,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark ? AppColors.warning.withOpacity(0.2) : Color.lerp(AppColors.warning, Colors.white, 0.85)!,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hearing_disabled_rounded,
                color: AppColors.warning, size: 22), // Use AppColors.warning instead of orange
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️  DEAF / MUTE PATIENT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isDark ? AppColors.warning : AppColors.warning.withOpacity(0.9),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Use text chat only. Avoid voice calls.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.warning.withOpacity(0.75)
                        : AppColors.warning.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openEmergencyChat(context, emergency),
            icon: const Icon(Icons.chat_bubble_rounded, size: 14),
            label: const Text('Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryTeal, // Logo-matched secondary action
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
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
                          icon: const Icon(Icons.record_voice_over, color: AppColors.warning),
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
                  style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold, fontSize: 15)), // Logo-matched accent
                const SizedBox(height: 12),
                
                // Phase 2: Collapsible Medical Details Section
                profileAsync.when(
                  data: (profile) {
                    if (profile == null) return const Text('No medical profile linked.', style: TextStyle(color: Colors.grey));

                    final allergies = profile.allergies.isNotEmpty ? profile.allergies.join(', ') : 'None';
                    final chronic = profile.chronicDiseases.isNotEmpty ? profile.chronicDiseases.join(', ') : 'None';
                    final medications = profile.medications.isNotEmpty ? profile.medications.map((m) => m.name).join(', ') : 'None';
                    final history = profile.medicalHistory?.isNotEmpty == true ? profile.medicalHistory! : 'None';

                    final isDeaf = profile.patientType.toUpperCase() == 'DEAF' || emergency.patientType.toUpperCase() == 'DEAF';

                    return Column(
                      children: [
                        // Collapsible header (Phase 2)
                        GestureDetector(
                          onTap: () => setState(() => _showFullMedicalDetails = !_showFullMedicalDetails),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.medical_services, size: 18, color: Colors.blue.shade900),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Medical Profile',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // Quick info (always visible)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withOpacity(0.1), // Logo-matched light blue
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${profile.bloodType}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue, // Logo-matched
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _showFullMedicalDetails
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppColors.primaryBlue, // Logo-matched
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded content (Phase 2)
                        if (_showFullMedicalDetails) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1), // Logo-matched light blue
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Blood Type', profile.bloodType),
                                _buildDetailRow('Allergies', allergies),
                                _buildDetailRow('Chronic', chronic),
                                _buildDetailRow('Medications', medications),
                                _buildDetailRow('History', history),

                                if (isDeaf) ...[
                                  const Divider(),
                                  Row(
                                    children: [
                                      Icon(Icons.hearing_disabled, size: 16, color: AppColors.primaryBlue), // Logo-matched
                                      const SizedBox(width: 8),
                                      Text('DEAF PATIENT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue)), // Logo-matched
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Use text chat only. Avoid voice calls.',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load profile: $e', style: const TextStyle(color: AppColors.error)),
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

  // Phase 3: Predefined messages popup
  void _showPredefinedMessages(BuildContext context, emergency_entity.Emergency emergency) {
    final messages = [
      "I'm almost there",
      "Coming up now",
      "Where are you in the house?",
      "I have pain medication",
      "Can you move or is pain too severe?",
      "Calling emergency hospital",
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Messages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...messages.map((msg) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _openEmergencyChat(context, emergency);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    msg,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            )),
          ],
        ),
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
    final color = isDone ? AppColors.primaryBlue : Colors.grey.shade300; // Logo-matched color
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDone ? AppColors.primaryBlue : Colors.grey.shade200, border: isCurrent ? Border.all(color: AppColors.primaryBlue, width: 3) : null), // Logo-matched
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
