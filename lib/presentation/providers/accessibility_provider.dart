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
// Keys are namespaced per user id (`acc_<userId>_<name>`) so one account's
// settings — e.g. DEAF defaults — never leak into another account on the
// same device. Before login a `guest` namespace is used.
const _kVoiceGuidance    = 'voiceGuidance';
const _kTextOnly         = 'textOnly';
const _kLargeButtons     = 'largeButtons';
const _kHighContrast     = 'highContrast';
const _kVibration        = 'vibration';
const _kFontMultiplier   = 'fontMultiplier';
const _kThemeMode        = 'themeMode'; // 0/1=light, 2=dark, 3=system

/// Accessibility Settings Notifier - manages state changes
class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(AccessibilitySettings()) {
    loadForUser(null, null);
  }

  String _namespace = 'guest';
  String? _loadedUserId;
  int _loadGeneration = 0;

  String _key(String name) => 'acc_${_namespace}_$name';

  // ── Persistence helpers ──────────────────────────────────────────────────

  /// Loads the settings saved for [userId]. If this user has never saved any,
  /// role-appropriate defaults are applied (DEAF patients get text-only,
  /// high-contrast, vibration and slightly larger text) and persisted.
  /// Passing null switches back to guest defaults (after logout).
  Future<void> loadForUser(String? userId, String? patientType) async {
    if (userId != null && userId == _loadedUserId) return;
    final generation = ++_loadGeneration;
    _namespace = userId ?? 'guest';
    _loadedUserId = userId;

    final prefs = await SharedPreferences.getInstance();
    if (generation != _loadGeneration) return; // a newer load started

    if (!prefs.containsKey(_key(_kVoiceGuidance))) {
      state = userId == null ? AccessibilitySettings() : _profileDefaults(patientType);
      if (userId != null) await _saveToPrefs();
      return;
    }

    final themeModeIdx = prefs.getInt(_key(_kThemeMode)) ?? 0;
    final themeMode = themeModeIdx == 2
        ? ThemeMode.dark
        : themeModeIdx == 3
            ? ThemeMode.system
            : ThemeMode.light; // default to light

    state = AccessibilitySettings(
      voiceGuidanceEnabled: prefs.getBool(_key(_kVoiceGuidance)) ?? false,
      textOnlyMode:         prefs.getBool(_key(_kTextOnly))      ?? false,
      largeButtons:         prefs.getBool(_key(_kLargeButtons))  ?? false,
      highContrast:         prefs.getBool(_key(_kHighContrast))  ?? false,
      vibrationFeedback:    prefs.getBool(_key(_kVibration))     ?? true,
      fontSizeMultiplier:   (prefs.getDouble(_key(_kFontMultiplier)) ?? 1.0).clamp(1.0, 1.5),
      themeMode:            themeMode,
    );
  }

  AccessibilitySettings _profileDefaults(String? patientType) {
    if ((patientType ?? '').toUpperCase() == 'DEAF') {
      return AccessibilitySettings(
        textOnlyMode: true,
        vibrationFeedback: true,
        highContrast: true,
        fontSizeMultiplier: 1.15,
      );
    }
    return AccessibilitySettings();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_kVoiceGuidance),   state.voiceGuidanceEnabled);
    await prefs.setBool(_key(_kTextOnly),         state.textOnlyMode);
    await prefs.setBool(_key(_kLargeButtons),     state.largeButtons);
    await prefs.setBool(_key(_kHighContrast),     state.highContrast);
    await prefs.setBool(_key(_kVibration),        state.vibrationFeedback);
    await prefs.setDouble(_key(_kFontMultiplier), state.fontSizeMultiplier);
    final themeModeIdx = state.themeMode == ThemeMode.dark
        ? 2
        : state.themeMode == ThemeMode.system
            ? 3
            : 0; // light
    await prefs.setInt(_key(_kThemeMode), themeModeIdx);
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

  /// Update font size multiplier (100%–150%, applied app-wide).
  void setFontSizeMultiplier(double multiplier) {
    final clampedMultiplier = multiplier.clamp(1.0, 1.5);
    state = state.copyWith(fontSizeMultiplier: clampedMultiplier);
    _saveToPrefs();
  }

  /// Update theme mode
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveToPrefs();
  }

  /// Ensures the given user's settings are loaded (safe to call repeatedly).
  void initializeFromUser(String? patientType, [String? userId]) {
    if (userId != null) loadForUser(userId, patientType);
  }

  /// Resets the CURRENT user's settings to their profile defaults.
  void resetToProfileDefaults(String? patientType) {
    state = _profileDefaults(patientType);
    _saveToPrefs();
  }

  /// Force a re-initialization (e.g. settings reset).
  void reinitialize(String? patientType, [String? userId]) {
    resetToProfileDefaults(patientType);
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
      fontSizeMultiplier: fontSize.clamp(1.0, 1.5),
      themeMode: state.themeMode,
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
