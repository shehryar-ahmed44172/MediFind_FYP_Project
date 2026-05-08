import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_feedback_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../domain/entities/emergency.dart';
import '../../../services/audio/voice_alert_service.dart';

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
          
          if (newStatus != _currentStatus) {
            // Voice Alerts for progress
            if (newStatus == 'ASSIGNED' || newStatus == 'EN_ROUTE') {
              VoiceAlertService().speakMessage("A responder has been assigned and is on the way.");
            } else if (newStatus == 'ARRIVED') {
              VoiceAlertService().speakMessage("The responder has arrived at your location.");
            }
          }

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

  // ── AAC Communication Board ─────────────────────────────────────────────────
  // Eight universal emergency phrases with icons.
  // Tapping one sends it instantly to the assigned responder via emergency chat.

  static const List<Map<String, dynamic>> _emergencyPhrases = [
    {'icon': Icons.emergency_rounded,        'text': 'I need immediate help!'},
    {'icon': Icons.hearing_disabled_rounded, 'text': 'I am Deaf — use text chat.'},
    {'icon': Icons.favorite_rounded,         'text': 'I have chest pain.'},
    {'icon': Icons.air_rounded,              'text': 'I cannot breathe.'},
    {'icon': Icons.bolt_rounded,             'text': 'I am having a seizure.'},
    {'icon': Icons.local_hospital_rounded,   'text': 'Please call an ambulance.'},
    {'icon': Icons.monitor_heart_rounded,    'text': 'I am diabetic — feeling faint.'},
    {'icon': Icons.warning_amber_rounded,    'text': 'I have a drug allergy.'},
  ];

  Widget _buildQuickMessageButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQuickMessageBoard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.medifindGradient),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.message_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Quick Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showQuickMessageBoard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.message_rounded, color: Colors.white70, size: 20),
                SizedBox(width: 10),
                Text('Quick Emergency Messages',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a phrase to send instantly to your responder',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: _emergencyPhrases.map((phrase) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuickMessage(phrase['text'] as String);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        Icon(phrase['icon'] as IconData, color: AppColors.primaryLight, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phrase['text'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendQuickMessage(String message) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final room = await repo.createOrGetEmergencyChatRoom(widget.emergencyId);
      ref.read(chatMessagesProvider(room.id).notifier).sendMessage(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sent: $message',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

        // 3. Floating Action Buttons (right side — map controls)
        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            children: [
              _buildFloatingMapButton(Icons.my_location, () => _animateToResponder()),
              const SizedBox(height: 12),
              _buildFloatingMapButton(Icons.layers_rounded, () {}),
            ],
          ),
        ),

        // 3b. AAC Quick Message Button (left side — deaf patients only)
        if (isDeafPatient &&
            _currentStatus != 'RESOLVED' &&
            _currentStatus != 'COMPLETED')
          Positioned(
            left: 16,
            bottom: 120,
            child: _buildQuickMessageButton(context),
          ),

        // 4. Modern Draggable Bottom Sheet
        _buildDraggableBottomSheet(context, theme, emergency, settings, isDeafPatient),

        // Deaf Patient Mode Banner
        if (isDeafPatient)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hearing_disabled, color: Colors.white, size: 18),
                  SizedBox(width: 12),
                  Text(
                    'DEAF MODE: VISUAL UPDATES ACTIVE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

        if (isDeafPatient && (_currentStatus == 'EN_ROUTE' || _currentStatus == 'ARRIVED'))
          _buildDeafVisualPulse(theme),

        if (_currentStatus == 'ARRIVED' && isDeafPatient)
          _buildArrivedVisualAlert(theme),

        // 5. Resolution / Completion Overlay
        if (_currentStatus == 'RESOLVED' || _currentStatus == 'COMPLETED')
          _buildResolutionOverlay(context, theme),
      ],
    );
  }

  Widget _buildGlassHeader(ThemeData theme, AccessibilitySettings settings) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              _buildPulseIndicator(Colors.greenAccent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ESTIMATED ARRIVAL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulseIndicator(Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Icon(Icons.emergency_share_rounded, color: color, size: 22),
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
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, -10))
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
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.05)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _responderName ?? 'Assigning...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _currentStatus.replaceAll('_', ' '),
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Verified Responder',
                                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isDeafPatient) ...[
                        _buildPremiumAction(Icons.phone_rounded, Colors.greenAccent, () {
                          if (_responderPhone != null) _makePhoneCall(_responderPhone!);
                        }),
                        const SizedBox(width: 12),
                      ],
                      _buildPremiumAction(Icons.chat_bubble_rounded, AppColors.primary, () {
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat() async {
    // Show a loading indicator while we create/get the chat room
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(chatRepositoryProvider);
      final room = await repo.createOrGetEmergencyChatRoom(widget.emergencyId);
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        context.push('/chat/${room.id}', extra: _responderName ?? 'Responder');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open chat: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildModernStatusTimeline(ThemeData theme, AccessibilitySettings settings) {
    final statusOrder = ['PENDING', 'ACTIVE', 'ASSIGNED', 'RESPONDER_ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'ARRIVED', 'RESOLVED', 'COMPLETED'];
    final currentIndex = statusOrder.indexOf(_currentStatus).clamp(0, statusOrder.length - 1);
    
    // Normalize index for a 4-step UI
    int uiIndex = 0;
    if (currentIndex >= 1 && currentIndex <= 4) uiIndex = 1;
    if (currentIndex == 5) uiIndex = 2;
    if (currentIndex >= 6) uiIndex = 3;

    return Column(
      children: [
        _ModernTimelineItem(label: 'SOS Signal Received', time: 'LIVE', isDone: uiIndex >= 0, isLast: false, color: Colors.blueAccent),
        _ModernTimelineItem(label: 'Responder Assigned', time: uiIndex >= 1 ? 'SUCCESS' : '--:--', isDone: uiIndex >= 1, isCurrent: uiIndex == 1, isLast: false, color: Colors.orangeAccent),
        _ModernTimelineItem(label: 'En Route to You', time: uiIndex >= 2 ? 'TRACKING' : '--:--', isDone: uiIndex >= 2, isCurrent: uiIndex == 2, isLast: false, color: Colors.purpleAccent),
        _ModernTimelineItem(label: 'Arrived at Destination', time: uiIndex >= 3 ? 'HERE' : '--:--', isDone: uiIndex >= 3, isCurrent: uiIndex == 3, isLast: true, color: Colors.greenAccent),
      ],
    );
  }


  Widget _buildDeafVisualPulse(ThemeData theme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: _AnimatedPulseBorder(
          color: _currentStatus == 'ARRIVED' ? Colors.greenAccent : Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildArrivedVisualAlert(ThemeData theme) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.withOpacity(0.95),
              Colors.green.shade900.withOpacity(0.98),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 100),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'HELP IS HERE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'LOOK FOR THE RESPONDER NOW',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 64),
            ElevatedButton(
              onPressed: () => setState(() => _currentStatus = 'RESOLVED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade900,
                elevation: 10,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              ),
              child: const Text('I SEE THEM / DISMISS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionOverlay(BuildContext context, ThemeData theme) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF1E293B).withOpacity(0.95),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.greenAccent, width: 2),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 80),
            ),
            const SizedBox(height: 32),
            const Text(
              'EMERGENCY RESOLVED',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Help has been provided and the situation is now under control.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: const Text('RETURN HOME', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
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

  final Color color;

  const _ModernTimelineItem({
    required this.label,
    required this.time,
    required this.isDone,
    this.isCurrent = false,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isDone ? color : (isCurrent ? color : Colors.white10);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isDone ? statusColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 2),
                boxShadow: isCurrent ? [
                  BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                ] : [],
              ),
              child: isDone ? const Icon(Icons.check, size: 10, color: Colors.black) : null,
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

class _AnimatedPulseBorder extends StatefulWidget {
  final Color color;
  const _AnimatedPulseBorder({required this.color});

  @override
  State<_AnimatedPulseBorder> createState() => _AnimatedPulseBorderState();
}

class _AnimatedPulseBorderState extends State<_AnimatedPulseBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.1, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.color.withOpacity(_opacity.value),
            width: 12,
          ),
        ),
      ),
    );
  }
}

