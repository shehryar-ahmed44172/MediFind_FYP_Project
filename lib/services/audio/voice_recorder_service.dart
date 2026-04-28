import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class VoiceRecorderService {
  static final VoiceRecorderService _instance = VoiceRecorderService._internal();
  factory VoiceRecorderService() => _instance;
  VoiceRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = p.join(tempDir.path, 'voice_msg_${DateTime.now().millisecondsSinceEpoch}.m4a');
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
