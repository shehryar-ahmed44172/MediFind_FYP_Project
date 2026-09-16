import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Result of asking for microphone access before recording.
enum MicPermissionResult { granted, denied, permanentlyDenied }

class VoiceRecorderService {
  static final VoiceRecorderService _instance = VoiceRecorderService._internal();
  factory VoiceRecorderService() => _instance;
  VoiceRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  /// Requests the microphone permission (shows the system prompt if needed).
  Future<MicPermissionResult> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted || status.isLimited) return MicPermissionResult.granted;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return MicPermissionResult.permanentlyDenied;
      }
      return MicPermissionResult.denied;
    } catch (e) {
      // Fall back to the recorder plugin's own permission check.
      debugPrint('Microphone permission request failed: $e');
      return await _recorder.hasPermission()
          ? MicPermissionResult.granted
          : MicPermissionResult.denied;
    }
  }

  Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}${Platform.pathSeparator}voice_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentPath = path;

        const config = RecordConfig(); // Default config (m4a, 44.1kHz)

        await _recorder.start(config, path: path);
        debugPrint('🎙️ Recording started at: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      debugPrint('🎙️ Recording stopped: $path');
      return path;
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      return _currentPath;
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }
}
