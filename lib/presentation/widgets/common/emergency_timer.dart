import 'dart:async';
import 'package:flutter/material.dart';

class EmergencyTimer extends StatefulWidget {
  final String expiresAt;
  final String? serverTime;
  final VoidCallback? onExpired;
  final TextStyle? style;

  const EmergencyTimer({
    Key? key,
    required this.expiresAt,
    this.serverTime,
    this.onExpired,
    this.style,
  }) : super(key: key);

  @override
  State<EmergencyTimer> createState() => _EmergencyTimerState();
}

class _EmergencyTimerState extends State<EmergencyTimer> {
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _calculateInitialTime();
    _startTimer();
  }

  @override
  void didUpdateWidget(EmergencyTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _calculateInitialTime();
    }
  }

  void _calculateInitialTime() {
    final expiry = DateTime.parse(widget.expiresAt);
    final now = widget.serverTime != null 
        ? DateTime.parse(widget.serverTime!) 
        : DateTime.now();
    
    // We calculate the diff based on server time to stay synchronized
    final diff = expiry.difference(now).inSeconds;
    
    // If we use local time, we might need to adjust if serverTime is provided
    if (widget.serverTime != null) {
      // Calculate local offset if needed, but for simplicity we'll just use the diff
      // and apply it to current local time.
      _secondsRemaining = diff;
    } else {
      _secondsRemaining = diff;
    }

    if (_secondsRemaining < 0) _secondsRemaining = 0;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    
    final color = _secondsRemaining < 10 ? Colors.red : Colors.orange;

    return Text(
      '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: widget.style ?? TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
        fontFamily: 'monospace',
      ),
    );
  }
}
