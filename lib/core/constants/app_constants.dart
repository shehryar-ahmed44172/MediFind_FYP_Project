/// API and app configuration constants
class AppConstants {
  // Environment Flag
  static const bool isDevelopment = true;
  
  // Base URLs (Android Emulator uses 10.0.2.2, iOS uses localhost)
  static const String _devBaseUrl = 'http://192.168.100.86:3000/api/';
  static const String _prodBaseUrl = 'https://api.medifind.com/api/';
  static String get baseUrl => isDevelopment ? _devBaseUrl : _prodBaseUrl;

  // WebSocket & Socket.io Configuration
  static const String _devWsUrl = 'ws://10.0.2.2:3000/';
  static const String _prodWsUrl = 'wss://api.medifind.com/';
  static String get wsUrl => isDevelopment ? _devWsUrl : _prodWsUrl;

  static const String _devSocketUrl = 'http://192.168.100.86:3000/';
  static const String _prodSocketUrl = 'https://api.medifind.com';
  static String get socketUrl => isDevelopment ? _devSocketUrl : _prodSocketUrl;

  static const String apiVersion = 'v1';
  static const int apiTimeout = 60000; // Increased to 60 seconds for local dev
  static const String jwtTokenKey = 'auth_token';
  
  // Database
  static const String databaseName = 'medifind_db';
  static const int databaseVersion = 1;
  
  // Hive Boxes
  static const String userBoxKey = 'users';
  static const String emergencyBoxKey = 'emergencies';
  static const String medicalProfileBoxKey = 'medicalProfiles';
  static const String authBoxKey = 'auth';
  
  // Location
  static const double locationUpdateIntervalSeconds = 10;
  static const double locationAccuracyMeters = 10;
  
  // App Info
  static const String appName = 'MediFind';
  static const String appVersion = '1.0.0';
  
  // Roles
  static const String rolePatient = 'PATIENT';
  static const String roleResponder = 'RESPONDER';
  static const String roleAdmin = 'ADMIN';
  static const String roleCaregiver = 'CAREGIVER';
  
  // Emergency Types
  static const String emergencyTypeCardiac = 'CARDIAC';
  static const String emergencyTypeTrauma = 'TRAUMA';
  static const String emergencyTypeStroke = 'STROKE';
  static const String emergencyTypeShortnessOfBreath = 'SHORTNESS_OF_BREATH';
  static const String emergencyTypeChestPain = 'CHEST_PAIN';
  static const String emergencyTypeOther = 'OTHER';
  
  // Emergency Status
  static const String statusInitiated = 'INITIATED';
  static const String statusInProgress = 'IN_PROGRESS';
  static const String statusResponderAssigned = 'RESPONDER_ASSIGNED';
  static const String statusCompleted = 'COMPLETED';
  static const String statusCancelled = 'CANCELLED';
  
  // Emergency contact related
  static const int maxEmergencyContacts = 5;
  
  // Pagination
  static const int itemsPerPage = 20;
}
