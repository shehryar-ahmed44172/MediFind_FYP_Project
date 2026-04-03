/// App Configuration for development and production environments
/// This class centralizes all environment-specific settings for the app.
class AppConfig {
  /// Set to true for development/layout testing
  /// Set to false for production deployment
  // Note: Must be changed to 'false' before releasing the app to real users.
  static const bool isDevelopment = true;

  /// Initial route based on environment
  /// Determines which screen the user sees first when the app launches.
  static String get initialRoute {
    // If in development mode, open the developer menu directly. 
    // Otherwise, direct the user to the login screen.
    return isDevelopment ? '/dev-menu' : '/login';
  }

  /// Enable auth guard based on environment
  /// Used to restrict access to certain pages if the user is not logged in.
  static bool get enableAuthGuard {
    // Disables authentication checks during development for faster testing.
    return !isDevelopment;
  }

  /// Show debug overlays
  /// Controls the visibility of the "DEBUG" banner in the top right corner of the app.
  static bool get showDebugBanner {
    return isDevelopment;
  }
}
