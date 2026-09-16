import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/chat_provider.dart';
import '../../../data/datasources/remote/medifind_api_client.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_feedback_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../domain/entities/emergency.dart';
import '../../../services/audio/voice_alert_service.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_utils.dart';
import '../../widgets/map_ambulance_overlay.dart';

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
  // Tracks last marker positions so _updateMarkers skips work when nothing moved
  LatLng? _lastPatientPos;
  LatLng? _lastResponderPos;
  String? _responderName;
  String? _responderPhone;
  String? _responderProfileImage;
  double?  _responderRating;
  String? _responderType;
  String? _motorbikeNumber;
  String? _vehicleType;
  String? _organization;
  String? _responderId;
  String _currentStatus = 'PENDING';
  String _eta = 'Calculating...';
  int _selectedStars = 0;
  bool _ratingSubmitted = false;

  // AI-personalized quick replies for deaf patients (loaded lazily on first open)
  List<Map<String, dynamic>>? _aiQuickReplies;
  
  BitmapDescriptor? _ambulanceIcon;
  final Set<Marker> _markers = {};

  // ── Simulation overlay state ─────────────────────────────────────────────
  bool _simActive = false;
  LatLng? _patientLatLng;
  ScreenCoordinate? _responderScreenCoord;
  ScreenCoordinate? _patientScreenCoord;
  double _currentBearing = 90; // default east (bike faces right)
  LatLng? _prevResponderLatLng;

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
    final patientPos = LatLng(emergency.latitude, emergency.longitude);
    _patientLatLng = patientPos; // used by overlay position tracker

    final responderPos = (_responderLat != null && _responderLong != null)
        ? LatLng(_responderLat!, _responderLong!)
        : null;

    // Skip expensive marker rebuild when positions haven't changed
    if (patientPos == _lastPatientPos && responderPos == _lastResponderPos) return;
    _lastPatientPos = patientPos;
    _lastResponderPos = responderPos;

    _markers.clear();

    // During simulation the Flutter overlay widgets replace both markers so
    // we skip adding them here to avoid double rendering on the map.
    if (_simActive) return;

    // Patient marker — always fixed at the original SOS coordinates.
    // The device's built-in blue dot (myLocationEnabled: true) shows the
    // patient's real-time position separately, so these two must never be mixed.
    _markers.add(
      Marker(
        markerId: const MarkerId('patient'),
        position: patientPos,
        infoWindow: const InfoWindow(title: 'SOS Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    );

    // Responder marker — updated only when the socket delivers a new position.
    // _animateToResponder() is intentionally NOT called here: calling a camera
    // animation inside build() causes it to fire on every rebuild (timer ticks,
    // provider refreshes, etc.), which makes the map snap away from wherever
    // the patient is looking. Camera moves are triggered from the socket listener.
    if (responderPos != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('responder'),
          position: responderPos,
          icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _responderName ?? 'Responder'),
          rotation: 0,
        ),
      );
    }
  }

  void _animateToResponder() async {
    if (_mapController != null && _responderLat != null && _responderLong != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(_responderLat!, _responderLong!)),
      );
    }
  }

  // Recomputes screen-pixel positions for both overlay widgets after any
  // camera move or GPS update. Only active during simulation.
  Future<void> _updateOverlayPositions() async {
    if (!mounted || _mapController == null) return;

    if (_patientLatLng != null) {
      try {
        final c = await _mapController!.getScreenCoordinate(_patientLatLng!);
        if (mounted) setState(() => _patientScreenCoord = c);
      } catch (_) {}
    }

    if (_responderLat != null && _responderLong != null) {
      try {
        final c = await _mapController!.getScreenCoordinate(
          LatLng(_responderLat!, _responderLong!),
        );
        if (mounted) setState(() => _responderScreenCoord = c);
      } catch (_) {}
    }
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude  * math.pi / 180;
    final lat2 = to.latitude    * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
               math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilityProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isDeafPatient = (user?.patientType?.toUpperCase() == 'DEAF') || settings.textOnlyMode;
    final isSimulation = ref.watch(simulationModeProvider);
    _simActive = isSimulation; // keep marker logic in sync
    final emergencyAsync = ref.watch(getEmergencyProvider(widget.emergencyId));
    
    ref.listen(socketStreamProvider, (previous, next) {
      if (next.hasValue && !isSimulation) { // Only listen to real socket if NOT simulating
        final message = next.value!;
        final data = message.data as Map<String, dynamic>;

        if (message.event == SocketEvent.emergencyStatusChange) {
          final newStatus = data['status']?.toString() ?? data['newStatus']?.toString() ?? _currentStatus;
          
          if (newStatus != _currentStatus) {
            // Voice Alerts for progress — skip for deaf patients who rely on visual/haptic cues
            if (!isDeafPatient) {
              if (newStatus == 'ASSIGNED' || newStatus == 'EN_ROUTE') {
                VoiceAlertService().speakMessage("A responder has been assigned and is on the way.");
              } else if (newStatus == 'ARRIVED') {
                VoiceAlertService().speakMessage("The responder has arrived at your location.");
              }
            }
          }

          setState(() {
            _currentStatus = newStatus;
            if (data['responderName']         != null) _responderName         = data['responderName'];
            if (data['responderPhone']        != null) _responderPhone        = data['responderPhone'];
            if (data['responderProfileImage'] != null) _responderProfileImage = data['responderProfileImage'];
            if (data['responderRating']       != null) _responderRating       = double.tryParse(data['responderRating'].toString());
            if (data['responderType']         != null) _responderType         = data['responderType'];
            if (data['motorbikeNumber']       != null) _motorbikeNumber       = data['motorbikeNumber'];
            if (data['vehicleType']           != null) _vehicleType           = data['vehicleType'];
            if (data['organization']          != null) _organization          = data['organization'];
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
          // Animate camera ONLY here — after a genuine responder GPS update.
          // Never call this inside build() or _updateMarkers().
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _animateToResponder();
              _updateOverlayPositions();
            }
          });
        }
      }
    });

    // Handle Simulation logic
    if (isSimulation) {
      _startSimulation();
    }

    final theme = AppTheme.buildTheme(settings);

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: emergencyAsync.when(
          data: (emergency) {
            _updateMarkers(emergency);
            if (_responderId == null && emergency.responderId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _responderId = emergency.responderId);
              });
            }
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
        // Compute new position before setState so we can calc bearing cleanly.
        final newLat = (_responderLat  ?? emergency.latitude  + 0.01) - 0.0005;
        final newLng = (_responderLong ?? emergency.longitude + 0.01) - 0.0005;
        final currPos = LatLng(newLat, newLng);

        // Bearing: direction from previous position → new position.
        if (_prevResponderLatLng != null) {
          _currentBearing = _calculateBearing(_prevResponderLatLng!, currPos);
        }
        _prevResponderLatLng = currPos;

        setState(() {
          _responderLat     = newLat;
          _responderLong    = newLng;
          _eta              = '4 min';
          _responderName    = 'Ali Hassan';
          _responderRating  = 4.8;
          _responderType    = 'PARAMEDIC';
          _vehicleType      = 'MOTORBIKE_AMBULANCE';
          _motorbikeNumber  = 'LHR-2847';
          _organization     = 'Rescue 1122';
          _currentStatus    = 'EN_ROUTE';
        });

        // Refresh overlay screen-coordinates after each simulated move.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animateToResponder();
            _updateOverlayPositions();
          }
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
    // Load AI replies from backend on first open; use static phrases as fallback
    if (_aiQuickReplies == null) {
      final apiClient = ref.read(apiClientProvider);
      apiClient.getDeafQuickReplies(widget.emergencyId).then((replies) {
        if (mounted) setState(() => _aiQuickReplies = replies);
      }).catchError((_) {
        // Keep null — falls back to static phrases
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final phrases = _aiQuickReplies ?? _emergencyPhrases;
          final isAi = _aiQuickReplies != null;

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.message_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Quick Emergency Messages',
                          style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    if (isAi)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: const Text('AI', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAi
                      ? 'Personalized for your emergency — tap to send'
                      : 'Tap a phrase to send instantly to your responder',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: phrases.map((phrase) {
                    final text = phrase['text'] as String;
                    final iconData = isAi
                        ? _iconFromName(phrase['icon'] as String? ?? '')
                        : (phrase['icon'] as IconData);
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendQuickMessage(text);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                        ),
                        child: Row(
                          children: [
                            Icon(iconData, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(color: AppColors.onSurface, fontSize: 11.5, fontWeight: FontWeight.w600),
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
          );
        },
      ),
    );
  }

  // Maps backend icon name strings (Material icon names) to Flutter IconData
  IconData _iconFromName(String name) {
    const map = <String, IconData>{
      'emergency': Icons.emergency_rounded,
      'hearing_disabled': Icons.hearing_disabled_rounded,
      'favorite': Icons.favorite_rounded,
      'air': Icons.air_rounded,
      'bolt': Icons.bolt_rounded,
      'local_hospital': Icons.local_hospital_rounded,
      'monitor_heart': Icons.monitor_heart_rounded,
      'warning_amber': Icons.warning_amber_rounded,
      'medication': Icons.medication_rounded,
      'bloodtype': Icons.bloodtype_rounded,
      'accessible': Icons.accessible_rounded,
      'help': Icons.help_rounded,
      'sick': Icons.sick_rounded,
      'thermostat': Icons.thermostat_rounded,
    };
    return map[name] ?? Icons.message_rounded;
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
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
            buildingsEnabled: false,
            indoorViewEnabled: false,
            tiltGesturesEnabled: false,
            style: MapUtils.getDarkMapStyle(),
            onMapCreated: (GoogleMapController controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
              _mapController = controller;
            },
            onCameraIdle: () {
              // After any camera animation finishes, recalculate overlay positions
              // so the Flutter widgets stay pinned to the correct lat/lng.
              if (mounted && _simActive) _updateOverlayPositions();
            },
          ),
        ),

        // ── Simulation overlays ──────────────────────────────────────────────
        // These Flutter widgets replace the default Google Maps markers during
        // simulation. IgnorePointer ensures they never block touch on the map.
        if (_simActive && _patientScreenCoord != null)
          Positioned(
            left:  _patientScreenCoord!.x.toDouble() - 34,
            top:   _patientScreenCoord!.y.toDouble() - 80,
            child: IgnorePointer(
              child: const PatientAvatarWidget(),
            ),
          ),

        if (_simActive && _responderScreenCoord != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            left:  _responderScreenCoord!.x.toDouble() - 64,
            top:   _responderScreenCoord!.y.toDouble() - 58,
            child: IgnorePointer(
              child: MotorbikeAmbulanceWidget(bearing: _currentBearing),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface, size: 22),
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
                color: AppColors.primary.withOpacity(0.90),
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
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            children: [
              _buildPulseIndicator(AppColors.success),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ESTIMATED ARRIVAL',
                      style: TextStyle(
                        color: AppColors.primary.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eta,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 20,
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
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.error.withOpacity(0.25)),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Icon(Icons.emergency_share_rounded, color: color, size: 20),
    );
  }

  Widget _buildFloatingMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.primary.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
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
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, -8))
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // ── drag handle ──
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),

              // ── Status chip ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          _responderName != null ? 'RESPONDER ASSIGNED' : 'FINDING RESPONDER...',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Responder card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE2F0F3), Color(0xFFB7D9E0)],
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: _responderProfileImage != null
                              ? Image.network(_responderProfileImage!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildInitialsAvatar())
                              : _buildInitialsAvatar(),
                        ),
                        const SizedBox(width: 14),

                        // Name + badge + rating
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _responderName ?? 'Assigning...',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: AppColors.onSurface,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (_responderType != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.primaryLight.withOpacity(0.25)),
                                      ),
                                      child: Text(
                                        _responderType!.replaceAll('_', ' '),
                                        style: const TextStyle(color: AppColors.primaryLight, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (_responderRating != null) ...[
                                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                    const SizedBox(width: 3),
                                    Text(
                                      _responderRating!.toStringAsFixed(1),
                                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ],
                              ),
                              if (_organization != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    _organization!,
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Column(
                          children: [
                            if (!isDeafPatient)
                              _buildPremiumAction(Icons.phone_rounded, AppColors.success, () {
                                if (_responderPhone != null) _makePhoneCall(_responderPhone!);
                              }),
                            if (!isDeafPatient) const SizedBox(height: 10),
                            _buildPremiumAction(Icons.chat_bubble_rounded, AppColors.primary, _openChat),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 12),

                    // Vehicle row
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, color: AppColors.warning, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_vehicleType == 'MOTORBIKE_AMBULANCE' || _vehicleType == null)
                                    ? 'Motorbike Ambulance'
                                    : _vehicleType!.replaceAll('_', ' '),
                                style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              const Text('Emergency Response Vehicle', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            ],
                          ),
                        ),
                        // Number plate
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.onSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (_motorbikeNumber ?? 'N/A').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Divider(color: Colors.grey.shade100),
              const SizedBox(height: 16),
              const Text('Live Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.onSurface)),
              const SizedBox(height: 20),
              _buildModernStatusTimeline(theme, settings),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showCancelDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('CANCEL EMERGENCY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInitialsAvatar() {
    final initials = (_responderName?.isNotEmpty == true)
        ? _responderName!.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: initials.length == 1 ? 26 : 20,
        ),
      ),
    );
  }

  Widget _buildPremiumAction(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.22), width: 1),
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
            backgroundColor: AppColors.error,
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
              AppColors.success.withOpacity(0.95),
              AppColors.success.withOpacity(0.98),
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
                foregroundColor: AppColors.success,
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
        color: AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success.withOpacity(0.4), width: 2),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Emergency Resolved',
                  style: TextStyle(color: AppColors.onSurface, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Help has been provided and the\nsituation is now under control.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 36),

                if (!_ratingSubmitted && _responderId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Rate your responder',
                          style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text('How was your experience?', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final star = i + 1;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedStars = star),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  _selectedStars >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: _selectedStars >= star ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                  size: 40,
                                ),
                              ),
                            );
                          }),
                        ),
                        if (_selectedStars > 0) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final responderId = _responderId!;
                                final stars = _selectedStars;
                                setState(() => _ratingSubmitted = true);
                                try {
                                  await ref.read(rateResponderProvider(RateResponderParams(
                                    responderId: responderId,
                                    emergencyId: widget.emergencyId,
                                    stars: stars,
                                  )).future);
                                } catch (_) {}
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Skip', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ),
                ] else ...[
                  if (_ratingSubmitted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          const SizedBox(width: 6),
                          Text('Thanks for your feedback!', style: TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Return Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Emergency?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
        content: const Text('Are you sure you want to cancel the active emergency?', style: TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    final active = isDone || isCurrent;
    final dotColor = active ? color : const Color(0xFFE2E8F0);

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
                color: isDone ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
                boxShadow: isCurrent ? [
                  BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, spreadRadius: 1)
                ] : [],
              ),
              child: isDone ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? color.withOpacity(0.25) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: active ? AppColors.onSurface : const Color(0xFF94A3B8),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    color: active ? color : const Color(0xFFCBD5E1),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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

