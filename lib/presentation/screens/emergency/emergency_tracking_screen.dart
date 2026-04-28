import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_feedback_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../domain/entities/emergency.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_utils.dart';

class EmergencyTrackingScreen extends ConsumerStatefulWidget {
  final String emergencyId;
  const EmergencyTrackingScreen({super.key, required this.emergencyId});

  @override
  ConsumerState<EmergencyTrackingScreen> createState() => _EmergencyTrackingScreenState();
}

class _EmergencyTrackingScreenState extends ConsumerState<EmergencyTrackingScreen> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  double? _responderLat;
  double? _responderLong;
  String? _responderName;
  String? _responderPhone;
  String _currentStatus = 'PENDING';
  String _eta = 'Calculating...';
  
  BitmapDescriptor? _ambulanceIcon;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = SocketService.instance;
      socketService.joinEmergencyRoom(widget.emergencyId);
      socketService.joinLocationRoom(widget.emergencyId);
      ref.read(socketStreamProvider);
    });
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
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    );

    // Responder Marker
    if (_responderLat != null && _responderLong != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('responder'),
          position: LatLng(_responderLat!, _responderLong!),
          icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _responderName ?? 'Responder'),
          rotation: 0, // Could calculate rotation based on movement later
        ),
      );
      
      // Auto-center if needed
      _animateToResponder();
    }
  }

  void _animateToResponder() async {
    if (_mapController != null && _responderLat != null && _responderLong != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(_responderLat!, _responderLong!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilityProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isDeafPatient = (user?.patientType?.toUpperCase() == 'DEAF') || settings.textOnlyMode;
    final isSimulation = ref.watch(simulationModeProvider);
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));
    
    ref.listen(socketStreamProvider, (previous, next) {
      if (next.hasValue && !isSimulation) { // Only listen to real socket if NOT simulating
        final message = next.value!;
        final data = message.data as Map<String, dynamic>;

        if (message.event == SocketEvent.emergencyStatusChange) {
          final newStatus = data['status']?.toString() ?? data['newStatus']?.toString() ?? _currentStatus;
          setState(() {
            _currentStatus = newStatus;
            if (data['responderName'] != null) _responderName = data['responderName'];
            if (data['responderPhone'] != null) _responderPhone = data['responderPhone'];
          });
          
          if (newStatus == 'ARRIVED' && isDeafPatient) {
            if (settings.vibrationFeedback) HapticFeedbackService.sosPattern();
          }
        } 
        else if (message.event == SocketEvent.responderLocationUpdate) {
          setState(() {
            _responderLat = double.tryParse(data['latitude'].toString());
            _responderLong = double.tryParse(data['longitude'].toString());
            _eta = data['eta']?.toString() ?? _eta;
          });
        }
      }
    });

    // Handle Simulation logic
    if (isSimulation) {
      _startSimulation();
    }

    final theme = AppTheme.buildDarkTheme(settings);

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: emergencyAsync.when(
          data: (emergency) {
            _updateMarkers(emergency);
            return _buildModernBody(context, theme, emergency, settings, isDeafPatient);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
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
        setState(() {
          // Move responder slightly closer to patient on each tick
          _responderLat = (_responderLat ?? emergency.latitude + 0.01) - 0.0005;
          _responderLong = (_responderLong ?? emergency.longitude + 0.01) - 0.0005;
          _eta = "4 min";
          _responderName = "Simulated Responder";
          _currentStatus = 'EN_ROUTE';
        });
      }
    });
  }

  Widget _buildModernBody(BuildContext context, ThemeData theme, Emergency emergency, AccessibilitySettings settings, bool isDeafPatient) {
    return Stack(
      children: [
        // 1. Dark Map
        Positioned.fill(
          child: GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: LatLng(emergency.latitude, emergency.longitude),
              zoom: 15,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: MapUtils.getDarkMapStyle(),
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
              _mapController = controller;
            },
          ),
        ),

        // 2. Glassmorphism Top Bar
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildGlassHeader(theme, settings)),
            ],
          ),
        ),

        // 3. Floating Action Buttons
        Positioned(
          right: 16,
          bottom: 120, // Above bottom sheet
          child: Column(
            children: [
              _buildFloatingMapButton(Icons.my_location, () => _animateToResponder()),
              const SizedBox(height: 12),
              _buildFloatingMapButton(Icons.layers_rounded, () {}),
            ],
          ),
        ),

        // 4. Modern Draggable Bottom Sheet
        _buildDraggableBottomSheet(context, theme, emergency, settings, isDeafPatient),

        if (_currentStatus == 'ARRIVED' && isDeafPatient)
          _buildArrivedVisualAlert(theme),
      ],
    );
  }

  Widget _buildGlassHeader(ThemeData theme, AccessibilitySettings settings) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_share_rounded, color: Colors.greenAccent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Help arriving in',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    Text(
                      _eta,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildDraggableBottomSheet(BuildContext context, ThemeData theme, Emergency emergency, AccessibilitySettings settings, bool isDeafPatient) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5))
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_responderName ?? 'Assigning Responder...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                        Text('${_currentStatus.replaceAll('_', ' ')} • Active Response', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (!isDeafPatient) ...[
                    _buildCircleAction(Icons.phone_rounded, Colors.green, () {
                      if (_responderPhone != null) {
                        _makePhoneCall(_responderPhone!);
                      }
                    }),
                    const SizedBox(width: 12),
                  ],
                  _buildCircleAction(Icons.chat_bubble_rounded, Colors.blue, () {
                    _openChat();
                  }),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
              const Text('Live Status Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 20),
              _buildModernStatusTimeline(theme, settings),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showCancelDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('CANCEL EMERGENCY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat() {
    // Navigate to Chat Screen (Planned Feature)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildModernStatusTimeline(ThemeData theme, AccessibilitySettings settings) {
    final statusOrder = ['PENDING', 'RESPONDER_ASSIGNED', 'EN_ROUTE', 'ARRIVED', 'RESOLVED'];
    final currentIndex = statusOrder.indexOf(_currentStatus).clamp(0, 4);

    return Column(
      children: [
        _ModernTimelineItem(label: 'SOS Signal Received', time: '1:42 PM', isDone: currentIndex >= 0, isLast: false),
        _ModernTimelineItem(label: 'Responder Dispatched', time: '1:44 PM', isDone: currentIndex >= 1, isLast: false),
        _ModernTimelineItem(label: 'En Route to Location', time: 'ETA 4 min', isDone: currentIndex > 2, isCurrent: currentIndex == 2, isLast: false),
        _ModernTimelineItem(label: 'Arrived at Destination', time: '--:--', isDone: currentIndex >= 3, isLast: true),
      ],
    );
  }


  Widget _buildArrivedVisualAlert(ThemeData theme) {
    return Positioned.fill(
      child: Container(
        color: Colors.green.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 100),
            const SizedBox(height: 24),
            const Text('HELP IS HERE!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),
            const Text('The responder has arrived at your location.', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => setState(() => _currentStatus = 'RESOLVED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cancel Emergency?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: const Text('Are you sure you want to cancel the active emergency?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(cancelEmergencyProvider(widget.emergencyId).future);
              if (mounted) context.go('/home');
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _ModernTimelineItem extends StatelessWidget {
  final String label;
  final String time;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _ModernTimelineItem({
    required this.label,
    required this.time,
    required this.isDone,
    this.isCurrent = false,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? Colors.greenAccent : (isCurrent ? Colors.blueAccent : Colors.grey.withOpacity(0.3));
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isDone ? Colors.greenAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: isCurrent ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : null,
              ),
              child: isDone ? const Icon(Icons.check, size: 8, color: Colors.black) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? Colors.greenAccent.withOpacity(0.3) : Colors.white10,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDone || isCurrent ? Colors.white : Colors.white38,
                  fontWeight: isDone || isCurrent ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              Text(
                time,
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

