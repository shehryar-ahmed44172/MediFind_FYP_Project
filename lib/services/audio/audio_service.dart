import 'package:just_audio/just_audio.dart';
import '../../core/utils/exceptions.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;

  /// Initialize audio player
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioPlayer = AudioPlayer();
      _isInitialized = true;
    } catch (e) {
      throw AppException(
        message: 'Failed to initialize audio player',
        originalException: e,
      );
    }
  }

  /// Play SOS alert audio
  Future<void> playSosAlert() async {
    if (!_isInitialized) await initialize();

    try {
      // You would load an actual SOS alert sound file here
      // For now, this is a placeholder
      await _audioPlayer.setAsset('assets/sounds/sos_alert.mp3');
      await _audioPlayer.play();
    } catch (e) {
      throw AppException(
        message: 'Failed to play SOS alert',
        originalException: e,
      );
    }
  }

  /// Play notification sound
  Future<void> playNotificationSound() async {
    if (!_isInitialized) await initialize();

    try {
      await _audioPlayer.setAsset('assets/sounds/notification.mp3');
      await _audioPlayer.play();
    } catch (e) {
      throw AppException(
        message: 'Failed to play notification sound',
        originalException: e,
      );
    }
  }

  /// Stop audio playback
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _audioPlayer.stop();
    } catch (e) {
      throw AppException(
        message: 'Failed to stop audio playback',
        originalException: e,
      );
    }
  }

  /// Pause audio playback
  Future<void> pause() async {
    if (!_isInitialized) return;

    try {
      await _audioPlayer.pause();
    } catch (e) {
      throw AppException(
        message: 'Failed to pause audio playback',
        originalException: e,
      );
    }
  }

  /// Resume audio playback
  Future<void> resume() async {
    if (!_isInitialized) return;

    try {
      await _audioPlayer.play();
    } catch (e) {
      throw AppException(
        message: 'Failed to resume audio playback',
        originalException: e,
      );
    }
  }

  /// Get current playback position
  Duration get position => _audioPlayer.position;

  /// Get total duration
  Duration get duration => _audioPlayer.duration ?? Duration.zero;

  /// Check if audio is playing
  bool get isPlaying => _audioPlayer.playing;

  /// Dispose audio player
  Future<void> dispose() async {
    if (_isInitialized) {
      await _audioPlayer.dispose();
      _isInitialized = false;
    }
  }
}
