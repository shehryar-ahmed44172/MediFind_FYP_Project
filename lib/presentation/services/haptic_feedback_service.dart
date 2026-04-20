import 'package:flutter/services.dart';

/// HapticFeedbackService provides specialized tactile feedback patterns
/// to assist users with accessibility needs (e.g., Deaf/Mute users).
class HapticFeedbackService {
  /// A standard light pulse for button taps.
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// A distinct pattern for critical actions like SOS activation.
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// A medium pulse for state changes.
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// An SOS-like pulse pattern (Short-Short-Short Long-Long-Long Short-Short-Short)
  /// Note: Flutter's native [HapticFeedback] is limited to single pulses.
  /// For complex patterns, we'd typically use the 'vibration' package,
  /// but we'll simulate intensity with multiple pulses here.
  static Future<void> sosPattern() async {
    for (int i = 0; i < 3; i++) {
       await HapticFeedback.heavyImpact();
       await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Confirmation pulse (two quick light hits)
  static Future<void> confirmation() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }
}
