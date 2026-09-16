import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

/// Countdown until an emergency request expires (m:ss).
///
/// Uses the theme's text style with tabular figures; the last 10 seconds are
/// shown in the SOS color. Pass [style] to override.
class EmergencyTimer extends StatefulWidget {
  final String expiresAt;
  final String? serverTime;
  final VoidCallback? onExpired;
  final TextStyle? style;

  const EmergencyTimer({
    super.key,
    required this.expiresAt,
    this.serverTime,
    this.onExpired,
    this.style,
  });

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
      _startTimer();
    }
  }

  void _calculateInitialTime() {
    final expiry = DateTime.tryParse(widget.expiresAt);
    if (expiry == null) {
      _secondsRemaining = 0;
      return;
    }
    // Server time (when provided) keeps the countdown in sync with the backend.
    final now = (widget.serverTime != null ? DateTime.tryParse(widget.serverTime!) : null) ?? DateTime.now();
    _secondsRemaining = expiry.difference(now).inSeconds;
    if (_secondsRemaining < 0) _secondsRemaining = 0;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
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
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final cs = Theme.of(context).colorScheme;
    final urgent = _secondsRemaining < 10;
    final base = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: urgent ? MfColors.sos(context) : cs.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Semantics(
      liveRegion: urgent,
      label: 'Expires in $minutes minute${minutes == 1 ? '' : 's'} $seconds second${seconds == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: Text(
        '$minutes:${seconds.toString().padLeft(2, '0')}',
        style: widget.style ?? base,
      ),
    );
  }
}
