import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/auth_provider.dart';

class SosCountdownScreen extends ConsumerStatefulWidget {
  final String emergencyType;
  final double latitude;
  final double longitude;
  final String? additionalInfo;

  const SosCountdownScreen({
    Key? key,
    required this.emergencyType,
    required this.latitude,
    required this.longitude,
    this.additionalInfo,
  }) : super(key: key);

  @override
  ConsumerState<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends ConsumerState<SosCountdownScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsLeft = 10;
  bool _cancelled = false;
  bool _isSending = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

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
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _sendSOS() async {
    if (_cancelled || _isSending) return;
    setState(() => _isSending = true);

    try {
      final userId = await ref.read(currentUserIdProvider.future);

      final params = CreateEmergencyParams(
        emergencyType: widget.emergencyType,
        latitude: widget.latitude,
        longitude: widget.longitude,
        additionalInfo: widget.additionalInfo,
      );

      final emergency = await ref.read(createEmergencyProvider(params).future);

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
        context.go('/home/emergency');
      }
    }
  }

  void _cancel() {
    _timer.cancel();
    setState(() => _cancelled = true);
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS cancelled'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_isSending) {
      return Scaffold(
        backgroundColor: Colors.red.shade700,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text('Sending SOS Alert...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Notifying emergency responders',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.red.shade800,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.emergency_rounded, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              const Text(
                'SOS Sending In...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Alert will be sent automatically unless cancelled',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 48),

              // Countdown
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 6),
                ),
                child: Center(
                  child: Text(
                    '$_secondsLeft',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.emergencyType.replaceAll('_', ' '),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 56),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('CANCEL SOS',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
