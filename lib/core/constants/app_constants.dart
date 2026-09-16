/// API and app configuration constants
class AppConstants {
  // ── Environment Flag ──────────────────────────────────────────────────────
  // true  = use LAN IP or ngrok below (local/university testing)
  // false = use production URLs
  static const bool isDevelopment = true;

  // ── ngrok Flag ────────────────────────────────────────────────────────────
  // true  = use ngrok tunnel URL (works on ANY network — home, Riphah-G, etc.)
  // false = use LAN IP below (requires phone + PC on SAME WiFi)
  //
  // HOW TO USE:
  //   1. Run backend:  npm run dev
  //   2. Run ngrok:    ngrok http 3000
  //   3. Copy the https://xxxx.ngrok-free.app URL into _ngrokHost below
  //   4. Set _useNgrok = true  → build & run app
  static const bool   _useNgrok   = true;
  static const String _ngrokHost  = 'https://wastingly-glariest-gearldine.ngrok-free.dev';

  // ── LAN / Local Testing (same WiFi only) ──────────────────────────────────
  // Windows → CMD → ipconfig → look for "IPv4 Address"
  static const String _lanIp       = '172.17.16.56'; // ← your PC's IPv4
  static const int    _backendPort = 3000;

  // ── Dev URL sets ──────────────────────────────────────────────────────────
  static const String _ngrokBaseUrl   = '$_ngrokHost/api/';
  static const String _ngrokWsUrl     = 'wss://wastingly-glariest-gearldine.ngrok-free.dev/';
  static const String _ngrokSocketUrl = _ngrokHost;

  static const String _lanBaseUrl   = 'http://$_lanIp:$_backendPort/api/';
  static const String _lanWsUrl     = 'ws://$_lanIp:$_backendPort/';
  static const String _lanSocketUrl = 'http://$_lanIp:$_backendPort';

  // ── Production URLs ───────────────────────────────────────────────────────
  static const String _prodBaseUrl   = 'https://api.medifind.com/api/';
  static const String _prodWsUrl     = 'wss://api.medifind.com/';
  static const String _prodSocketUrl = 'https://api.medifind.com';

  static String get baseUrl   => isDevelopment
      ? (_useNgrok ? _ngrokBaseUrl   : _lanBaseUrl)
      : _prodBaseUrl;
  static String get wsUrl     => isDevelopment
      ? (_useNgrok ? _ngrokWsUrl     : _lanWsUrl)
      : _prodWsUrl;
  static String get socketUrl => isDevelopment
      ? (_useNgrok ? _ngrokSocketUrl : _lanSocketUrl)
      : _prodSocketUrl;

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
  
  // Stripe (sandbox/test mode)
  // Get from https://dashboard.stripe.com/test/apikeys → Publishable key
  static const String stripePublishableKey = 'pk_test_51TnGC8RHmdsfec97QXV2OwFGD1szpvIFIOrPtg91J38XtQVnkcaoLINfjXfmHhSuwMB4739s2IkZldsWAkTRe3x000409DqnXO';

  // App Info
  static const String appName = 'MediFind';
  static const String appVersion = '1.0.0';
  
  // Roles
  static const String rolePatient = 'PATIENT';
  static const String roleResponder = 'RESPONDER';
  static const String roleAdmin = 'ADMIN';
  static const String roleCaregiver = 'CAREGIVER';
  
  // Emergency Types (aligned with backend SPECIALIST_MAP; see EmergencyTypes)
  static const String emergencyTypeCardiac = 'CARDIAC';
  static const String emergencyTypeStroke = 'STROKE';
  static const String emergencyTypeShortnessOfBreath = 'SHORTNESS_OF_BREATH';
  static const String emergencyTypeTrauma = 'TRAUMA';
  static const String emergencyTypeFall = 'FALL';
  static const String emergencyTypeSeizure = 'SEIZURE';
  static const String emergencyTypeDiabetic = 'DIABETIC';
  static const String emergencyTypeOther = 'OTHER';
  /// Legacy alias — the app now sends CARDIAC for chest pain.
  static const String emergencyTypeChestPain = 'CHEST_PAIN';

  // Emergency Status (backend values)
  static const String statusActive = 'ACTIVE';
  static const String statusAssigned = 'ASSIGNED';
  static const String statusArrived = 'ARRIVED';
  static const String statusResolved = 'RESOLVED';
  static const String statusCancelled = 'CANCELLED';
  /// Legacy values still seen in older cached data.
  static const String statusInitiated = 'INITIATED';
  static const String statusInProgress = 'IN_PROGRESS';
  static const String statusResponderAssigned = 'RESPONDER_ASSIGNED';
  static const String statusCompleted = 'COMPLETED';
  
  // Emergency contact related
  static const int maxEmergencyContacts = 5;
  
  // Pagination
  static const int itemsPerPage = 20;
}
