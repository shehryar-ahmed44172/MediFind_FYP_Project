import 'package:flutter_tts/flutter_tts.dart';
import '../../domain/entities/emergency.dart';
import '../../domain/entities/medical_profile.dart';

/// VoiceAlertService handles text-to-speech functionality for emergency alerts.
/// Used primarily by responders to receive voice notifications of emergencies.
class VoiceAlertService {
  static final VoiceAlertService _instance = VoiceAlertService._internal();
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  factory VoiceAlertService() {
    return _instance;
  }

  VoiceAlertService._internal() {
    _flutterTts = FlutterTts();
    _setupTts();
  }

  /// Initialize TTS engine
  void _setupTts() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((message) {
      _isSpeaking = false;
      print('TTS Error: $message');
    });
  }

  /// Check if TTS is initialized
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set language
      await _flutterTts.setLanguage('en-US');

      // Set speech rate (0.0 to 2.0)
      await _flutterTts.setSpeechRate(0.8);

      // Set pitch
      await _flutterTts.setPitch(1.0);

      // Set volume
      await _flutterTts.setVolume(1.0);

      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize TTS: $e');
    }
  }

  /// Speak emergency alert with patient medical summary
  Future<void> speakEmergencyAlert(Emergency emergency) async {
    await initialize();

    try {
      final alertText = _buildEmergencyAlertText(emergency);
      await _flutterTts.speak(alertText);
    } catch (e) {
      print('Failed to speak emergency alert: $e');
    }
  }

  /// Read medical profile summary aloud
  Future<void> speakMedicalSummary(MedicalProfile medical) async {
    await initialize();

    try {
      final summaryText = _buildMedicalSummaryText(medical);
      await _flutterTts.speak(summaryText);
    } catch (e) {
      print('Failed to speak medical summary: $e');
    }
  }

  /// Speak automated situational report for deaf patients
  Future<void> speakAutomatedEmergencyReport({
    required Emergency emergency,
    required MedicalProfile medical,
  }) async {
    await initialize();

    try {
      final typeText = _getEmergencyTypeDescription(emergency.emergencyType);
      final medicalSummary = _buildMedicalSummaryText(medical);
      final additionalInfo = emergency.additionalInfo != null && emergency.additionalInfo!.isNotEmpty
          ? 'Situation details: ${emergency.additionalInfo}. '
          : '';

      final reportText = 'Automated Emergency Report. Patient is deaf and unable to speak. '
          'Condition: $typeText emergency. '
          '$additionalInfo'
          '$medicalSummary. '
          'Repeating once.';

      await _flutterTts.setSpeechRate(0.7); // Slightly slower for clarity
      await _flutterTts.speak(reportText);
    } catch (e) {
      print('Failed to speak automated situational report: $e');
    }
  }

  /// Speak custom message (for responder notifications, etc.)
  Future<void> speakMessage(String message) async {
    await initialize();

    try {
      if (!_isSpeaking) {
        await _flutterTts.speak(message);
      }
    } catch (e) {
      print('Failed to speak message: $e');
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('Failed to stop TTS: $e');
    }
  }

  /// Resume paused speech
  Future<void> resume() async {
    try {
      await _flutterTts.setLanguage('en-US');
    } catch (e) {
      print('Failed to resume TTS: $e');
    }
  }

  /// Pause current speech
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      print('Failed to pause TTS: $e');
    }
  }

  /// Get current speaking status
  bool get isSpeaking => _isSpeaking;

  /// Build emergency alert text from emergency object
  String _buildEmergencyAlertText(Emergency emergency) {
    final typeText = _getEmergencyTypeDescription(emergency.emergencyType);
    final locationText = 'at coordinates ${emergency.latitude.toStringAsFixed(4)}, '
        '${emergency.longitude.toStringAsFixed(4)}';

    final additionalInfo = emergency.additionalInfo != null && emergency.additionalInfo!.isNotEmpty
        ? '. Additional information: ${emergency.additionalInfo}'
        : '';

    return 'Emergency Alert! $typeText emergency $locationText$additionalInfo. '
        'Please report to the location immediately.';
  }

  /// Build medical summary text from medical profile
  String _buildMedicalSummaryText(MedicalProfile medical) {
    final buffer = StringBuffer('Patient Medical Summary. ');

    if (medical.bloodType.isNotEmpty) {
      buffer.write('Blood group: ${medical.bloodType}. ');
    }

    if (medical.allergies.isNotEmpty) {
      buffer.write('Allergies: ${medical.allergies.join(', ')}. ');
    }

    if (medical.chronicDiseases.isNotEmpty) {
      buffer.write('Chronic conditions: ${medical.chronicDiseases.join(', ')}. ');
    }

    if (medical.medications.isNotEmpty) {
      // Assuming medication names are needed
      final medNames = medical.medications.map((m) => m.name).join(', ');
      buffer.write('Current medications: $medNames. ');
    }

    if (medical.disabilityType != null && medical.disabilityType!.isNotEmpty) {
      buffer.write('Disabilities: ${medical.disabilityType}');
    }

    return buffer.toString();
  }

  /// Convert emergency type to readable description
  String _getEmergencyTypeDescription(String emergencyType) {
    switch (emergencyType.toLowerCase()) {
      case 'cardiac':
        return 'Cardiac';
      case 'respiratory':
        return 'Respiratory';
      case 'trauma':
        return 'Trauma';
      case 'stroke':
        return 'Stroke';
      case 'seizure':
        return 'Seizure';
      case 'poisoning':
        return 'Poisoning';
      case 'allergic_reaction':
        return 'Allergic Reaction';
      case 'fall':
        return 'Fall';
      case 'burns':
        return 'Burns';
      case 'other':
      default:
        return 'Medical';
    }
  }

  /// Dispose TTS resources
  Future<void> dispose() async {
    try {
      await _flutterTts.stop();
      _isInitialized = false;
    } catch (e) {
      print('Error disposing TTS: $e');
    }
  }
}
