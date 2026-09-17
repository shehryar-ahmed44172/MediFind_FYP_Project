import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/call/call_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/design_system/design_system.dart';

/// Full-screen in-app call: ringing (incoming / outgoing), connecting, connected, ended.
///
/// Built for everyone including Deaf users: every state is shown in large text, an
/// incoming call also flashes the screen, and video calls keep the remote picture
/// as large as possible for sign language.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  final CallService _call = CallService.instance;
  late final AnimationController _pulse;
  Timer? _clock;
  bool _popped = false;

  static const _bg = Color(0xFF0B1320);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _call.state.addListener(_onStateChanged);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _call.state.value.phase == CallPhase.connected) setState(() {});
    });
  }

  @override
  void dispose() {
    _call.state.removeListener(_onStateChanged);
    _pulse.dispose();
    _clock?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (_call.state.value.phase == CallPhase.idle) {
      if (!_popped && Navigator.of(context).canPop()) {
        _popped = true;
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _call.state.value;
    return PopScope(
      // Leaving the screen must not leave a hidden, running call behind
      canPop: s.phase == CallPhase.idle || s.phase == CallPhase.ended,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && s.phase == CallPhase.connected) _call.hangUp();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (s.isVideo && s.phase == CallPhase.connected && s.hasRemoteVideo)
              RTCVideoView(_call.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else
              _buildPortrait(s),
            if (s.phase == CallPhase.incoming) _buildIncomingFlash(),
            if (s.isVideo && s.cameraOn && s.isActive && s.phase != CallPhase.incoming)
              Positioned(
                right: MfSpace.md,
                top: MediaQuery.paddingOf(context).top + MfSpace.md,
                width: 110,
                height: 150,
                child: ClipRRect(
                  borderRadius: MfRadius.mdAll,
                  child: ColoredBox(
                    color: Colors.black,
                    child: RTCVideoView(_call.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),
              ),
            if (s.isVideo && s.phase == CallPhase.connected && s.hasRemoteVideo)
              Positioned(left: 0, right: 0, top: 0, child: _buildTopBar(s)),
            Positioned(left: 0, right: 0, bottom: 0, child: _buildControls(s)),
          ],
        ),
      ),
    );
  }

  /// Screen edge pulses while ringing (visual ring for Deaf users).
  Widget _buildIncomingFlash() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25 + 0.6 * _pulse.value), width: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(CallState s) {
    return Container(
      padding: EdgeInsets.fromLTRB(MfSpace.md, MediaQuery.paddingOf(context).top + MfSpace.sm, 140, MfSpace.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.peer?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(_statusText(s), style: const TextStyle(color: Colors.white70, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildPortrait(CallState s) {
    final text = Theme.of(context).textTheme;
    final ringing = s.phase == CallPhase.incoming || s.phase == CallPhase.outgoing;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MfSpace.lg),
        child: Column(
          children: [
            const SizedBox(height: MfSpace.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.isVideo ? Icons.videocam_outlined : Icons.call_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: MfSpace.xs),
                Text(
                  s.isVideo ? 'MediFind video call' : 'MediFind voice call',
                  style: text.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                padding: EdgeInsets.all(ringing ? 10 + 8 * _pulse.value : 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: ringing ? 0.12 + 0.12 * _pulse.value : 0.12),
                ),
                child: child,
              ),
              child: MfAvatar(imageUrl: s.peer?.imageUrl, name: s.peer?.name, size: 132),
            ),
            const SizedBox(height: MfSpace.lg),
            Text(
              s.peer?.name ?? '',
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: MfSpace.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                _statusText(s),
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: s.phase == CallPhase.ended ? const Color(0xFFFCA5A5) : Colors.white70),
              ),
            ),
            if (s.isVideo && s.phase == CallPhase.outgoing && s.cameraOn) ...[
              const SizedBox(height: MfSpace.md),
              const Text('Your camera is on', style: TextStyle(color: Colors.white54)),
            ],
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  String _statusText(CallState s) {
    switch (s.phase) {
      case CallPhase.outgoing:
        return 'Ringing…';
      case CallPhase.incoming:
        return s.isVideo ? 'Incoming video call' : 'Incoming voice call';
      case CallPhase.connecting:
        return 'Connecting…';
      case CallPhase.connected:
        final start = s.connectedAt ?? DateTime.now();
        final d = DateTime.now().difference(start);
        final mm = d.inMinutes.toString().padLeft(2, '0');
        final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
        return '$mm:$ss';
      case CallPhase.ended:
        return _endText(s.endReason);
      case CallPhase.idle:
        return '';
    }
  }

  String _endText(String? reason) {
    switch (reason) {
      case 'DECLINED':
        return 'Call declined';
      case 'NO_ANSWER':
        return 'No answer';
      case 'CANCELLED':
      case 'CALLER_OFFLINE':
        return 'Missed call';
      case 'ANSWERED_ELSEWHERE':
        return 'Answered on another device';
      case 'EMERGENCY_ENDED':
        return 'The emergency has ended. The call was closed.';
      case 'RESPONDER_RELEASED':
        return 'The responder is no longer assigned. The call was closed.';
      case 'CONNECTION_FAILED':
      case 'CONNECTION_LOST':
        return 'Connection lost';
      case 'HANGUP':
      case 'HANGUP_BY_ME':
      case 'CANCELLED_BY_ME':
      case 'DECLINED_BY_ME':
        return 'Call ended';
      case null:
        return 'Call ended';
      default:
        return reason; // server message (e.g. not allowed / busy)
    }
  }

  Widget _buildControls(CallState s) {
    final bottom = MediaQuery.paddingOf(context).bottom + MfSpace.lg;
    if (s.phase == CallPhase.incoming) {
      return Padding(
        padding: EdgeInsets.fromLTRB(MfSpace.xl, 0, MfSpace.xl, bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundAction(icon: Icons.call_end_rounded, label: 'Decline', color: _red, size: 72, onTap: _call.declineIncoming),
            _RoundAction(
              icon: s.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              label: 'Accept',
              color: _green,
              size: 72,
              onTap: () async {
                final error = await _call.acceptIncoming();
                if (error != null && mounted) showMfSnackBar(context, error, tone: MfTone.danger);
              },
            ),
          ],
        ),
      );
    }
    if (s.phase == CallPhase.ended) {
      final phone = s.peer?.phoneNumber;
      final offerPhone = phone != null && const {'NO_ANSWER', 'OFFLINE', 'CONNECTION_FAILED'}.contains(s.endReason);
      return Padding(
        padding: EdgeInsets.fromLTRB(MfSpace.lg, 0, MfSpace.lg, bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (offerPhone) ...[
              _RoundAction(
                icon: Icons.phone_forwarded_rounded,
                label: 'Call on phone',
                color: _green,
                onTap: () => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[\s-]'), ''))),
              ),
              const SizedBox(width: MfSpace.xl),
            ],
            _RoundAction(icon: Icons.close_rounded, label: 'Close', color: Colors.white24, onTap: _call.hangUp),
          ],
        ),
      );
    }
    final connected = s.phase == CallPhase.connected || s.phase == CallPhase.connecting;
    return Container(
      padding: EdgeInsets.fromLTRB(MfSpace.md, MfSpace.lg, MfSpace.md, bottom),
      decoration: s.isVideo
          ? const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundAction(
            icon: s.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: s.muted ? 'Unmute' : 'Mute',
            color: s.muted ? Colors.white : Colors.white24,
            iconColor: s.muted ? _bg : Colors.white,
            onTap: _call.toggleMute,
          ),
          if (s.isVideo) ...[
            _RoundAction(
              icon: s.cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: s.cameraOn ? 'Camera' : 'Camera off',
              color: s.cameraOn ? Colors.white24 : Colors.white,
              iconColor: s.cameraOn ? Colors.white : _bg,
              onTap: _call.toggleCamera,
            ),
            _RoundAction(icon: Icons.cameraswitch_rounded, label: 'Flip', color: Colors.white24, onTap: _call.switchCamera),
          ] else
            _RoundAction(
              icon: s.speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label: 'Speaker',
              color: s.speakerOn ? Colors.white : Colors.white24,
              iconColor: s.speakerOn ? _bg : Colors.white,
              onTap: _call.toggleSpeaker,
            ),
          _RoundAction(
            icon: Icons.call_end_rounded,
            label: connected ? 'End' : 'Cancel',
            color: _red,
            onTap: _call.hangUp,
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconColor = Colors.white,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: size, height: size, child: Icon(icon, color: iconColor, size: size * 0.45)),
            ),
          ),
          const SizedBox(height: MfSpace.xs),
          ExcludeSemantics(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}
