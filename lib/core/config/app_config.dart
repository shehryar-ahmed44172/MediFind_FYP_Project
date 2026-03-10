/// App Configuration for development and production environments
class AppConfig {
  /// Set to true for development/layout testing
  /// Set to false for production deployment
  static const bool isDevelopment = true;

  /// Initial route based on environment
  static String get initialRoute {
    return isDevelopment ? '/dev-menu' : '/login';
  }

  /// Enable auth guard based on environment
  static bool get enableAuthGuard {
    return !isDevelopment;
  }

  /// Show debug overlays
  static bool get showDebugBanner {
    return isDevelopment;
  }
}
