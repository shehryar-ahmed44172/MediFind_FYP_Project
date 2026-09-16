import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// MediFind design tokens.
///
/// Spacing follows a 4/8 grid, radii stay within 8–16, elevation is flat
/// (borders instead of heavy shadows) and motion is short and optional.
class MfSpace {
  MfSpace._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Standard horizontal page gutter.
  static const double gutter = 16;
}

class MfRadius {
  MfRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

class MfSize {
  MfSize._();

  /// Minimum touch target everywhere.
  static const double minTouch = 48;

  /// Height of primary call-to-action buttons.
  static const double primaryButton = 56;

  /// Diameter of the patient SOS button.
  static const double sosButton = 208;

  static const double headerHeight = 64;
}

class MfMotion {
  MfMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);

  /// True when the OS asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, [Duration d = normal]) =>
      reduced(context) ? Duration.zero : d;
}

/// Semantic tones used by chips, banners, tiles and buttons.
enum MfTone { primary, neutral, success, warning, danger, info }

/// Resolved foreground / container colors for an [MfTone].
class MfToneColors {
  final Color foreground;
  final Color container;
  final Color border;
  final Color onSolid;
  final Color solid;
  const MfToneColors({
    required this.foreground,
    required this.container,
    required this.border,
    required this.solid,
    required this.onSolid,
  });
}

/// Palette accessors that respect the active theme (dark mode + high contrast).
class MfColors {
  MfColors._();

  /// THE single SOS / destructive red token. In high-contrast mode the theme
  /// swaps in a darker shade of the same red for WCAG contrast.
  static Color sos(BuildContext context) => Theme.of(context).colorScheme.error;

  static Color success(BuildContext context) => AppColors.success;
  static Color warning(BuildContext context) => AppColors.warning;

  static Color textPrimary(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color textSecondary(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
  static Color border(BuildContext context) => Theme.of(context).colorScheme.outlineVariant;

  static bool isHighContrast(BuildContext context) =>
      Theme.of(context).colorScheme.primary == AppColors.hcPrimary;

  static MfToneColors tone(BuildContext context, MfTone tone) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hc = isHighContrast(context);

    Color base;
    switch (tone) {
      case MfTone.primary:
        base = dark ? AppColors.primaryLight : cs.primary;
        break;
      case MfTone.neutral:
        base = cs.onSurfaceVariant;
        break;
      case MfTone.success:
        base = AppColors.success;
        break;
      case MfTone.warning:
        base = AppColors.warning;
        break;
      case MfTone.danger:
        base = cs.error;
        break;
      case MfTone.info:
        base = AppColors.primaryLight;
        break;
    }

    // Amber / emerald text on white is low contrast: darken the text shade
    // for tinted containers, keep the pure token for solid fills and icons.
    Color fg = base;
    if (!dark && (tone == MfTone.warning || tone == MfTone.success)) {
      fg = Color.lerp(base, Colors.black, 0.35)!;
    }
    if (hc && !dark) fg = tone == MfTone.danger ? cs.error : AppColors.hcPrimary;

    return MfToneColors(
      foreground: fg,
      container: tone == MfTone.neutral
          ? cs.surfaceContainerHighest.withValues(alpha: dark ? 0.6 : 0.7)
          : base.withValues(alpha: dark ? 0.18 : 0.10),
      border: hc ? AppColors.hcPrimary : base.withValues(alpha: dark ? 0.45 : 0.30),
      solid: tone == MfTone.neutral ? cs.onSurface : base,
      onSolid: tone == MfTone.warning ? const Color(0xFF1B2632) : Colors.white,
    );
  }
}

extension MfContext on BuildContext {
  ThemeData get mfTheme => Theme.of(this);
  ColorScheme get mfColors => Theme.of(this).colorScheme;
  TextTheme get mfText => Theme.of(this).textTheme;
}
