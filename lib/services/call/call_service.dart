import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../socket/socket_service.dart';

/// In-app voice / video calls (WebRTC).
///
/// Media flows peer-to-peer between the two phones; the MediFind server only relays
/// signalling over Socket.io (`call:*` events) and decides who may call whom
/// (caregiver ↔ patient, and patient/caregiver ↔ the responder of an open emergency;
/// Deaf patients: video only).
enum CallMedia { audio, video }

enum CallPhase { idle, outgoing, incoming, connecting, connected, ended }

class CallPeer {
  final String id;
  final String name;
  final String? imageUrl;
  /// Used for the "Call on phone" fallback when the in-app call cannot connect.
  final String? phoneNumber;

  const CallPeer({required this.id, required this.name, this.imageUrl, this.phoneNumber});
}

@immutable
class CallState {
  final CallPhase phase;
  final CallMedia media;
  final CallPeer? peer;
  final String? callId;
  final bool muted;
  final bool speakerOn;
  final bool cameraOn;
  final DateTime? connectedAt;
  final String? endReason;
  /// Remote video is available.
  final bool hasRemoteVideo;

  const CallState({
    this.phase = CallPhase.idle,
    this.media = CallMedia.audio,
    this.peer,
    this.callId,
    this.muted = false,
    this.speakerOn = false,
    this.cameraOn = true,
    this.connectedAt,
    this.endReason,
    this.hasRemoteVideo = false,
  });

  bool get isVideo => media == CallMedia.video;
  bool get isActive => phase != CallPhase.idle && phase != CallPhase.ended;

  CallState copyWith({
    CallPhase? phase,
    CallMedia? media,
    CallPeer? peer,
    String? callId,
    bool? muted,
    bool? speakerOn,
    bool? cameraOn,
    DateTime? connectedAt,
    String? endReason,
    bool? hasRemoteVideo,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        media: media ?? this.media,
        peer: peer ?? this.peer,
        callId: callId ?? this.callId,
        muted: muted ?? this.muted,
        speakerOn: speakerOn ?? this.speakerOn,
        cameraOn: cameraOn ?? this.cameraOn,
        connectedAt: connectedAt ?? this.connectedAt,
        endReason: endReason ?? this.endReason,
        hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
      );
}

class CallService {
  CallService._();
  static final CallService instance = CallService._();

  static const String callRoute = '/call';

  final ValueNotifier<CallState> state = ValueNotifier(const CallState());
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  Dio? _dio;
  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<({String event, Map<String, dynamic> data})>? _eventsSub;
  bool _renderersReady = false;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _pendingCandidates = [];
  /// Signals that arrive while the camera/microphone are still starting.
  final List<Map<String, dynamic>> _earlySignals = [];
  bool _remoteDescriptionSet = false;
  List<Map<String, dynamic>>? _iceServers;

  final AudioPlayer _tone = AudioPlayer();
  Timer? _vibrationTimer;
  Timer? _resetTimer;
  Timer? _connectTimeout;

  CallState get _s => state.value;
  void _set(CallState next) => state.value = next;

  /// Call once at app start (after the router exists).
  void init({required Dio dio, required GlobalKey<NavigatorState> navigatorKey}) {
    _dio = dio;
    _navigatorKey = navigatorKey;
    _eventsSub ??= SocketService.instance.callEvents.listen(_onEvent);
    _initWebRtc();
  }

  Future<void>? _webRtcReady;

  /// Audio settings that WebRTC only reads when it first starts, so they must be
  /// applied before any call or renderer: voice-call audio path, and WebRTC's own
  /// (software) echo cancellation + noise suppression instead of the phone's
  /// hardware ones, which distort voice on many budget phones (e.g. Infinix).
  Future<void> _initWebRtc() => _webRtcReady ??= () async {
        if (kIsWeb) return;
        try {
          await WebRTC.initialize(options: {
            if (Platform.isAndroid) 'androidAudioConfiguration': AndroidAudioConfiguration.communication.toMap(),
            'androidUseHardwareAudioProcessing': false,
          });
        } catch (e) {
          debugPrint('[Call] WebRTC initialize failed: $e');
        }
      }();

  Future<void> _ensureRenderers() async {
    await _initWebRtc();
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  // ── Outgoing ──────────────────────────────────────────────────────────────

  /// Starts a call. Returns null on success, otherwise a message for the user.
  Future<String?> startCall(CallPeer peer, CallMedia media) async {
    if (_s.isActive) return 'You are already in a call.';
    final permissionError = await _requestPermissions(media);
    if (permissionError != null) return permissionError;
    await _ensureRenderers();

    _resetTimer?.cancel();
    _set(CallState(
      phase: CallPhase.outgoing,
      media: media,
      peer: peer,
      speakerOn: media == CallMedia.video,
    ));
    _openCallScreen();
    await _startLocalMedia(media);

    final ack = await SocketService.instance.emitWithAck('call:invite', {
      'toUserId': peer.id,
      'media': media.name,
    });
    if (ack['ok'] != true) {
      final message = ack['message']?.toString() ?? 'The call could not be started.';
      _finish(ack['code']?.toString() == 'OFFLINE' ? 'OFFLINE' : 'FAILED', message: message);
      return message;
    }
    _set(_s.copyWith(callId: ack['callId']?.toString()));
    _playTone('assets/sounds/call_ringback.wav');
    return null;
  }

  // ── Incoming ──────────────────────────────────────────────────────────────

  Future<String?> acceptIncoming() async {
    final callId = _s.callId;
    if (_s.phase != CallPhase.incoming || callId == null) return null;
    final permissionError = await _requestPermissions(_s.media);
    if (permissionError != null) {
      declineIncoming();
      return permissionError;
    }
    _stopAlerting();
    await _ensureRenderers();
    final ack = await SocketService.instance.emitWithAck('call:accept', {'callId': callId});
    if (ack['ok'] != true) {
      _finish('GONE', message: ack['message']?.toString() ?? 'This call is no longer available.');
      return ack['message']?.toString();
    }
    _set(_s.copyWith(phase: CallPhase.connecting));
    await _startLocalMedia(_s.media);
    await _createPeerConnection();
    _startConnectTimeout();
    // The caller sends the offer next (call:signal).
    return null;
  }

  void declineIncoming() {
    final callId = _s.callId;
    if (callId != null) SocketService.instance.emit('call:decline', {'callId': callId});
    _finish('DECLINED_BY_ME');
  }

  /// Hang up / cancel, whatever the current phase.
  void hangUp() {
    final callId = _s.callId;
    switch (_s.phase) {
      case CallPhase.outgoing:
        if (callId != null) SocketService.instance.emit('call:cancel', {'callId': callId});
        _finish('CANCELLED_BY_ME');
        break;
      case CallPhase.incoming:
        declineIncoming();
        break;
      case CallPhase.connecting:
      case CallPhase.connected:
        if (callId != null) SocketService.instance.emit('call:end', {'callId': callId});
        _finish('HANGUP_BY_ME');
        break;
      case CallPhase.idle:
      case CallPhase.ended:
        _resetNow();
        break;
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void toggleMute() {
    final muted = !_s.muted;
    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    _set(_s.copyWith(muted: muted));
  }

  Future<void> toggleSpeaker() async {
    final on = !_s.speakerOn;
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (e) {
      debugPrint('[Call] speaker toggle failed: $e');
    }
    _set(_s.copyWith(speakerOn: on));
  }

  void toggleCamera() {
    final on = !_s.cameraOn;
    for (final track in _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = on;
    }
    _set(_s.copyWith(cameraOn: on));
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (e) {
      debugPrint('[Call] switch camera failed: $e');
    }
  }

  // ── Signalling events ─────────────────────────────────────────────────────

  Future<void> _onEvent(({String event, Map<String, dynamic> data}) e) async {
    final data = e.data;
    final callId = data['callId']?.toString();
    switch (e.event) {
      case 'call:incoming':
        if (_s.isActive) return; // server already refuses calls to busy users
        final from = data['from'] is Map ? Map<String, dynamic>.from(data['from'] as Map) : const <String, dynamic>{};
        _resetTimer?.cancel();
        _set(CallState(
          phase: CallPhase.incoming,
          media: data['media'] == 'video' ? CallMedia.video : CallMedia.audio,
          callId: callId,
          speakerOn: data['media'] == 'video',
          peer: CallPeer(
            id: from['id']?.toString() ?? '',
            name: from['fullName']?.toString() ?? 'MediFind user',
            imageUrl: from['profileImageUrl']?.toString(),
          ),
        ));
        _startAlerting();
        _openCallScreen();
        break;

      case 'call:accepted':
        if (callId != _s.callId || _s.phase != CallPhase.outgoing) return;
        _stopAlerting();
        _set(_s.copyWith(phase: CallPhase.connecting));
        await _createPeerConnection();
        _startConnectTimeout();
        final offer = await _pc!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': _s.isVideo,
        });
        await _pc!.setLocalDescription(offer);
        _sendSignal({'type': 'offer', 'sdp': offer.sdp});
        break;

      case 'call:signal':
        if (callId != _s.callId) return;
        final signal = data['signal'] is Map ? Map<String, dynamic>.from(data['signal'] as Map) : null;
        if (signal == null) return;
        if (_pc == null) {
          _earlySignals.add(signal); // peer connection is still being created
          return;
        }
        await _handleSignal(signal);
        break;

      case 'call:declined':
        if (callId == _s.callId) _finish('DECLINED');
        break;
      case 'call:cancelled':
        if (callId == _s.callId) _finish(data['reason']?.toString() == 'ANSWERED_ELSEWHERE' ? 'ANSWERED_ELSEWHERE' : 'CANCELLED');
        break;
      case 'call:missed':
        if (callId == _s.callId) _finish(_s.phase == CallPhase.incoming ? 'MISSED' : 'NO_ANSWER');
        break;
      case 'call:ended':
        if (callId == _s.callId) _finish(data['reason']?.toString() ?? 'HANGUP');
        break;
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> signal) async {
    final pc = _pc;
    if (pc == null) return;
    try {
      switch (signal['type']) {
        case 'offer':
          await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'] as String?, 'offer'));
          _remoteDescriptionSet = true;
          await _flushCandidates();
          final answer = await pc.createAnswer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': _s.isVideo,
          });
          await pc.setLocalDescription(answer);
          _sendSignal({'type': 'answer', 'sdp': answer.sdp});
          break;
        case 'answer':
          await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'] as String?, 'answer'));
          _remoteDescriptionSet = true;
          await _flushCandidates();
          break;
        case 'candidate':
          final candidate = RTCIceCandidate(
            signal['candidate'] as String?,
            signal['sdpMid'] as String?,
            (signal['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (_remoteDescriptionSet) {
            await pc.addCandidate(candidate);
          } else {
            _pendingCandidates.add(candidate);
          }
          break;
      }
    } catch (e) {
      debugPrint('[Call] signal ${signal['type']} failed: $e');
    }
  }

  Future<void> _flushCandidates() async {
    final pc = _pc;
    if (pc == null) return;
    for (final c in List.of(_pendingCandidates)) {
      await pc.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  void _sendSignal(Map<String, dynamic> signal) {
    final callId = _s.callId;
    if (callId != null) SocketService.instance.emit('call:signal', {'callId': callId, 'signal': signal});
  }

  // ── WebRTC plumbing ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _loadIceServers() async {
    final cached = _iceServers;
    if (cached != null) return cached;
    try {
      final response = await _dio!.get('calls/ice-servers');
      final list = (response.data['data']?['iceServers'] as List?) ?? const [];
      _iceServers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[Call] ICE servers unavailable, using public STUN: $e');
      _iceServers = [
        {'urls': ['stun:stun.l.google.com:19302']},
      ];
    }
    return _iceServers!;
  }

  Future<void> _startLocalMedia(CallMedia media) async {
    if (_localStream != null) return;
    await _initWebRtc();
    try {
      // Voice-call audio mode: turns on the phone's hardware echo canceller and
      // noise suppressor and routes audio like a normal phone call.
      if (!kIsWeb && Platform.isAndroid) {
        await Helper.setAndroidAudioConfiguration(AndroidAudioConfiguration.communication);
      }
      final stream = await navigator.mediaDevices.getUserMedia({
        // Android's WebRTC only reads 'mandatory'/'optional' audio constraints; plain
        // keys like {'echoCancellation': true} were ignored, so calls had no echo
        // cancellation or noise suppression at all.
        'audio': {
          'mandatory': {
            'googEchoCancellation': 'true',
            'googEchoCancellation2': 'true',
            'googDAEchoCancellation': 'true',
            'googNoiseSuppression': 'true',
            'googNoiseSuppression2': 'true',
            'googAutoGainControl': 'true',
            'googHighpassFilter': 'true',
            'googTypingNoiseDetection': 'true',
          },
          'optional': [],
        },
        'video': media == CallMedia.video
            ? {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 24}
            : false,
      });
      _localStream = stream;
      localRenderer.srcObject = stream;
      if (media == CallMedia.video) {
        await Helper.setSpeakerphoneOn(true);
      }
    } catch (e) {
      debugPrint('[Call] getUserMedia failed: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    if (_pc != null) return;
    await _initWebRtc();
    final pc = await createPeerConnection({
      'iceServers': await _loadIceServers(),
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
      }
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _sendSignal({
        'type': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onTrack = (event) {
      debugPrint('[Call] remote track: ${event.track.kind} streams=${event.streams.length}');
      if (event.streams.isEmpty) return;
      remoteRenderer.srcObject = event.streams.first;
      if (event.track.kind == 'video') _set(_s.copyWith(hasRemoteVideo: true));
    };
    // Some Android builds report the connection through the ICE state only
    pc.onIceConnectionState = (iceState) {
      debugPrint('[Call] ice state: $iceState');
      if (iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _markConnected();
      }
    };
    pc.onConnectionState = (connectionState) {
      debugPrint('[Call] connection state: $connectionState');
      switch (connectionState) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _markConnected();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          final callId = _s.callId;
          if (callId != null) SocketService.instance.emit('call:end', {'callId': callId});
          _finish('CONNECTION_FAILED');
          break;
        default:
          break;
      }
    };

    // Signals that arrived while the camera was starting, now that every listener is attached
    final early = List.of(_earlySignals);
    _earlySignals.clear();
    for (final signal in early) {
      await _handleSignal(signal);
    }
  }

  void _markConnected() {
    _connectTimeout?.cancel();
    if (_s.phase == CallPhase.connecting) {
      _set(_s.copyWith(phase: CallPhase.connected, connectedAt: DateTime.now()));
      HapticFeedback.mediumImpact();
    }
  }

  Timer? _statePoll;

  void _startConnectTimeout() {
    // Some devices do not deliver the connection-state event: poll it as a fallback
    _statePoll?.cancel();
    _statePoll = Timer.periodic(const Duration(seconds: 1), (t) async {
      final pc = _pc;
      if (pc == null || _s.phase != CallPhase.connecting) {
        t.cancel();
        return;
      }
      final ice = await pc.getIceConnectionState();
      final conn = await pc.getConnectionState();
      if (ice == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          ice == RTCIceConnectionState.RTCIceConnectionStateCompleted ||
          conn == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('[Call] connected (polled: ice=$ice conn=$conn)');
        _markConnected();
        t.cancel();
      }
    });
    _connectTimeout?.cancel();
    _connectTimeout = Timer(const Duration(seconds: 30), () {
      if (_s.phase == CallPhase.connecting) {
        final callId = _s.callId;
        if (callId != null) SocketService.instance.emit('call:end', {'callId': callId});
        _finish('CONNECTION_FAILED');
      }
    });
  }

  // ── Ringing ───────────────────────────────────────────────────────────────

  void _startAlerting() {
    _playTone('assets/sounds/call_ringtone.wav');
    _vibrationTimer?.cancel();
    HapticFeedback.heavyImpact();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => HapticFeedback.heavyImpact());
  }

  void _stopAlerting() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _tone.stop();
  }

  Future<void> _playTone(String asset) async {
    try {
      await _tone.setAsset(asset);
      await _tone.setLoopMode(LoopMode.one);
      _tone.play();
    } catch (e) {
      debugPrint('[Call] tone failed: $e');
    }
  }

  // ── Teardown ──────────────────────────────────────────────────────────────

  void _finish(String reason, {String? message}) {
    _stopAlerting();
    _connectTimeout?.cancel();
    _statePoll?.cancel();
    final pc = _pc;
    _pc = null;
    pc?.close();
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      stream.dispose();
    }
    if (_renderersReady) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    // Back to normal media audio for the rest of the app (videos, alert sounds)
    if (!kIsWeb && Platform.isAndroid) {
      Helper.setAndroidAudioConfiguration(AndroidAudioConfiguration.media).catchError((_) {});
    }
    _pendingCandidates.clear();
    _earlySignals.clear();
    _remoteDescriptionSet = false;
    _set(_s.copyWith(phase: CallPhase.ended, endReason: message ?? reason));
    // Leave the result on screen briefly (longer when a phone fallback is offered)
    final offerPhone = const {'NO_ANSWER', 'OFFLINE', 'CONNECTION_FAILED'}.contains(reason) && _s.peer?.phoneNumber != null;
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(milliseconds: offerPhone ? 8000 : 1800), _resetNow);
  }

  void _resetNow() {
    _resetTimer?.cancel();
    _set(const CallState());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _requestPermissions(CallMedia media) async {
    final permissions = [Permission.microphone, if (media == CallMedia.video) Permission.camera];
    final results = await permissions.request();
    if (results.values.any((s) => !s.isGranted)) {
      return media == CallMedia.video
          ? 'Camera and microphone permission are needed for video calls.'
          : 'Microphone permission is needed for calls.';
    }
    return null;
  }

  void _openCallScreen() {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    final router = GoRouter.of(context);
    if (router.routerDelegate.currentConfiguration.uri.path == callRoute) return;
    router.push(callRoute);
  }
}
