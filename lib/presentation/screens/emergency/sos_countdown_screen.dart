import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_utils.dart';
import '../../../services/socket/socket_service.dart';
import 'dart:math' as math;
import '../../../services/audio/voice_alert_service.dart';

class SosCountdownScreen extends ConsumerStatefulWidget {
  final String emergencyType;
  final double latitude;
  final double longitude;
  final String? additionalInfo;

  const SosCountdownScreen({
    super.key,
    this.emergencyType = 'GENERAL',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.additionalInfo,
  });

  @override
  ConsumerState<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends ConsumerState<SosCountdownScreen>
    with TickerProviderStateMixin {
  late Timer _timer;
  int _secondsLeft = 60;
  final int _maxSeconds = 60;
  bool _cancelled = false;
  bool _isSearching = false;
  String? _emergencyId;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Three staggered radar ring controllers — InDrive style
  late AnimationController _radar1Controller;
  late AnimationController _radar2Controller;
  late AnimationController _radar3Controller;

  // "Responder Found" flash overlay
  bool _responderFound = false;
  late AnimationController _foundController;
  late Animation<double> _foundOpacity;

  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  BitmapDescriptor? _ambulanceIcon;
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _confirmedIcon;

  late AnimationController _bikeMovementController;
  final List<_SimulatedBike> _simulatedBikes = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Three radar rings — each delayed by 0.66s to stagger the expanding effect
    _radar1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _radar2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    Future.delayed(const Duration(milliseconds: 666), () {
      if (mounted) _radar2Controller.repeat();
    });

    _radar3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    Future.delayed(const Duration(milliseconds: 1333), () {
      if (mounted) _radar3Controller.repeat();
    });

    // "Responder Found" flash
    _foundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _foundOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _foundController, curve: Curves.easeIn),
    );

    _bikeMovementController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateBikePositions);
    _bikeMovementController.repeat();

    _loadMarkerIcons();
    _initializeSearch();
    _initSimulatedBikes();
  }

  void _initSimulatedBikes() {
    for (int i = 0; i < 4; i++) {
      _simulatedBikes.add(_SimulatedBike(
        id: 'sim_$i',
        position: LatLng(
          widget.latitude + (_random.nextDouble() - 0.5) * 0.015,
          widget.longitude + (_random.nextDouble() - 0.5) * 0.015,
        ),
        target: LatLng(
          widget.latitude + (_random.nextDouble() - 0.5) * 0.015,
          widget.longitude + (_random.nextDouble() - 0.5) * 0.015,
        ),
      ));
    }
  }

  void _updateBikePositions() {
    if (!mounted || _cancelled || _ambulanceIcon == null || _responderFound) return;

    setState(() {
      _markers.clear();
      
      // User Marker
      _markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(widget.latitude, widget.longitude),
        icon: _userIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));

      // Move each bike
      for (var bike in _simulatedBikes) {
        bike.moveTowardsTarget();
        if (bike.hasReachedTarget()) {
          bike.setNewTarget(widget.latitude, widget.longitude, _random);
        }
        
        _markers.add(Marker(
          markerId: MarkerId(bike.id),
          position: bike.position,
          icon: _ambulanceIcon!,
          rotation: bike.rotation,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        ));
      }
    });
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final icons = await Future.wait([
        MapUtils.getAmbulanceMarker(),
        MapUtils.getPatientMarker(),
        MapUtils.getConfirmedResponderMarker(),
      ]);
      if (mounted) {
        setState(() {
          _ambulanceIcon  = icons[0];
          _userIcon       = icons[1];
          _confirmedIcon  = icons[2];
        });
      }
    } catch (e) {
      debugPrint('Error loading marker icons: $e');
    }
  }

  /// Called by socket/polling when a real responder accepts.
  /// Stops the simulation, shows the confirmation flash, then navigates.
  void _onResponderAssigned() {
    if (_responderFound) return; // guard against double-fire
    setState(() => _responderFound = true);
    _foundController.forward();
    HapticFeedback.heavyImpact();

    // Replace all simulated bikes with the confirmed marker at center
    if (_confirmedIcon != null) {
      setState(() {
        _markers
          ..removeWhere((m) => m.markerId.value.startsWith('sim_'))
          ..add(Marker(
            markerId: const MarkerId('confirmed_responder'),
            position: LatLng(widget.latitude, widget.longitude),
            icon: _confirmedIcon!,
            anchor: const Offset(0.5, 0.5),
          ));
      });
    }
  }

  void _initializeSearch() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsLeft--);

        final user = ref.read(currentUserProvider).valueOrNull;
        if (user?.patientType == 'DEAF') {
          HapticFeedback.heavyImpact(); // Stronger feedback for Deaf patients
        } else {
          HapticFeedback.lightImpact();
        }

        // HEARTBEAT POLLING: Every 5 seconds, manually refresh status as a fallback
        if (_secondsLeft % 5 == 0 && _emergencyId != null) {
          ref.invalidate(getEmergencyProvider(_emergencyId!));
        }

        // Auto-cancel when countdown reaches 0
        if (_secondsLeft <= 0) {
          timer.cancel();
          _autoCancel();
        }
      }
    });

    // Start SOS Broadcast immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendSOS();
    });
  }


  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _radar1Controller.dispose();
    _radar2Controller.dispose();
    _radar3Controller.dispose();
    _foundController.dispose();
    _bikeMovementController.dispose();
    super.dispose();
  }

  Future<void> _sendSOS() async {
    if (_cancelled || _isSearching) return;
    
    setState(() => _isSearching = true);
    try {
      final params = CreateEmergencyParams(
        emergencyType: widget.emergencyType,
        latitude: widget.latitude,
        longitude: widget.longitude,
        additionalInfo: widget.additionalInfo,
      );

      final emergency = await ref.read(createEmergencyProvider(params).future);
      
      if (mounted) {
        setState(() {
          _emergencyId = emergency.id;
        });
        
        // Small delay to ensure socket is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) SocketService.instance.joinEmergencyRoom(emergency.id);
        });
        
        final _user = ref.read(currentUserProvider).valueOrNull;
        final _isDeaf = (_user?.patientType?.toUpperCase() == 'DEAF') ||
            ref.read(accessibilityProvider).textOnlyMode;
        if (!_isDeaf) {
          VoiceAlertService().speakMessage("Emergency request sent. Searching for nearby responders.");
        }
      }
      
    } catch (e) {
      debugPrint('❌ [SOS] Failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trigger SOS: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _autoCancel() async {
    if (_emergencyId != null) {
      await ref.read(cancelEmergencyProvider(_emergencyId!).future);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No responders available. Emergency cancelled automatically.')),
      );
      context.go('/home');
    }
  }

  void _cancel() {
    _timer.cancel();
    setState(() => _cancelled = true);
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('SOS Alert Cancelled', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilityProvider);
    final theme = Theme.of(context);

    // Robust fallback: Watch the actual emergency state for status changes
    final emergencyState = ref.watch(getEmergencyProvider(_emergencyId ?? ''));
    emergencyState.whenData((emergency) {
      if (emergency != null) {
        final status = emergency.status.toString().toUpperCase();
        if (status == 'ASSIGNED' ||
            status == 'ACCEPTED' ||
            status == 'RESPONDER_ASSIGNED' ||
            status == 'EN_ROUTE') {
          _onResponderAssigned();
          _timer.cancel();
          // Brief delay so the "Responder Found" flash is visible before navigating
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) context.go('/emergency/$_emergencyId/tracking');
          });
        }
      }
    });

    // Listen for responder assigned event via socket
    ref.listen(socketStreamProvider, (previous, next) {
      if (next.hasValue && next.value!.event == SocketEvent.emergencyStatusChange) {
        final rawData = next.value!.data;
        final data = (rawData is Map && rawData.containsKey('data')) ? rawData['data'] : rawData;

        if (data is Map) {
          final status = (data['status'] ?? data['newStatus'] ?? '').toString().toUpperCase();
          if (status == 'ASSIGNED' ||
              status == 'ACCEPTED' ||
              status == 'RESPONDER_ASSIGNED' ||
              status == 'EN_ROUTE') {
            _onResponderAssigned();
            _timer.cancel();
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (mounted) context.go('/emergency/$_emergencyId/tracking');
            });
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false, // Let the map bleed to the top
        child: Stack(
          children: [
          // Real Google Map
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.latitude, widget.longitude),
                    zoom: 15,
                  ),
                  markers: _markers,
                  style: MapUtils.getDarkMapStyle(),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                ),
                // ── Triple-ring InDrive-style radar ──────────────────────
                ...[_radar1Controller, _radar2Controller, _radar3Controller]
                    .map((ctrl) => Center(
                          child: AnimatedBuilder(
                            animation: ctrl,
                            builder: (_, __) {
                              final v = ctrl.value;
                              return Container(
                                width: 220 * v,
                                height: 220 * v,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary
                                      .withOpacity(0.10 * (1 - v)),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withOpacity(0.70 * (1 - v)),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        )),

                // ── Responder Found flash overlay ────────────────────────
                if (_responderFound)
                  FadeTransition(
                    opacity: _foundOpacity,
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E)
                                        .withOpacity(0.45),
                                    blurRadius: 24,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 40),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Responder Found!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'En route to your location',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Deaf Patient Mode Banner
          if (ref.watch(currentUserProvider).valueOrNull?.patientType == 'DEAF')
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Icon(Icons.hearing_disabled, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'DEAF PATIENT MODE ACTIVE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('VISUAL ALERTS ON', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Main Countdown Body Surface
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: AppShadows.neumorphicOut,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      'Emergency SOS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Responders will be notified automatically',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                    
                    const Spacer(),

                    // Radial Countdown
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.6,
                          maxHeight: MediaQuery.of(context).size.width * 0.6,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Stack(
                            fit: StackFit.expand,
                          children: [
                            // Soft Outer Glow Background
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.15),
                                    blurRadius: 40,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Progress Ring indicator
                            CircularProgressIndicator(
                              value: _secondsLeft / _maxSeconds,
                              strokeWidth: 12,
                              backgroundColor: Colors.red.shade50,
                              color: Colors.red.shade600,
                              strokeCap: StrokeCap.round,
                            ),
                            
                            // Inner Text
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '00:${_secondsLeft.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.red,
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                  const Text(
                                    'SECONDS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                    const Spacer(),

                    // Cancel Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppShadows.neumorphicOut,
                      ),
                      child: ElevatedButton(
                        onPressed: _cancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.scaffoldBackgroundColor,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'CANCEL EMERGENCY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

}

class _SimulatedBike {
  final String id;
  LatLng position;
  LatLng target;
  double rotation = 0;
  final double speed = 0.00005;

  _SimulatedBike({required this.id, required this.position, required this.target}) {
    _calculateRotation();
  }

  void moveTowardsTarget() {
    double latDiff = target.latitude - position.latitude;
    double lngDiff = target.longitude - position.longitude;
    double distance = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);

    if (distance > speed) {
      position = LatLng(
        position.latitude + (latDiff / distance) * speed,
        position.longitude + (lngDiff / distance) * speed,
      );
    }
  }

  bool hasReachedTarget() {
    double latDiff = target.latitude - position.latitude;
    double lngDiff = target.longitude - position.longitude;
    return math.sqrt(latDiff * latDiff + lngDiff * lngDiff) < speed * 2;
  }

  void setNewTarget(double centerLat, double centerLng, math.Random random) {
    target = LatLng(
      centerLat + (random.nextDouble() - 0.5) * 0.015,
      centerLng + (random.nextDouble() - 0.5) * 0.015,
    );
    _calculateRotation();
  }

  void _calculateRotation() {
    double lat1 = position.latitude * math.pi / 180;
    double lng1 = position.longitude * math.pi / 180;
    double lat2 = target.latitude * math.pi / 180;
    double lng2 = target.longitude * math.pi / 180;

    double y = math.sin(lng2 - lng1) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lng2 - lng1);
    rotation = math.atan2(y, x) * 180 / math.pi;
  }
}

