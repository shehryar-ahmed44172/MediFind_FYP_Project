import 'package:flutter/material.dart';

class AppColors {
  // Primary colors — MediFind Logo Teal Gradient
  static const Color primary = Color(0xFF0E9AA7);       // Logo teal (medical cross)
  static const Color primaryLight = Color(0xFF1CBBB4);   // Logo lighter teal (highlights)
  static const Color primaryDark = Color(0xFF0A7E8C);    // Logo darker teal (shadow areas)

  // Secondary colors — Logo charcoal/navy text
  static const Color secondary = Color(0xFF3D4F5F);      // Logo "medifind" text color  
  static const Color secondaryLight = Color(0xFF5A7084);
  static const Color secondaryDark = Color(0xFF2B3A47);

  // Accent colors
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF8A80);
  static const Color accentDark = Color(0xFFE53935);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Semantic colors - NEUMORPHIC BACKGROUND
  static const Color background = Color(0xFFE0E5EC); // Neumorphic base
  static const Color surface = Color(0xFFE0E5EC);
  static const Color surfaceVariant = Color(0xFFD1D9E6);
  static const Color onBackground = Color(0xFF212121);
  static const Color onSurface = Color(0xFF212121);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // MediFind Logo Gradient (for gradient decorations)
  static const List<Color> medifindGradient = [
    Color(0xFF0A7E8C),  // dark teal
    Color(0xFF0E9AA7),  // primary teal
    Color(0xFF1CBBB4),  // light teal
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
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        error: AppColors.error,
        surface: AppColors.surface,
        onBackground: AppColors.onBackground,
        onSurface: AppColors.onSurface,
        onPrimary: AppColors.onPrimary,
        onSecondary: AppColors.onSecondary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background, // Match neumorphic background
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // By removing thick borders, neumorphic inner shadows usually wrap inputs, 
        // we leave invisible borders for the container shadow to do the work.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: AppColors.grey800,
      ),
      scaffoldBackgroundColor: AppColors.grey900,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.grey900,
        elevation: 0,
      ),
    );
  }
}
