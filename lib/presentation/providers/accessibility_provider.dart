import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/audio/voice_alert_service.dart';

/// Represents accessibility settings for the entire application
class AccessibilitySettings {
  final bool voiceGuidanceEnabled;
  final bool textOnlyMode;
  final bool largeButtons;
  final bool highContrast;
  final bool vibrationFeedback;
  final double fontSizeMultiplier; // 1.0 = normal, 1.2 = 20% larger, etc.

  AccessibilitySettings({
    this.voiceGuidanceEnabled = false,
    this.textOnlyMode = false,
    this.largeButtons = false,
    this.highContrast = false,
    this.vibrationFeedback = true,
    this.fontSizeMultiplier = 1.0,
  });

  /// Create a copy with modified fields
  AccessibilitySettings copyWith({
    bool? voiceGuidanceEnabled,
    bool? textOnlyMode,
    bool? largeButtons,
    bool? highContrast,
    bool? vibrationFeedback,
    double? fontSizeMultiplier,
  }) {
    return AccessibilitySettings(
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      textOnlyMode: textOnlyMode ?? this.textOnlyMode,
      largeButtons: largeButtons ?? this.largeButtons,
      highContrast: highContrast ?? this.highContrast,
      vibrationFeedback: vibrationFeedback ?? this.vibrationFeedback,
      fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibilitySettings &&
          runtimeType == other.runtimeType &&
          voiceGuidanceEnabled == other.voiceGuidanceEnabled &&
          textOnlyMode == other.textOnlyMode &&
          largeButtons == other.largeButtons &&
          highContrast == other.highContrast &&
          vibrationFeedback == other.vibrationFeedback &&
          fontSizeMultiplier == other.fontSizeMultiplier;

  @override
  int get hashCode =>
      voiceGuidanceEnabled.hashCode ^
      textOnlyMode.hashCode ^
      largeButtons.hashCode ^
      highContrast.hashCode ^
      vibrationFeedback.hashCode ^
      fontSizeMultiplier.hashCode;
}

/// Accessibility Settings Notifier - manages state changes
class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(AccessibilitySettings());

  /// Toggle voice guidance
  void toggleVoiceGuidance() {
    state = state.copyWith(
      voiceGuidanceEnabled: !state.voiceGuidanceEnabled,
    );
  }

  /// Toggle text-only mode
  void toggleTextOnlyMode() {
    state = state.copyWith(
      textOnlyMode: !state.textOnlyMode,
    );
  }

  /// Toggle large buttons
  void toggleLargeButtons() {
    state = state.copyWith(
      largeButtons: !state.largeButtons,
    );
  }

  /// Toggle high contrast
  void toggleHighContrast() {
    state = state.copyWith(
      highContrast: !state.highContrast,
    );
  }

  /// Toggle vibration feedback
  void toggleVibrationFeedback() {
    state = state.copyWith(
      vibrationFeedback: !state.vibrationFeedback,
    );
  }

  /// Update font size multiplier
  void setFontSizeMultiplier(double multiplier) {
    // Clamp between 0.8 (20% smaller) and 1.5 (50% larger)
    final clampedMultiplier = multiplier.clamp(0.8, 1.5);
    state = state.copyWith(
      fontSizeMultiplier: clampedMultiplier,
    );
  }

  /// Reset to defaults
  void resetToDefaults() {
    state = AccessibilitySettings();
  }

  /// Apply all settings at once
  void applySettings(
    bool voiceGuidance,
    bool textOnly,
    bool largeButtons,
    bool highContrast,
    bool vibration,
    double fontSize,
  ) {
    state = AccessibilitySettings(
      voiceGuidanceEnabled: voiceGuidance,
      textOnlyMode: textOnly,
      largeButtons: largeButtons,
      highContrast: highContrast,
      vibrationFeedback: vibration,
      fontSizeMultiplier: fontSize,
    );
  }
}

/// Global accessibility settings provider
final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
  (ref) => AccessibilityNotifier(),
);

/// Provider for voice alert service
final voiceAlertServiceProvider = Provider<VoiceAlertService>((ref) {
  final service = VoiceAlertService();
  service.initialize();
  return service;
});

/// Provider for voice guidance enabled status
final voiceGuidanceEnabledProvider = Provider<bool>((ref) {
  return ref.watch(accessibilityProvider).voiceGuidanceEnabled;
});

/// Provider for text-only mode status
final textOnlyModeProvider = Provider<bool>((ref) {
  return ref.watch(accessibilityProvider).textOnlyMode;
});

/// Provider for large buttons status
final largeButtonsProvider = Provider<bool>((ref) {
  return ref.watch(accessibilityProvider).largeButtons;
});

/// Provider for high contrast status
final highContrastProvider = Provider<bool>((ref) {
  return ref.watch(accessibilityProvider).highContrast;
});

/// Provider for vibration feedback status
final vibrationFeedbackProvider = Provider<bool>((ref) {
  return ref.watch(accessibilityProvider).vibrationFeedback;
});

/// Provider for font size multiplier
final fontSizeMultiplierProvider = Provider<double>((ref) {
  return ref.watch(accessibilityProvider).fontSizeMultiplier;
});
