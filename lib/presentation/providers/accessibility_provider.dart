import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/audio/voice_alert_service.dart';

/// Represents accessibility settings for the entire application
class AccessibilitySettings {
  final bool voiceGuidanceEnabled;
  final bool textOnlyMode;
  final bool largeButtons;
  final bool highContrast;
  final bool vibrationFeedback;
  final double fontSizeMultiplier; // 1.0 = normal, 1.2 = 20% larger, etc.
  final ThemeMode themeMode;

  AccessibilitySettings({
    this.voiceGuidanceEnabled = false,
    this.textOnlyMode = false,
    this.largeButtons = false,
    this.highContrast = false,
    this.vibrationFeedback = true,
    this.fontSizeMultiplier = 1.0,
    this.themeMode = ThemeMode.light, // Default light — user can change in Settings
  });

  /// Create a copy with modified fields
  AccessibilitySettings copyWith({
    bool? voiceGuidanceEnabled,
    bool? textOnlyMode,
    bool? largeButtons,
    bool? highContrast,
    bool? vibrationFeedback,
    double? fontSizeMultiplier,
    ThemeMode? themeMode,
  }) {
    return AccessibilitySettings(
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      textOnlyMode: textOnlyMode ?? this.textOnlyMode,
      largeButtons: largeButtons ?? this.largeButtons,
      highContrast: highContrast ?? this.highContrast,
      vibrationFeedback: vibrationFeedback ?? this.vibrationFeedback,
      fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
      themeMode: themeMode ?? this.themeMode,
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
          fontSizeMultiplier == other.fontSizeMultiplier &&
          themeMode == other.themeMode;

  @override
  int get hashCode =>
      voiceGuidanceEnabled.hashCode ^
      textOnlyMode.hashCode ^
      largeButtons.hashCode ^
      highContrast.hashCode ^
      vibrationFeedback.hashCode ^
      fontSizeMultiplier.hashCode ^
      themeMode.hashCode;
}

// ── SharedPreferences keys ────────────────────────────────────────────────
const _kVoiceGuidance    = 'acc_voiceGuidance';
const _kTextOnly         = 'acc_textOnly';
const _kLargeButtons     = 'acc_largeButtons';
const _kHighContrast     = 'acc_highContrast';
const _kVibration        = 'acc_vibration';
const _kFontMultiplier   = 'acc_fontMultiplier';
const _kThemeMode        = 'acc_themeMode'; // 0=system, 1=light, 2=dark

/// Accessibility Settings Notifier - manages state changes
class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(AccessibilitySettings()) {
    _loadFromPrefs();
  }

  // ── Persistence helpers ──────────────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Only apply if there are persisted values (first run returns null)
    if (!prefs.containsKey(_kVoiceGuidance)) return;

    // 0=light (default), 1=light, 2=dark, 3=system
    final themeModeIdx = prefs.getInt(_kThemeMode) ?? 0;
    final themeMode = themeModeIdx == 2
        ? ThemeMode.dark
        : themeModeIdx == 3
            ? ThemeMode.system
            : ThemeMode.light; // default to light

    state = AccessibilitySettings(
      voiceGuidanceEnabled: prefs.getBool(_kVoiceGuidance) ?? false,
      textOnlyMode:         prefs.getBool(_kTextOnly)      ?? false,
      largeButtons:         prefs.getBool(_kLargeButtons)  ?? false,
      highContrast:         prefs.getBool(_kHighContrast)  ?? false,
      vibrationFeedback:    prefs.getBool(_kVibration)     ?? true,
      fontSizeMultiplier:   prefs.getDouble(_kFontMultiplier) ?? 1.0,
      themeMode:            themeMode,
    );
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceGuidance,   state.voiceGuidanceEnabled);
    await prefs.setBool(_kTextOnly,         state.textOnlyMode);
    await prefs.setBool(_kLargeButtons,     state.largeButtons);
    await prefs.setBool(_kHighContrast,     state.highContrast);
    await prefs.setBool(_kVibration,        state.vibrationFeedback);
    await prefs.setDouble(_kFontMultiplier, state.fontSizeMultiplier);
    // 0=light, 1=light, 2=dark, 3=system
    final themeModeIdx = state.themeMode == ThemeMode.dark
        ? 2
        : state.themeMode == ThemeMode.system
            ? 3
            : 0; // light
    await prefs.setInt(_kThemeMode, themeModeIdx);
  }

  /// Toggle voice guidance
  void toggleVoiceGuidance() {
    state = state.copyWith(voiceGuidanceEnabled: !state.voiceGuidanceEnabled);
    _saveToPrefs();
  }

  /// Toggle text-only mode
  void toggleTextOnlyMode() {
    state = state.copyWith(textOnlyMode: !state.textOnlyMode);
    _saveToPrefs();
  }

  /// Toggle large buttons
  void toggleLargeButtons() {
    state = state.copyWith(largeButtons: !state.largeButtons);
    _saveToPrefs();
  }

  /// Toggle high contrast
  void toggleHighContrast() {
    state = state.copyWith(highContrast: !state.highContrast);
    _saveToPrefs();
  }

  /// Toggle vibration feedback
  void toggleVibrationFeedback() {
    state = state.copyWith(vibrationFeedback: !state.vibrationFeedback);
    _saveToPrefs();
  }

  /// Update font size multiplier
  void setFontSizeMultiplier(double multiplier) {
    // Clamp between 0.8 (20% smaller) and 1.5 (50% larger)
    final clampedMultiplier = multiplier.clamp(0.8, 1.5);
    state = state.copyWith(fontSizeMultiplier: clampedMultiplier);
    _saveToPrefs();
  }

  /// Update theme mode
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveToPrefs();
  }

  String? _initializedFromUserId;

  /// Initialize based on user patient type
  void initializeFromUser(String? patientType, [String? userId]) {
    // Avoid re-initialization for the same user if already state-synced
    if (userId != null && _initializedFromUserId == userId) return;
    
    final type = patientType?.toUpperCase() ?? 'NORMAL';
    
    if (type == 'DEAF') {
      state = AccessibilitySettings(
        textOnlyMode: true,
        vibrationFeedback: true,
        highContrast: true,
        fontSizeMultiplier: 1.15,
      );
    } else {
      state = AccessibilitySettings();
    }

    _saveToPrefs();

    if (userId != null) {
      _initializedFromUserId = userId;
    }
  }

  /// Force a re-initialization (e.g. settings reset)
  void reinitialize(String? patientType, [String? userId]) {
    _initializedFromUserId = null;
    initializeFromUser(patientType, userId);
  }

  /// Apply all settings at once (existing method preserved)
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
    _saveToPrefs();
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
