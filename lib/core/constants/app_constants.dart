/// API and app configuration constants
class AppConstants {
  // API Configuration
  static const String baseUrl = 'https://api.medifind.com/';
  static const String apiVersion = 'v1';
  static const int apiTimeout = 30000; // 30 seconds
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
