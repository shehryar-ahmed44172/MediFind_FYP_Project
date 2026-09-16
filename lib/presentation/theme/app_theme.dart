import 'package:flutter/material.dart';
import '../providers/accessibility_provider.dart';

class AppColors {
  // Primary colors — brand palette from the logo (#0C637E, #2496A7, #2891C2)
  static const MaterialColor primary = MaterialColor(
    0xFF0C637E,
    <int, Color>{
      50: Color(0xFFE2F0F3),
      100: Color(0xFFB7D9E0),
      200: Color(0xFF87C0CD),
      300: Color(0xFF57A6B9),
      400: Color(0xFF3393A9),
      500: Color(0xFF0C637E), // Base Navy-Teal
      600: Color(0xFF0A5B76),
      700: Color(0xFF08516B),
      800: Color(0xFF064761),
      900: Color(0xFF04364E),
    },
  );
  static const Color primaryLight = Color(0xFF2891C2); // Sky Blue
  static const Color primaryDark = Color(0xFF04364E); // Deep
  static const Color secondaryTeal = Color(0xFF2496A7); // Mid Teal
  static const Color primaryPale = Color(0xFFE2F0F3); // Pale
  static const Color onPrimary = Colors.white;

  // Neutral — Charcoal / slate
  static const MaterialColor secondary = MaterialColor(
    0xFF3D4F5F,
    <int, Color>{
      50: Color(0xFFE8EBEE),
      100: Color(0xFFC5CDD3),
      200: Color(0xFF9EAAB7),
      300: Color(0xFF77879A),
      400: Color(0xFF5A6E84),
      500: Color(0xFF3D4F5F),
      600: Color(0xFF374857),
      700: Color(0xFF2F3F4D),
      800: Color(0xFF283643),
      900: Color(0xFF1B2632),
    },
  );
  static const Color charcoal = Color(0xFF3D4F5F);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  /// THE SOS / destructive token. Every SOS red in the app resolves to this
  /// (or to `Theme.of(context).colorScheme.error`, which is this color, with a
  /// darker shade of the same red in high-contrast mode).
  static const Color sos = error;

  /// Kept for backwards compatibility — maps to the SOS token (no extra hue).
  static const Color accent = error;

  // Surfaces
  static const Color background = Color(0xFFF8FAFC); // slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color glassSurface = Color(0xF2FFFFFF);
  static const Color border = Color(0xFFE2E8F0); // slate 200
  static const Color borderStrong = Color(0xFFCBD5E1); // slate 300

  static const Color onBackground = Color(0xFF0F172A); // slate 900
  static const Color onSurface = Color(0xFF1E293B); // slate 800
  static const Color onSurfaceVariant = Color(0xFF64748B); // slate 500

  static const Color primaryBlue = Color(0xFF2891C2);
  static const Color primaryTeal = Color(0xFF2496A7);
  static const Color primaryNavy = Color(0xFF0C637E);

  // Dark mode
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceHigh = Color(0xFF273449);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkOnSurface = Color(0xFFF1F5F9);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);

  // High contrast overrides
  static const Color hcBackground = Colors.white;
  static const Color hcSurface = Colors.white;
  static const Color hcOnSurface = Colors.black;
  // High contrast keeps the brand: deepest navy-teal is ~12:1 on white
  static const Color hcPrimary = AppColors.primaryDark;
  static const Color hcOnPrimary = Colors.white;

  /// High-contrast shade of the SOS token (same hue, WCAG AA on white).
  static const Color hcAccent = Color(0xFFDC2626); // darker SOS red for AA contrast with white text

  /// Brand gradient — reserved for the logo/splash only.
  static const List<Color> medifindGradient = [
    Color(0xFF0C637E),
    Color(0xFF2496A7),
    Color(0xFF2891C2),
  ];
}

/// Flat elevation. Cards use 1px borders; shadows are kept subtle.
class AppShadows {
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          offset: const Offset(0, 2),
          blurRadius: 6,
        ),
      ];

  // ALIASES for compatibility
  static List<BoxShadow> get neumorphicOut => softShadow;
  static List<BoxShadow> get neumorphicIn => softShadow;
  static List<BoxShadow> get glassShadow => cardShadow;

  /// Formerly a large glow; now a restrained shadow.
  static List<BoxShadow> get sosMassiveGlow => [
        BoxShadow(
          color: AppColors.sos.withValues(alpha: 0.18),
          offset: const Offset(0, 4),
          blurRadius: 12,
        ),
      ];
}

class AppTextStyles {
  static const String family = 'Montserrat';

  static const TextStyle displayLarge = TextStyle(fontFamily: family, fontSize: 57, fontWeight: FontWeight.w600, letterSpacing: -0.25, height: 1.12);
  static const TextStyle displayMedium = TextStyle(fontFamily: family, fontSize: 45, fontWeight: FontWeight.w600, height: 1.16);
  static const TextStyle displaySmall = TextStyle(fontFamily: family, fontSize: 36, fontWeight: FontWeight.w600, height: 1.2);

  static const TextStyle headlineLarge = TextStyle(fontFamily: family, fontSize: 30, fontWeight: FontWeight.w600, height: 1.25);
  static const TextStyle headlineMedium = TextStyle(fontFamily: family, fontSize: 26, fontWeight: FontWeight.w600, height: 1.28);
  static const TextStyle headlineSmall = TextStyle(fontFamily: family, fontSize: 22, fontWeight: FontWeight.w600, height: 1.3);

  static const TextStyle titleLarge = TextStyle(fontFamily: family, fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);
  static const TextStyle titleMedium = TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle titleSmall = TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);

  static const TextStyle bodyLarge = TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle bodyMedium = TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45);
  static const TextStyle bodySmall = TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);

  static const TextStyle labelLarge = TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle labelMedium = TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle labelSmall = TextStyle(fontFamily: family, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, height: 1.3);
}

class AppTheme {
  static const double _radius = 12;

  static ThemeData buildTheme(AccessibilitySettings settings) {
    final hc = settings.highContrast;
    final bg = hc ? AppColors.hcBackground : AppColors.background;
    final surf = hc ? AppColors.hcSurface : AppColors.surface;
    final onSurf = hc ? AppColors.hcOnSurface : AppColors.onSurface;
    final onSurfVar = hc ? Colors.black : AppColors.onSurfaceVariant;
    final prim = hc ? AppColors.hcPrimary : AppColors.primary;
    final sos = hc ? AppColors.hcAccent : AppColors.sos;
    final border = hc ? AppColors.primaryDark : AppColors.border;
    final borderStrong = hc ? AppColors.primaryDark : AppColors.borderStrong;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: prim,
      onPrimary: hc ? AppColors.hcOnPrimary : Colors.white,
      primaryContainer: hc ? Colors.white : AppColors.primaryPale,
      onPrimaryContainer: hc ? AppColors.primaryDark : AppColors.primaryDark,
      secondary: hc ? AppColors.primaryDark : AppColors.secondaryTeal,
      onSecondary: Colors.white,
      tertiary: hc ? AppColors.primaryDark : AppColors.primaryLight,
      surface: surf,
      onSurface: onSurf,
      onSurfaceVariant: onSurfVar,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: hc ? Colors.white : const Color(0xFFF8FAFC),
      surfaceContainer: hc ? Colors.white : const Color(0xFFF1F5F9),
      surfaceContainerHigh: hc ? Colors.white : const Color(0xFFEEF2F6),
      surfaceContainerHighest: hc ? Colors.white : const Color(0xFFE2E8F0),
      outline: borderStrong,
      outlineVariant: border,
      error: sos,
      onError: Colors.white,
      errorContainer: sos.withValues(alpha: 0.10),
      onErrorContainer: hc ? Colors.black : const Color(0xFF991B1B),
      surfaceTint: Colors.transparent,
    );

    return _build(
      settings: settings,
      scheme: scheme,
      scaffold: bg,
      borderWidth: hc ? 2 : 1,
    );
  }

  static ThemeData buildDarkTheme(AccessibilitySettings settings) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: AppColors.primaryPale,
      secondary: AppColors.secondaryTeal,
      onSecondary: Colors.white,
      tertiary: AppColors.primaryLight,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: const Color(0xFF172033),
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkSurfaceHigh,
      surfaceContainerHighest: AppColors.darkBorder,
      outline: const Color(0xFF475569),
      outlineVariant: AppColors.darkBorder,
      error: AppColors.sos,
      onError: Colors.white,
      errorContainer: AppColors.sos.withValues(alpha: 0.2),
      onErrorContainer: const Color(0xFFFECACA),
      surfaceTint: Colors.transparent,
    );
    return _build(
      settings: settings,
      scheme: scheme,
      scaffold: AppColors.darkBackground,
      borderWidth: 1,
    );
  }

  static ThemeData _build({
    required AccessibilitySettings settings,
    required ColorScheme scheme,
    required Color scaffold,
    required double borderWidth,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final hc = settings.highContrast && !isDark;
    final textTheme = _buildTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final buttonVertical = settings.largeButtons ? 20.0 : 14.0;
    final borderSide = BorderSide(color: scheme.outlineVariant, width: borderWidth);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius));
    final buttonText = AppTextStyles.labelLarge.copyWith(fontSize: 15);
    // Buttons use navy-teal (#0C637E): white text contrast 6.5:1.
    final buttonBg = hc ? AppColors.primaryDark : (isDark ? AppColors.primaryLight : AppColors.primary);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      fontFamily: AppTextStyles.family,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: scheme.onSurface),
        shape: Border(bottom: borderSide),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: borderSide,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: hc ? AppColors.primaryDark : scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? (hc ? Colors.white : (isDark ? AppColors.primaryLight : AppColors.primary))
                : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.labelMedium.copyWith(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.labelMedium,
        unselectedLabelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w500),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: scheme.onSurface),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceHigh : AppColors.onSurface,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        actionTextColor: AppColors.primaryPale,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: borderSide,
        labelStyle: AppTextStyles.labelLarge.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface),
        subtitleTextStyle: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? buttonBg : scheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.transparent : scheme.outline),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: buttonBg,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: buttonBg,
        dividerColor: scheme.outlineVariant,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w500),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonBg,
        foregroundColor: Colors.white,
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.symmetric(vertical: buttonVertical, horizontal: 20),
          textStyle: buttonText,
          shape: shape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.symmetric(vertical: buttonVertical, horizontal: 20),
          textStyle: buttonText,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: hc ? AppColors.primaryDark : (isDark ? AppColors.primaryLight : AppColors.primary),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.symmetric(vertical: buttonVertical, horizontal: 20),
          side: BorderSide(color: scheme.outline, width: borderWidth),
          textStyle: buttonText,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: hc ? AppColors.primaryDark : (isDark ? AppColors.primaryLight : AppColors.primary),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: buttonText,
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.onSurface,
        ),
      ),

      inputDecorationTheme: _buildInputDecorationTheme(scheme, hc: hc, isDark: isDark),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    // Font scaling is applied app-wide via MediaQuery.textScaler in main.dart.
    return Typography.blackMountainView.copyWith(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(
    ColorScheme scheme, {
    required bool hc,
    required bool isDark,
  }) {
    final normal = BorderSide(color: hc ? AppColors.primaryDark : scheme.outline, width: hc ? 2 : 1);
    final focusColor = hc ? AppColors.primaryDark : (isDark ? AppColors.primaryLight : AppColors.primary);
    OutlineInputBorder b(BorderSide side) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: side,
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: b(normal),
      enabledBorder: b(normal),
      disabledBorder: b(BorderSide(color: scheme.outlineVariant)),
      focusedBorder: b(BorderSide(color: focusColor, width: 2)),
      errorBorder: b(BorderSide(color: scheme.error, width: 1.5)),
      focusedErrorBorder: b(BorderSide(color: scheme.error, width: 2)),
      errorStyle: AppTextStyles.bodySmall.copyWith(color: scheme.error, fontWeight: FontWeight.w500),
      errorMaxLines: 3,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return AppTextStyles.bodyMedium.copyWith(color: focusColor);
        }
        return AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant);
      }),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return AppTextStyles.labelLarge.copyWith(color: scheme.error);
        }
        if (states.contains(WidgetState.focused)) {
          return AppTextStyles.labelLarge.copyWith(color: focusColor);
        }
        return AppTextStyles.labelLarge.copyWith(color: scheme.onSurfaceVariant);
      }),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return focusColor;
        return scheme.onSurfaceVariant;
      }),
      suffixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return focusColor;
        return scheme.onSurfaceVariant;
      }),
    );
  }
}
