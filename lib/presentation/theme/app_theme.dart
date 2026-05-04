import 'package:flutter/material.dart';
import '../providers/accessibility_provider.dart';

class AppColors {
  // Primary colors — Updated to match logo (#0C637E, #2496A7, #2891C2)
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
  static const Color primaryLight = Color(0xFF2891C2);   // Sky Blue from logo
  static const Color primaryDark = Color(0xFF04364E);    // Deepest logo area
  static const Color secondaryTeal = Color(0xFF2496A7);   // Mid Teal from logo
  static const Color onPrimary = Colors.white;

  // Secondary/Neutral colors — Charcoal
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

  // Status and Accent colors (Emerald/Amber/Red Palette)
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444);   // Red 500

  // Modern Palette
  static const Color background = Color(0xFFF8FAFC); // Very light blue-gray
  static const Color surface = Color(0xFFFFFFFF);
  static const Color glassSurface = Color(0xCCFFFFFF); // For glassmorphism
  
  static const Color onBackground = Color(0xFF0F172A); // Slate 900
  static const Color onSurface = Color(0xFF1E293B);    // Slate 800
  
  static const Color primaryBlue = Color(0xFF2891C2);
  static const Color primaryTeal = Color(0xFF2496A7);
  static const Color primaryNavy = Color(0xFF0C637E);

  // Dark Mode specific
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkOnSurface = Color(0xFFF1F5F9);

  // High Contrast overrides
  static const Color hcBackground = Colors.white;
  static const Color hcSurface = Colors.white;
  static const Color hcOnSurface = Colors.black;
  static const Color hcPrimary = Colors.black;
  static const Color hcOnPrimary = Colors.white;
  static const Color hcAccent = Color(0xFFD32F2F);

  // MediFind Logo Gradient updated to new colors
  static const List<Color> medifindGradient = [
    Color(0xFF0C637E),  // dark navy teal
    Color(0xFF2496A7),  // mid teal
    Color(0xFF2891C2),  // sky blue
  ];
}
class AppShadows {
  // Modern Elevation (Soft Shadows)
  static List<BoxShadow> get softShadow {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        offset: const Offset(0, 4),
        blurRadius: 12,
        spreadRadius: 0,
      ),
    ];
  }

  // Modern Card Shadow
  static List<BoxShadow> get cardShadow {
    return [
      BoxShadow(
        color: const Color(0xFF0C637E).withOpacity(0.08),
        offset: const Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -4,
      ),
    ];
  }

  // ALIASES for compatibility during transition
  static List<BoxShadow> get neumorphicOut => cardShadow;
  static List<BoxShadow> get neumorphicIn => softShadow;

  // Glassmorphism effect shadow
  static List<BoxShadow> get glassShadow {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        offset: const Offset(0, 8),
        blurRadius: 32,
        spreadRadius: 0,
      ),
    ];
  }

  // SOS specific massive shadow
  static List<BoxShadow> get sosMassiveGlow {
    return [
      BoxShadow(
        color: AppColors.error.withOpacity(0.3),
        blurRadius: 40,
        spreadRadius: 8,
      ),
      BoxShadow(
        color: AppColors.error.withOpacity(0.15),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ];
  }
}

class AppTextStyles {
  // Same styles as before, just mapped correctly
  // Display styles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 57,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 45,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 36,
    fontWeight: FontWeight.bold,
  );

  // Headline styles
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  // Title styles
  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Montserrat',
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

class AppTheme {
  static ThemeData buildTheme(AccessibilitySettings settings) {
    final hc = settings.highContrast;
    final bg     = hc ? AppColors.hcBackground : AppColors.background;
    final surf   = hc ? AppColors.hcSurface    : AppColors.surface;
    final onSurf = hc ? AppColors.hcOnSurface  : AppColors.onSurface;
    final prim   = hc ? AppColors.hcPrimary    : AppColors.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary:    prim,
        onPrimary:  hc ? AppColors.hcOnPrimary : Colors.white,
        secondary:  AppColors.secondaryTeal,
        surface:    surf,
        onSurface:  onSurf,
        error:      hc ? AppColors.hcAccent : AppColors.error,
      ),
      scaffoldBackgroundColor: bg,
      fontFamily: 'Montserrat',
      textTheme: _buildTextTheme(settings),

      // ── AppBar ─────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18 * settings.fontSizeMultiplier,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),

      // ── Card ───────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Bottom Navigation ──────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w500, fontSize: 11),
      ),

      // ── Divider ────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 0,
      ),

      // ── Icon ───────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: AppColors.primary),

      // ── Dialog ─────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.onSurface,
        ),
      ),

      // ── Chip ───────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        labelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── ListTile ───────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      elevatedButtonTheme: _buildElevatedButtonTheme(settings, isDark: false),
      inputDecorationTheme: _buildInputDecorationTheme(settings),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(allowEnterRouteSnapshotting: false),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData buildDarkTheme(AccessibilitySettings settings) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        secondary: AppColors.secondaryTeal,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: 'Montserrat',
      textTheme: _buildTextTheme(settings).apply(
        bodyColor: AppColors.darkOnSurface,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: Colors.white.withOpacity(0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w500, fontSize: 11),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08),
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.primaryLight),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(settings, isDark: true),
      inputDecorationTheme: _buildInputDecorationTheme(settings).copyWith(
        fillColor: AppColors.darkSurface,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(AccessibilitySettings settings) {
    const baseTextTheme = Typography.blackMountainView;
    final m = settings.fontSizeMultiplier;

    return baseTextTheme.copyWith(
      displayLarge: AppTextStyles.displayLarge.copyWith(fontSize: 57 * m),
      displayMedium: AppTextStyles.displayMedium.copyWith(fontSize: 45 * m),
      displaySmall: AppTextStyles.displaySmall.copyWith(fontSize: 36 * m),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(fontSize: 32 * m),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(fontSize: 28 * m),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(fontSize: 24 * m),
      titleLarge: AppTextStyles.titleLarge.copyWith(fontSize: 22 * m),
      titleMedium: AppTextStyles.titleMedium.copyWith(fontSize: 16 * m),
      titleSmall: AppTextStyles.titleSmall.copyWith(fontSize: 14 * m),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(fontSize: 16 * m),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(fontSize: 14 * m),
      bodySmall: AppTextStyles.bodySmall.copyWith(fontSize: 12 * m),
    );
  }

  // isDark = true  → renders on a dark scaffold (use sky blue for contrast)
  // isDark = false → renders on a light scaffold (use sky blue; primary navy is too dark)
  static ElevatedButtonThemeData _buildElevatedButtonTheme(
    AccessibilitySettings settings, {
    bool isDark = false,
  }) {
    final Color bgColor = settings.highContrast
        ? Colors.black
        : isDark
            ? AppColors.primaryLight   // #2891C2 Sky Blue on dark background
            : AppColors.primaryLight;  // #2891C2 Sky Blue on light background (primary navy is too dark)

    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.symmetric(
          vertical: settings.largeButtons ? 24 : 16,
          horizontal: 24,
        ),
        textStyle: TextStyle(
          fontSize: 16 * settings.fontSizeMultiplier,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
          letterSpacing: 0.3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(AccessibilitySettings settings) {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: settings.highContrast 
            ? const BorderSide(color: Colors.black, width: 2) 
            : BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: settings.highContrast 
            ? const BorderSide(color: Colors.black, width: 2) 
            : BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: settings.highContrast ? Colors.black : AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      errorStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      labelStyle: const TextStyle(fontSize: 14),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold);
        }
        return const TextStyle(color: AppColors.primary);
      }),
    );
  }
}

