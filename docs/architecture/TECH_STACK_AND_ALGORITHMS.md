# MediFind - Technology Stack & Algorithms Document

**Version:** 1.0  
**Date:** February 26, 2026  
**Project:** MediFind Healthcare Emergency and Assistance System  
**Status:** Production-Ready Architecture

---

## Table of Contents

1. [Complete Technology Stack](#complete-technology-stack)
2. [Mobile (Flutter) Technologies](#mobile-flutter-technologies)
3. [Backend (ASP.NET) Technologies](#backend-aspnet-technologies)
4. [Core Algorithms](#core-algorithms)
5. [Infrastructure & DevOps](#infrastructure--devops)
6. [Security & Compliance](#security--compliance)
7. [Performance Metrics](#performance-metrics)

---

## Complete Technology Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    MEDIFIND TECH STACK                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐         ┌──────────────────────┐    │
│  │   MOBILE CLIENT      │         │   BACKEND SERVER     │    │
│  │   (Flutter 3.41.2)   │◄───────►│   (ASP.NET Core 8)   │    │
│  └──────────────────────┘         └──────────────────────┘    │
│         │                                    │                 │
│         │ Dio HTTP                          │ REST APIs       │
│         │ WebSocket                         │ SignalR         │
│         │                                   │                 │
│  ┌──────▼──────────────────────────┐   ┌──►┬─────────────────┐│
│  │  LOCAL STORAGE (Mobile)          │   │   │ DATABASE        ││
│  │  ├─ Hive (Object Storage)         │   │   │ └─ PostgreSQL  ││
│  │  ├─ SharedPreferences             │   │   │                ││
│  │  ├─ FlutterSecureStorage          │   │   │                ││
│  │  └─ SQLite (Local DB)             │   │   └─────────────────┘│
│  └───────────────────────────────────┘   │                      │
│                                          │                      │
│  ┌──────────────────────────────────┐   │   ┌────────────────┐ │
│  │  STATE MANAGEMENT (Riverpod)     │   │   │ CACHE LAYER    │ │
│  │  ├─ FutureProvider               │   │   │ ├─ Redis       │ │
│  │  ├─ StateNotifierProvider        │   │   │ └─ In-Memory   │ │
│  │  └─ StreamProvider               │   │   └────────────────┘ │
│  └──────────────────────────────────┘   │                      │
│                                          │                      │
│  ┌──────────────────────────────────┐   │   ┌────────────────┐ │
│  │  SERVICES (Mobile)               │   │   │ MESSAGE QUEUE  │ │
│  │  ├─ Location (Geolocator)        │   │   │ ├─ RabbitMQ    │ │
│  │  ├─ Notifications (WebSocket)    │   │   │ └─ Redis Queue │ │
│  │  ├─ Audio (JustAudio)            │   │   └────────────────┘ │
│  │  └─ Permissions (Handler)        │   │                      │
│  └──────────────────────────────────┘   │                      │
│                                          │                      │
│  ┌──────────────────────────────────┐   │   ┌────────────────┐ │
│  │  UI FRAMEWORKS                   │   │   │ EXTERNAL APIS  │ │
│  │  ├─ Material Design 3            │   │   │ ├─ Google Maps │ │
│  │  ├─ GoRouter (Navigation)        │   │   │ ├─ SMS Service │ │
│  │  └─ Flutter Animations           │   │   │ └─ Email API   │ │
│  └──────────────────────────────────┘   │   └────────────────┘ │
│                                          │                      │
│                                          │   ┌────────────────┐ │
│                                          │   │  LOGGING &     │ │
│                                          │   │  MONITORING    │ │
│                                          │   │ ├─ Application │ │
│                                          │   │ │  Insights    │ │
│                                          │   │ ├─ ELK Stack   │ │
│                                          │   │ └─ Datadog     │ │
│                                          │   └────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Mobile (Flutter) Technologies

### **1. Core Framework**

| Technology | Version | Purpose |
|-----------|---------|---------|
| **Flutter** | 3.41.2 | Cross-platform mobile app development |
| **Dart** | 3.11.0 | Programming language for Flutter |
| **Android SDK** | 36+ | Android platform support |
| **iOS SDK** | 12.0+ | iOS platform support |

### **2. State Management & Reactive Programming**

```dart
// Riverpod 2.6.1 - Reactive State Management
┌──────────────────────────────────────┐
│    RIVERPOD PROVIDERS                │
├──────────────────────────────────────┤
│                                      │
│  FutureProvider                      │
│  ├─ async data fetching              │
│  ├─ API calls                        │
│  └─ automatic caching                │
│                                      │
│  StateNotifierProvider               │
│  ├─ mutable state                    │
│  ├─ user actions                     │
│  └─ state notifications              │
│                                      │
│  StreamProvider                      │
│  ├─ real-time updates                │
│  ├─ WebSocket streams                │
│  └─ location tracking                │
│                                      │
│  ProviderListener                    │
│  └─ react to state changes           │
│                                      │
└──────────────────────────────────────┘

// Example: Emergency Riverpod Provider
final emergencyProvider = StateNotifierProvider<
  EmergencyNotifier, 
  AsyncValue<Emergency>
>((ref) {
  return EmergencyNotifier(ref.watch(emergencyRepositoryProvider));
});
```

**Advantages:**
- ✅ Automatic dependency injection
- ✅ Built-in caching
- ✅ Reactive updates
- ✅ Easy testing
- ✅ Type-safe

### **3. Networking & HTTP**

| Package | Version | Purpose |
|---------|---------|---------|
| **Dio** | 5.3.0 | HTTP client with interceptors |
| **http** | 1.1.0 | Lightweight HTTP requests |
| **web_socket_channel** | 2.4.5 | WebSocket for real-time notifications |

**Dio Features Used:**
```dart
// Request/Response Interceptors
┌────────────────────────────────────┐
│  JWT TOKEN INTERCEPTOR             │
├────────────────────────────────────┤
│ 1. Extract token from storage      │
│ 2. Add to Authorization header     │
│ 3. Refresh if expired              │
│ 4. Retry failed requests           │
└────────────────────────────────────┘

// Error Handling
┌────────────────────────────────────┐
│  ERROR MAPPING                     │
├────────────────────────────────────┤
│ • 401 → Unauthorized (logout)      │
│ • 403 → Forbidden (permissions)    │
│ • 404 → Not Found                  │
│ • 500 → Server Error (retry)       │
│ • Timeout → Network Error (retry)  │
└────────────────────────────────────┘
```

### **4. Local Storage**

| Package | Version | Purpose | Use Case |
|---------|---------|---------|----------|
| **Hive** | 2.2.3 | NoSQL object database | Cache emergencies, user data |
| **SharedPreferences** | 2.2.3 | Key-value storage | App settings, preferences |
| **FlutterSecureStorage** | 9.2.4 | Encrypted storage | JWT tokens, passwords |
| **SQLite** | 2.3.0 | Relational DB | Offline emergency history |

**Storage Architecture:**
```
Device Storage Hierarchy
├── FlutterSecureStorage (Most Secure)
│   └─ JWT Token
│   └─ Refresh Token
│   └─ User Credentials
│
├── Hive Database (Fast, NoSQL)
│   ├─ User object cache
│   ├─ Emergency history
│   ├─ Medical profile
│   └─ Caregiver data
│
├── SharedPreferences (Simple)
│   ├─ User preferences
│   ├─ App settings
│   ├─ Theme selection
│   └─ Language choice
│
└── SQLite (Complex Queries)
    ├─ Offline emergency database
    ├─ Sync queue
    └─ Historical data
```

### **5. Location & Geolocation**

| Package | Version | Purpose |
|---------|---------|---------|
| **Geolocator** | 9.0.2 | GPS location tracking |
| **permission_handler** | 11.4.0 | Runtime permissions |

**Location Features:**
```dart
// Real-time Location Tracking
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Request Location Permission
   └─ OnceOnly / Always allow

2. Start Position Stream
   ├─ Battery optimized
   ├─ Accuracy: 10-50 meters
   └─ Update interval: 5 seconds (emergency) / 30 sec (caregiver)

3. Background Tracking (when needed)
   ├─ Service enabled
   ├─ Battery drain: ~3-5% per hour
   └─ Configurable wake-lock

4. Geofencing (Future)
   ├─ Home location
   ├─ Hospital alerts
   └─ Emergency zone
```

### **6. Push Notifications**

```dart
// Custom WebSocket-based Notification System
┌──────────────────────────────────────┐
│   NOTIFICATION SERVICE (WebSocket)   │
├──────────────────────────────────────┤
│                                      │
│  1. Device Token Generation          │
│     └─ Unique per device             │
│                                      │
│  2. WebSocket Connection             │
│     ├─ wss://api.medifind.com        │
│     ├─ Auto-reconnect (backoff)      │
│     └─ Keep-alive pings              │
│                                      │
│  3. Message Reception                │
│     ├─ Emergency alerts              │
│     ├─ Responder updates             │
│     └─ Admin notifications           │
│                                      │
│  4. Local Notification Display       │
│     ├─ Native Android notification   │
│     ├─ Native iOS notification       │
│     └─ Sound & vibration             │
│                                      │
│  5. Topic Subscription               │
│     ├─ emergency_{id}                │
│     ├─ user_{id}                     │
│     └─ responder_{id}                │
│                                      │
└──────────────────────────────────────┘
```

### **7. UI & Navigation**

| Package | Version | Purpose |
|---------|---------|---------|
| **GoRouter** | 12.1.3 | Type-safe routing & navigation |
| **flutter_svg** | 2.0.11 | SVG image rendering |
| **cached_network_image** | 3.4.0 | Image caching & optimization |
| **image_picker** | 1.1.2 | Photo/camera selection |

**Navigation Structure:**
```dart
// GoRouter - Type-Safe Navigation
┌─────────────────────────────────┐
│    ROUTE CONFIGURATION          │
├─────────────────────────────────┤
│                                 │
│  Functional Routes              │
│  ├─ /login                      │
│  ├─ /register                   │
│  └─ /forgot-password            │
│                                 │
│  Stateful Routes (Bottom Nav)   │
│  ├─ /home                       │
│  ├─ /history                    │
│  ├─ /medical                    │
│  └─ /settings                   │
│                                 │
│  Emergency Routes (Modal)       │
│  ├─ /emergency                  │
│  ├─ /emergency-active           │
│  └─ /emergency-resolved         │
│                                 │
│  Deep Linking Support           │
│  └─ Opens specific screens      │
│     from notifications          │
│                                 │
└─────────────────────────────────┘
```

### **8. Code Generation & Serialization**

| Package | Version | Purpose |
|---------|---------|---------|
| **Freezed** | 2.5.2 | Immutable data classes |
| **json_serializable** | 6.8.0 | JSON serialization |
| **build_runner** | 2.4.13 | Code generation |

**Usage:**
```dart
// Freezed Entity Example
@freezed
class Emergency with _$Emergency {
  const factory Emergency({
    required String id,
    required String userId,
    required EmergencyType type,
    required Location location,
    required EmergencyStatus status,
    String? assignedResponderId,
    @Default([]) List<String> attachmentUrls,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _Emergency;

  factory Emergency.fromJson(Map<String, dynamic> json) =>
      _$EmergencyFromJson(json);
}

// Auto-generates:
// ✓ equality and hashCode
// ✓ toString()
// ✓ copyWith()
// ✓ JSON serialization
```

### **9. Audio & Multimedia**

| Package | Version | Purpose |
|---------|---------|---------|
| **JustAudio** | 0.9.44 | Audio playback (SOS alert) |
| **audio_session** | 0.1.25 | Audio session management |

**Audio Usage:**
```dart
// SOS Emergency Alert
┌────────────────────────────────┐
│  SOS ALERT SYSTEM              │
├────────────────────────────────┤
│                                │
│  1. Trigger SOS Press          │
│     └─ 140px circular button   │
│                                │
│  2. Play Alert Sound           │
│     ├─ 3 short beeps (urgent)  │
│     ├─ Duration: 1.5 seconds   │
│     ├─ Volume: Maximum         │
│     └─ Priority audio focus    │
│                                │
│  3. Vibration Pattern          │
│     ├─ Pattern: [0, 200, 100]  │
│     ├─ Amplitude: 255 (full)   │
│     └─ Repeat: 3 times         │
│                                │
│  4. Lock Screen Alert          │
│     ├─ Bypass mute switch      │
│     ├─ Wake device             │
│     └─ Full brightness screen  │
│                                │
└────────────────────────────────┘
```

### **10. Form Validation**

| Package | Version | Purpose |
|---------|---------|---------|
| **form_builder_validators** | 11.0.1 | Input validation |

**Validation Rules:**
```dart
// Email Validation
├─ Format: RFC 5322 compliant
├─ Max length: 254 characters
└─ Domain must have MX record

// Password Validation
├─ Minimum length: 8 characters
├─ Must contain: Uppercase, Lowercase, Number
├─ Must contain: Special character (!@#$%^&*)
└─ No common passwords (dictionary check)

// Phone Validation
├─ Format: E.164 international format
├─ Length: 10-15 digits
└─ Country code required

// Medical Data Validation
├─ Blood type: A, B, AB, O (with +/-)
├─ Medication name: Non-empty, <200 chars
└─ Allergy reaction: Pre-defined severity levels
```

---

## Backend (ASP.NET) Technologies

### **1. Framework & Runtime**

| Technology | Version | Purpose |
|-----------|---------|---------|
| **.NET** | 8.0 | Runtime framework |
| **ASP.NET Core** | 8.0 | Web API framework |
| **C#** | 12.0 | Programming language |

### **2. Web API & Communication**

```csharp
// ASP.NET Core Web API
┌──────────────────────────────────┐
│  REST API ENDPOINTS              │
├──────────────────────────────────┤
│                                  │
│  Authentication                  │
│  POST /api/auth/login            │
│  POST /api/auth/register         │
│  POST /api/auth/refresh-token    │
│  POST /api/auth/logout           │
│                                  │
│  Emergencies                     │
│  POST /api/emergency/create      │
│  GET  /api/emergency/{id}        │
│  PUT  /api/emergency/{id}/status │
│  GET  /api/emergency/tracking    │
│                                  │
│  Medical Profile                 │
│  GET  /api/medical-profile       │
│  PUT  /api/medical-profile       │
│  POST /api/medical-profile/allergy
│                                  │
│  Responder Operations            │
│  GET  /api/responder/emergencies │
│  PUT  /api/responder/accept      │
│  GET  /api/responder/location    │
│                                  │
└──────────────────────────────────┘

// SignalR Real-time Communication
┌──────────────────────────────────┐
│  SIGNALR HUBS                    │
├──────────────────────────────────┤
│                                  │
│  /hubs/notifications             │
│  ├─ EmergencyCreated             │
│  ├─ ResponderAssigned            │
│  ├─ LocationUpdated              │
│  ├─ EmergencyStatusChanged       │
│  └─ ResponderArrived             │
│                                  │
│  /hubs/dashboard                 │
│  ├─ EmergencyAdded               │
│  ├─ StatisticsUpdated            │
│  └─ DisconnectAlert              │
│                                  │
└──────────────────────────────────┘
```

### **3. Authentication & Authorization**

```csharp
// JWT Token-based Authentication
┌────────────────────────────────────┐
│  JWT TOKEN FLOW                    │
├────────────────────────────────────┤
│                                    │
│  1. Login Request                  │
│     └─ Email + Password via HTTPS  │
│                                    │
│  2. Server Verification            │
│     ├─ Hash password check         │
│     ├─ User status check           │
│     └─ Rate limit check            │
│                                    │
│  3. Token Generation               │
│     ├─ Access Token (15 min)       │
│     ├─ Refresh Token (7 days)      │
│     ├─ Claims: UserId, Role, Email │
│     ├─ Algorithm: HS256            │
│     └─ Signing: Server secret key  │
│                                    │
│  4. Token Storage (Mobile)         │
│     ├─ Access: SecureStorage       │
│     ├─ Refresh: SecureStorage      │
│     └─ In-memory cache             │
│                                    │
│  5. API Request                    │
│     └─ Header: Bearer {token}      │
│                                    │
│  6. Token Validation               │
│     ├─ Signature verification      │
│     ├─ Expiration check            │
│     ├─ Issuer validation           │
│     └─ Audience validation         │
│                                    │
│  7. Refresh Flow                   │
│     ├─ If expired, use refresh     │
│     ├─ Get new access token        │
│     └─ Retry original request      │
│                                    │
└────────────────────────────────────┘

// Role-based Authorization
public enum UserRole
{
    Patient = 1,      // Can create emergencies
    Responder = 2,    // Can accept & respond
    Caregiver = 3,    // Can monitor patient
    Admin = 4         // Full system access
}
```

### **4. Database & ORM**

| Technology | Purpose |
|-----------|---------|
| **Entity Framework Core 8** | ORM for data access |
| **PostgreSQL** | Primary relational database |
| **Entity Framework Migrations** | Database versioning |

**Database Schema:**
```sql
-- Core Tables
┌─────────────────────────────────┐
│  Users Table                    │
├─────────────────────────────────┤
│ • UserId (PK)                   │
│ • Email (Unique, Indexed)       │
│ • PhoneNumber                   │
│ • PasswordHash (Bcrypt)         │
│ • Role (FK → UserRoles)         │
│ • IsActive (Boolean)            │
│ • CreatedAt (UTC)               │
│ • LastLoginAt                   │
│ • ProfilePictureUrl             │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Emergencies Table              │
├─────────────────────────────────┤
│ • EmergencyId (PK)              │
│ • UserId (FK → Users)           │
│ • Type (Enum: ChestPain, etc)   │
│ • Severity (Critical/Moderate)  │
│ • Latitude                      │
│ • Longitude                     │
│ • Status (Active/Resolved)      │
│ • ResponderId (FK → Users)      │
│ • CreatedAt (UTC, Indexed)      │
│ • ResolvedAt                    │
│ • ResolutionNotes (Text)        │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Medical Profiles               │
├─────────────────────────────────┤
│ • ProfileId (PK)                │
│ • UserId (FK → Users, Unique)   │
│ • BloodType                     │
│ • Allergies (JSON)              │
│ • Medications (JSON)            │
│ • ChronicConditions             │
│ • EmergencyContacts (JSON)      │
│ • UpdatedAt (UTC)               │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Responders Table               │
├─────────────────────────────────┤
│ • ResponderId (FK → Users)      │
│ • Certification (License info)  │
│ • Agency (Hospital/Ambulance)   │
│ • CurrentStatus                 │
│ • Latitude                      │
│ • Longitude                     │
│ • LastLocationUpdate            │
│ • IsOnDuty (Boolean)            │
│ • AvailableEmergencies (Ref)    │
└─────────────────────────────────┘
```

### **5. Caching Strategy**

```csharp
// Multi-level Caching
┌─────────────────────────────────┐
│  L1: In-Memory Cache (200ms)    │
│  ├─ User profiles              │
│  ├─ Responder locations        │
│  └─ Active emergencies         │
│                                 │
│  L2: Redis Cache (50ms)         │
│  ├─ Session data               │
│  ├─ Emergency history          │
│  └─ Medical profiles           │
│                                 │
│  L3: Database (100-500ms)       │
│  ├─ Persistent data            │
│  ├─ Audit logs                 │
│  └─ Historical records         │
│                                 │
└─────────────────────────────────┘

// Cache Invalidation Strategy
On Emergency Creation
├─ Invalidate: Active emergencies list
├─ Invalidate: Responder availability
└─ Invalidate: User's emergency count

On Location Update
├─ Update: Responder position cache
└─ Update: Nearest responder list
```

### **6. Message Queue & Asynchronous Processing**

```csharp
// Event-driven Architecture
┌───────────────────────────────────┐
│  MESSAGE QUEUE (RabbitMQ/Redis)   │
├───────────────────────────────────┤
│                                   │
│  Emergency.Created Event          │
│  ├─ Trigger: Notify responders    │
│  ├─ Process: Find nearest         │
│  ├─ Queue: Responder assignments  │
│  └─ Retry: Exponential backoff    │
│                                   │
│  Responder.Accepted Event         │
│  ├─ Notify: Patient               │
│  ├─ Update: GPS tracking          │
│  └─ Alert: Caregiver              │
│                                   │
│  Emergency.Resolved Event         │
│  ├─ Send: Completion summary      │
│  ├─ Store: Audit log              │
│  └─ Trigger: Follow-up survey    │
│                                   │
└───────────────────────────────────┘
```

### **7. Logging & Monitoring**

| Technology | Purpose |
|-----------|---------|
| **Serilog** | Structured logging |
| **Application Insights** | Azure monitoring |
| **ELK Stack** | Log aggregation |

**Logging Levels:**
```csharp
// Log Severity
Critical    → System failure (requires immediate action)
Error       → Exception occurred (error condition)
Warning     → Potential issue (unusual event)
Information → Program flow (milestone events)
Debug       → Development info (detailed debugging)
Trace       → Most detailed (verbose information)

// Emergency Logging Example:
Logger.LogInformation(
    "Emergency created: {EmergencyId}, UserId: {UserId}, Type: {Type}",
    emergencyId, userId, emergencyType);

Logger.LogWarning(
    "No responder found within 5 km for Emergency: {Id}",
    emergencyId);

Logger.LogError(
    ex,
    "Failed to assign responder to Emergency: {Id}",
    emergencyId);
```

---

## Core Algorithms

### **1. Emergency Dispatch Algorithm**

**Nearest Responder Location Algorithm:**

```
ALGORITHM: FindNearestResponder
INPUT: Emergency.Location (Latitude, Longitude)
OUTPUT: Responder with minimum distance

FUNCTION findNearestResponder(emergencyLat, emergencyLon):
    1. Query all available responders (IsOnDuty = true)
    2. For each responder:
        a. Calculate Haversine distance
        b. Check response time (ETA)
        c. Filter out responders > 10 km away
    3. Rank by:
        - Distance (weight: 50%)
        - Speed/vehicle type (weight: 30%)
        - Experience (weight: 20%)
    4. Return top responder
    5. If no responder found:
        - Extend search radius to 20 km
        - Alert admin dashboard
        - Notify next-of-kin

COMPLEXITY:
- Time: O(n) where n = number of responders
- Space: O(n) for sorting
- Optimization: Index responders by location grid
```

**Haversine Distance Formula:**

```
FORMULA: Haversine Distance

Given two points: (lat1, lon1) and (lat2, lon2)

a = sin²(Δφ/2) + cos(φ1)·cos(φ2)·sin²(Δλ/2)
c = 2·atan2(√a, √(1-a))
d = R·c

Where:
- φ is latitude, Δφ is difference
- λ is longitude, Δλ is difference
- R is earth's radius (6,371 km)
- d is distance in kilometers

EXAMPLE (C#):
public double CalculateDistance(double lat1, double lon1, 
                                  double lat2, double lon2)
{
    const double R = 6371; // Earth's radius in km
    
    double dLat = (lat2 - lat1) * Math.PI / 180;
    double dLon = (lon2 - lon1) * Math.PI / 180;
    
    double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
               Math.Cos(lat1 * Math.PI / 180) * 
               Math.Cos(lat2 * Math.PI / 180) *
               Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
    
    double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    return R * c;
}

ACCURACY: ±0.5%
```

### **2. Emergency Severity Classification Algorithm**

```
ALGORITHM: ClassifyEmergencySeverity
INPUT: Emergency type, User medical profile
OUTPUT: Severity level (Critical/Moderate/Minor)

FUNCTION classifyByType(type):
    CRITICAL = {ChestPain, LossOfConsciousness, SevereAllergicReaction}
    MODERATE = {Fall, SevereInjury, SevereHeadache}
    MINOR = {Minor injury, Minor bleeding, Other}

FUNCTION adjustBySeverity(baseSeverity, medicalProfile):
    IF type == AllergyReaction:
        - If critical allergy (anaphylaxis) → CRITICAL
    
    IF baseSeverity == MODERATE:
        - If age > 65 → CRITICAL (elderly risk)
        - If diabetic with chest pain → CRITICAL
        - If history of heart disease → CRITICAL
        - If on blood thinners and bleeding → CRITICAL
    
    IF baseSeverity == MINOR:
        - If diabetic → MODERATE
        - If has cardiac condition → MODERATE

RANKING RESPONDERS by severity:
    CRITICAL → Paramedics + Ambulance (fastest)
    MODERATE → EMT + Ambulance
    MINOR → First responder or local nurse

EXAMPLE:
Input: ChestPain + Age:72 + History:HeartDisease
Output: CRITICAL → Paramedic + Ambulance (ETA: 3 min)
```

### **3. Real-time Location Tracking Algorithm**

```
ALGORITHM: Real-time Location Tracking
UPDATE FREQUENCY based on context:

EMERGENCY ACTIVE:
    - Update interval: 5 seconds
    - Battery priority: Performance
    - Accuracy: High (10-20m)
    
CAREGIVER MONITORING:
    - Update interval: 30 seconds
    - Battery priority: Balanced
    - Accuracy: Medium (30-50m)
    
BACKGROUND (Periodic Check):
    - Update interval: 5 minutes
    - Battery priority: Saving
    - Accuracy: Low (50-100m)

IMPLEMENTATION (Dart/Flutter):
StreamSubscription<Position> positionStream = 
  Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.highAccuracy,
      distanceFilter: 10, // Update if moved 10m
      timeLimit: Duration(seconds: 5),
    ),
  ).listen((Position position) {
    // Send to backend via Dio
    // Update local cache via Hive
    // Notify UI via Riverpod
  });

WEBSOCKET STREAMING:
1. Establish persistent WebSocket connection
2. Send location every update interval
3. Server receives location
4. Server broadcasts to:
   - Assigned responder
   - Caregiver
   - Admin dashboard
5. Other users receive via SignalR
```

### **4. Notification Priority Queue Algorithm**

```
ALGORITHM: NotificationPriorityQueue
PRIORITY LEVEL calculation:

Priority = (BaseType * TypeWeight) + 
           (Urgency * UrgencyWeight) + 
           (Age * AgeWeight)

WHERE:
TypeWeight = {
    EmergencyCreated: 100,
    ResponderAssigned: 85,
    ResponderArrived: 90,
    LocationUpdate: 50,
    MessageReceived: 40,
    StatusUpdate: 30
}

UrgencyWeight = {
    CRITICAL: 100,
    MODERATE: 60,
    MINOR: 20
}

AgeWeight = {
    < 1 second: 100,
    < 30 seconds: 80,
    < 1 minute: 60
}

QUEUE PROCESSING:
┌─────────────────────────────────┐
│  NOTIFICATION QUEUE             │
├─────────────────────────────────┤
│ Priority 1 (100+): Emergency    │
│ Priority 2 (80-99): Urgent      │
│ Priority 3 (50-79): Normal      │
│ Priority 4 (< 50): Background   │
└─────────────────────────────────┘

PROCESSING:
WHILE has_notifications:
    notification = queue.dequeue()  // Get highest priority
    IF user_online:
        send_websocket()             // Real-time
    ELSE:
        send_local_notification()    // Alert
        queue_for_later()            // Retry when online
```

### **5. Responder Availability & Load Balancing**

```
ALGORITHM: ResponderLoadBalancing

ASSIGN responder based on:
1. Distance (Haversine)
2. Current load (active emergencies)
3. Specialization (cardiac, trauma, etc)
4. Response time history
5. Availability status

SCORING FUNCTION:
ResponderScore = 
    (100 - distance_percentage) * 0.4 +
    (100 - load_percentage) * 0.3 +
    specialization_match * 0.2 +
    reliability_rating * 0.1

LOAD TRACKING:
┌────────────────────────────────┐
│  RESPONDER STATE               │
├────────────────────────────────┤
│ AvailableEmergencies: 0-5      │
│ CurrentEmergency: null/active  │
│ LastResponseTime: minutes      │
│ SuccessRate: %                 │
│ PatientRating: 0-5 stars       │
└────────────────────────────────┘

LOAD BALANCING POLICY:
- Max concurrent: 3 emergencies per responder
- If overloaded: reject or queue
- Auto-dispatch: when load drops
- Burnout prevention: max 12 hrs/shift
```

### **6. Emergency History Synchronization Algorithm**

```
ALGORITHM: OfficialDataSync (Offline-First)

OFFLINE STATUS:
1. Create emergency (local: Hive)
2. Store sync status: PENDING
3. Show toast: "Syncing when online"

WHEN ONLINE (DetectConnectivity):
1. Get all PENDING items from Hive
2. FOR EACH pending item:
    a. POST to server via Dio
    b. Handle conflicts:
       - Server has newer: merge/merge strategy
       - Duplicate detected: skip
       - Invalid data: user notified
    c. Update local: status = SYNCED
    d. Remove from sync queue
3. GET latest from server:
    - New emergencies added by other devices
    - Status updates from responders
4. Merge with local (timestamp-based)
5. Store in Hive & SQLite

CONFLICT RESOLUTION:
│ Scenario              │ Resolution            │
├──────────────────────┼────────────────────────┤
│ Local newer          │ Keep local, upload     │
│ Server newer         │ Download & replace     │
│ Both different       │ Manual merge (prompt)  │
│ Duplicate detected   │ Skip, deduplicate      │
│ Data corruption      │ Server version wins    │
```

### **7. Medical Data Encryption Algorithm**

```
ALGORITHM: HIPAA-Compliant Data Encryption

ENCRYPTION STANDARDS:
- Algorithm: AES-256 (Advanced Encryption Standard)
- Mode: GCM (Galois/Counter Mode)
- Key derivation: PBKDF2
- IV/Salt: Generate per encrypted value

PROTECTED DATA:
├─ Medical Profile (Allergies, Medications)
├─ Health History
├─ Emergency Details
├─ Location Data
└─ User PII (Email, Phone, Address)

IMPLEMENTATION:
1. Generate encryption key from user password:
   key = PBKDF2(password, salt, iterations=100000)

2. Encrypt sensitive fields:
   ciphertext = AES256_GCM(plaintext, key, iv)

3. Store: {iv + ciphertext + authTag}

4. Decrypt on retrieval:
   plaintext = AES256_GCM_DECRYPT(ciphertext, key, iv)

5. Audit logging:
   log(timestamp, user_id, action, data_type)

EXAMPLE (C#):
public string EncryptMedicalData(string plaintext, string key)
{
    using (var aes = new AesGcm(Convert.FromBase64String(key)))
    {
        byte[] nonce = new byte[12];
        using (var rng = new RNGCryptoServiceProvider())
            rng.GetBytes(nonce);
        
        byte[] ciphertext = new byte[plaintext.Length];
        byte[] tag = new byte[16];
        
        aes.Encrypt(nonce, 
                   Encoding.UTF8.GetBytes(plaintext),
                   null, ciphertext, tag);
        
        return Convert.ToBase64String(nonce.Concat(ciphertext).Concat(tag));
    }
}
```

---

## Infrastructure & DevOps

### **1. Deployment Architecture**

```
┌─────────────────────────────────────────┐
│        MEDIFIND INFRASTRUCTURE          │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐ │
│  │     Deployment Pipeline (CI/CD)   │ │
│  │                                   │ │
│  │  GitHub Push                      │ │
│  │      ↓                            │ │
│  │  GitHub Actions                   │ │
│  │      ├─ Build                     │ │
│  │      ├─ Test                      │ │
│  │      ├─ Security scan             │ │
│  │      └─ Deploy                    │ │
│  │      ↓                            │ │
│  │  ┌─────────────────────────────┐  │ │
│  │  │   Azure App Service          │  │ │
│  │  │   ASP.NET Running            │  │ │
│  │  │   ├─ Load Balancer           │  │ │
│  │  │   ├─ Auto-scale              │  │ │
│  │  │   └─ Health check            │  │ │
│  │  └─────────────────────────────┘  │ │
│  │      ↓                            │ │
│  │  ┌─────────────────────────────┐  │ │
│  │  │  Database Backend            │  │ │
│  │  │  ├─ PostgreSQL (Primary)     │  │ │
│  │  │  │  ├─ Write Instance        │  │ │
│  │  │  │  └─ Read Replicas         │  │ │
│  │  │  └─ Automated Backups        │  │ │
│  │  └─────────────────────────────┘  │ │
│  │  ┌─────────────────────────────┐  │ │
│  │  │  Caching Layer               │  │ │
│  │  │  └─ Azure Cache for Redis    │  │ │
│  │  └─────────────────────────────┘  │ │
│  │  ┌─────────────────────────────┐  │ │
│  │  │  Message Queue               │  │ │
│  │  │  └─ Azure Service Bus/Redis  │  │ │
│  │  └─────────────────────────────┘  │ │
│  │                                   │ │
│  └───────────────────────────────────┘ │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │     Monitoring & Logging          │ │
│  │                                   │ │
│  │  ├─ Application Insights          │ │
│  │  ├─ Log Analytics Workspace       │ │
│  │  ├─ Alert Rules                   │ │
│  │  └─ Custom Dashboards             │ │
│  │                                   │ │
│  └───────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### **2. Database Backup & Recovery**

```
BACKUP STRATEGY:
├─ Frequency: Every 6 hours
├─ Retention: 30 days full backups
├─ Type: Full + Differential + Transactional
│
├─ AUTOMATED BACKUPS:
│  └─ PostgreSQL: Point-in-time recovery (PITR)
│
├─ MANUAL BACKUP TRIGGERS:
│  ├─ Before major deployment
│  ├─ Before system changes
│  └─ On-demand (admin initiated)
│
└─ RECOVERY:
   ├─ RTO (Recovery Time Objective): 15 minutes
   ├─ RPO (Recovery Point Objective): 1 hour
   └─ Test recovery: Weekly
```

---

## Security & Compliance

### **1. Data Security Standards**

```
┌─────────────────────────────────────────┐
│           SECURITY LAYERS               │
├─────────────────────────────────────────┤
│                                         │
│  LAYER 1: Transport Security            │
│  ├─ HTTPS/TLS 1.3                       │
│  ├─ Certificate pinning                 │
│  └─ Perfect forward secrecy             │
│                                         │
│  LAYER 2: Authentication                │
│  ├─ JWT tokens (HS256)                  │
│  ├─ Refresh token rotation              │
│  └─ MFA (optional)                      │
│                                         │
│  LAYER 3: Authorization                 │
│  ├─ Role-based access control (RBAC)   │
│  ├─ Attribute-based (ABAC)              │
│  └─ Scope-based permissions             │
│                                         │
│  LAYER 4: Data Encryption               │
│  ├─ At-rest: AES-256 (sensitive data)   │
│  ├─ In-transit: TLS 1.3                 │
│  └─ In-memory: Cleared on logout        │
│                                         │
│  LAYER 5: Infrastructure                │
│  ├─ WAF (Web Application Firewall)      │
│  ├─ DDoS protection                     │
│  ├─ Network isolation (VPC)             │
│  └─ Intrusion detection                 │
│                                         │
└─────────────────────────────────────────┘
```

### **2. Compliance Standards**

| Regulation | Implementation |
|-----------|---|
| **HIPAA** | Encryption, audit logs, access control |
| **GDPR** | Data minimization, user consent, right to deletion |
| **CCPA** | Privacy notices, opt-out mechanism |
| **NIST** | Cybersecurity framework, risk assessment |

### **3. Authentication Flow**

```
LOGIN FLOW:
┌──────────────────────────┐
│  1. User enters email    │
│     password (app)       │
├──────────────────────────┤
│  2. POST /auth/login     │
│     (encrypted over TLS) │
├──────────────────────────┤
│  3. Server validates:    │
│     ├─ Email exists      │
│     ├─ Password hash OK  │
│     ├─ Account active    │
│     └─ Rate limit check  │
├──────────────────────────┤
│  4. Generate JWT:        │
│     ├─ Access (15 min)   │
│     ├─ Refresh (7 days)  │
│     └─ Sign with secret  │
├──────────────────────────┤
│  5. Return tokens to app │
├──────────────────────────┤
│  6. App stores securely: │
│     ├─ Access: RAM       │
│     ├─ Refresh: Secure   │
│     └─ Delete on logout  │
├──────────────────────────┤
│  7. API requests include:│
│     Header: "Authorization: │
│     Bearer {access_token}"  │
├──────────────────────────┤
│  8. If token expires:    │
│     └─ POST /auth/refresh│
│        (with refresh)    │
│                          │
└──────────────────────────┘
```

---

## Performance Metrics

### **1. Target Performance Standards**

| Metric | Target | Why |
|--------|--------|-----|
| **Emergency Response Time** | < 3 seconds | Life-critical |
| **API Response Time** | < 200ms | Real-time notifications |
| **Location Update Latency** | < 5 seconds | Responder tracking |
| **Database Query Time** | < 100ms | Data retrieval |
| **App Startup Time** | < 2 seconds | Emergency response |
| **Push Notification Delivery** | < 10 seconds | Alert delivery |

### **2. Optimization Techniques**

```
┌────────────────────────────────────┐
│  PERFORMANCE OPTIMIZATION          │
├────────────────────────────────────┤
│                                    │
│  FRONTEND (Flutter):               │
│  ├─ Image lazy loading             │
│  ├─ Widget build optimization      │
│  ├─ Provider/Riverpod caching      │
│  ├─ Hive local caching             │
│  ├─ Code splitting                 │
│  └─ Async operations               │
│                                    │
│  BACKEND (ASP.NET):                │
│  ├─ Entity Framework lazy loading  │
│  ├─ Query optimization (indexing)  │
│  ├─ Redis caching                  │
│  ├─ Async/await patterns           │
│  ├─ Batch processing               │
│  ├─ Connection pooling             │
│  ├─ Compression (gzip)             │
│  └─ CDN for static assets          │
│                                    │
│  NETWORK:                          │
│  ├─ Request batching               │
│  ├─ Payload optimization           │
│  ├─ HTTP/2 multiplexing            │
│  └─ WebSocket for real-time        │
│                                    │
└────────────────────────────────────┘
```

### **3. Monitoring & Alerts**

```csharp
// Example: Critical Emergency Response Alert
if (emergencyResponseTime > TimeSpan.FromSeconds(3))
{
    logger.LogError("CRITICAL: Emergency response delayed");
    alerting.SendAlert(
        severity: AlertSeverity.Critical,
        message: $"Emergency {emergencyId} took {emergencyResponseTime.TotalSeconds}s",
        recipients: new[] { "oncall-responder", "admin" }
    );
}

// Example: Low Responder Availability
if (availableResponders < 5)
{
    alerting.SendAlert(
        severity: AlertSeverity.High,
        message: $"Only {availableResponders} responders available",
        recipients: new[] { "dispatch-manager" }
    );
}
```

---

## Summary Table

| Layer | Technology | Purpose | Version |
|-------|-----------|---------|---------|
| **Mobile** | Flutter | Cross-platform app | 3.41.2 |
| **State Mgmt** | Riverpod | Reactive state | 2.6.1 |
| **Networking** | Dio | HTTP client | 5.3.0 |
| **Real-time** | WebSocket | Live updates | 2.4.5 |
| **Storage** | Hive | NoSQL database | 2.2.3 |
| **Location** | Geolocator | GPS tracking | 9.0.2 |
| **Backend** | ASP.NET | Web API | 8.0 |
| **Real-time** | SignalR | WebSocket | Built-in |
| **Database** | PostgreSQL | Relational DB | 14.0+ |
| **Cache** | Redis | In-memory cache | 7.0+ |
| **Monitoring** | App Insights | Logging | Azure |

---

**Document Status:** ✅ Complete  
**Last Updated:** February 26, 2026  
**Maintainer:** Development Team  
**Review Cycle:** Quarterly
