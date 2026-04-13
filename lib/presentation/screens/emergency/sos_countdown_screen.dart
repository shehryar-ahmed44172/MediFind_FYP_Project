import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:math' as math;
import '../../services/audio/voice_alert_service.dart';

class SosCountdownScreen extends ConsumerStatefulWidget {
  final String emergencyType;
  final double latitude;
  final double longitude;
  final String? additionalInfo;

  const SosCountdownScreen({
    Key? key,
    this.emergencyType = 'GENERAL',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.additionalInfo,
  }) : super(key: key);

  @override
  ConsumerState<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends ConsumerState<SosCountdownScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsLeft = 10;
  final int _maxSeconds = 10;
  bool _cancelled = false;
  bool _isSending = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Continuous pulse for the glowing rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    HapticFeedback.vibrate();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        _sendSOS();
      } else {
        setState(() => _secondsLeft--);
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _sendSOS() async {
    if (_cancelled || _isSending) return;
    setState(() => _isSending = true);

    try {
      final params = CreateEmergencyParams(
        emergencyType: widget.emergencyType,
        latitude: widget.latitude,
        longitude: widget.longitude,
        additionalInfo: widget.additionalInfo,
      );

      final emergency = await ref.read(createEmergencyProvider(params).future);
      VoiceAlertService().speakMessage("Emergency triggered. Help is on the way.");

      if (mounted) {
        context.go('/home/emergency/${emergency.id}/tracking');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/home');
      }
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
    if (_isSending) return _buildSendingOverlay();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Map Mockup
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              color: AppColors.primaryLight.withOpacity(0.15), // Mock map color
              child: Stack(
                children: [
                  // Fake map grid lines and markers
                  CustomPaint(painter: _FakeMapPainter(), size: Size.infinite),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                      ),
                    ),
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
                        color: Colors.black87,
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
    );
  }

  Widget _buildSendingOverlay() {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Colors.white, 
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Broadcasting Alert...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Finding nearest available responders',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple fake map painter to make the background look like a map without importing heavy dependencies
class _FakeMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.05)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Draw some random "roads"
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.4), paint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.5, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.2, size.height), Offset(size.width * 0.8, 0), paint);
    
    paint.strokeWidth = 4;
    paint.color = AppColors.primary.withOpacity(0.03);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), paint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.8, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
