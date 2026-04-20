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

  // Status and Accent colors
  static const Color accent = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);

  // Semantic Neumorphic Background
  static const Color background = Color(0xFFE0E5EC); 
  static const Color surface = Color(0xFFE0E5EC);
  static const Color onBackground = Color(0xFF212121);
  static const Color onSurface = Color(0xFF212121);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // MediFind Logo Gradient updated to new colors
  static const List<Color> medifindGradient = [
    Color(0xFF0C637E),  // dark navy teal
    Color(0xFF2496A7),  // mid teal
    Color(0xFF2891C2),  // sky blue
  ];
}

class AppShadows {
  // Neumorphic Outer Shadow (Pop out)
  static List<BoxShadow> get neumorphicOut {
    return [
      BoxShadow(
        color: Colors.white,
        offset: const Offset(-5, -5),
        blurRadius: 10,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: const Color(0xFFA3B1C6).withOpacity(0.6),
        offset: const Offset(5, 5),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ];
  }

  // Neumorphic Inner Shadow effect approximation (Pressed in)
  // Note: True inner shadows are best achieved with custom painters or Container decorations,
  // but we can use strong inverted shadows inside a clipped container.
  static List<BoxShadow> get neumorphicIn {
    return [
      BoxShadow(
        color: const Color(0xFFA3B1C6).withOpacity(0.8),
        offset: const Offset(2, 2),
        blurRadius: 3,
        spreadRadius: -1,
      ),
      BoxShadow(
        color: Colors.white,
        offset: const Offset(-2, -2),
        blurRadius: 3,
        spreadRadius: -1,
      ),
    ];
  }

  // SOS specific massive shadow
  static List<BoxShadow> get sosMassiveGlow {
    return [
      BoxShadow(
        color: AppColors.error.withOpacity(0.4),
        blurRadius: 30,
        spreadRadius: 5,
        offset: const Offset(5, 5),
      ),
      const BoxShadow(
        color: Colors.white,
        blurRadius: 30,
        spreadRadius: 5,
        offset: Offset(-5, -5),
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
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: settings.highContrast ? Colors.black : AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.background,
        onSurface: settings.highContrast ? Colors.black : AppColors.onSurface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Montserrat',
      textTheme: _buildTextTheme(settings),
      elevatedButtonTheme: _buildElevatedButtonTheme(settings),
      inputDecorationTheme: _buildInputDecorationTheme(settings),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );

    return baseTheme;
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

  static ElevatedButtonThemeData _buildElevatedButtonTheme(AccessibilitySettings settings) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: settings.highContrast ? Colors.black : AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: settings.largeButtons ? 24 : 16,
          horizontal: 24,
        ),
        textStyle: TextStyle(
          fontSize: 16 * settings.fontSizeMultiplier,
          fontWeight: FontWeight.bold,
          fontFamily: 'Montserrat',
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
        borderSide: settings.highContrast ? const BorderSide(color: Colors.black, width: 2) : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: settings.highContrast ? const BorderSide(color: Colors.black, width: 2) : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: settings.highContrast ? Colors.black : AppColors.primary,
          width: 2,
        ),
      ),
    );
  }
}

