# MediFind - Pending Implementation Guide

**Status Date:** March 10, 2026  
**Purpose:** Detailed instructions for completing all pending functionality from Modules 1-8

---

## 📋 Checklist of Implementation Tasks

### PRIORITY 1: Critical Core Features (MUST HAVE)

#### ✅ Module 2: Medical Profile Management - Backend Integration

**Task 2.1: Medical Profile Persistence**
- [x] Entity created (`domain/entities/medical_profile.dart`)
- [ ] Remote data source implemented (`data/datasources/remote/medical_profile_remote_datasource.dart`)
- [ ] Local data source implemented (`data/datasources/local/medical_profile_local_datasource.dart`)
- [ ] Repository fully implemented (`domain/repositories/medical_profile_repository.dart`)
- [ ] **ACTION NEEDED:** Backend API endpoints:
  - `GET /api/medical-profiles/{userId}` - Retrieve full profile
  - `PUT /api/medical-profiles/{userId}` - Update profile
  - `DELETE /api/medical-profiles/{userId}` - Delete profile
- **Implementation Focus:**
  ```dart
  // Should support:
  - Automatic sync with backend
  - Offline-first local caching with Hive
  - Conflict resolution
  - Lazy loading of profile data
  ```

**Task 2.2: Emergency Attachment of Medical Data**
- [ ] Update `CreateEmergencyUseCase` to attach `MedicalProfile`
- [ ] Modify emergency creation request to include:
  ```json
  {
    "patientId": "uuid",
    "emergencyType": "CARDIAC",
    "latitude": 33.6844,
    "longitude": 73.0479,
    "medicalProfile": {
      "bloodGroup": "O+",
      "allergies": ["Penicillin"],
      "chronicDiseases": ["Diabetes"],
      "medications": ["Metformin"],
      "disabilities": []
    }
  }
  ```
- [ ] Verify backend receives and stores ` medical_profiles` table reference

**Task 2.3: Medical Reports Upload**
- [ ] Create `MedicalReportsRepository` for upload/download
- [ ] Implement file upload to Azure Blob Storage (or S3)
- [ ] Use signed URLs for secure access
- [ ] Update `medical_reports_screen.dart` to:
  ```dart
  // Current state: Uses local _reports list
  // NEW: Should use MedicalReportsRepository
  - Upload to cloud storage
  - Display upload progress
  - Cache file URLs locally
  - Handle offline scenarios
  ```
- [ ] **Backend API needed:**
  - `POST /api/medical-reports/upload` - Upload file
  - `GET /api/medical-reports/{userId}` - List reports
  - `DELETE /api/medical-reports/{reportId}` - Delete report

---

#### ✅ Module 3: Accessibility Integration - Wire to Theme

**Task 3.1: Connect Accessibility Provider to App Theme**
- [x] `AccessibilityProvider` created (`presentation/providers/accessibility_provider.dart`)
- [ ] Wire to `MaterialApp` theme dynamically
- [ ] **ACTION NEEDED:** Update `lib/main.dart` and `app_theme.dart`:
  ```dart
  // In MediFindApp widget:
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final accessibilitySettings = ref.watch(accessibilityProvider);
        final theme = accessibilitySettings.buildTheme();
        
        return MaterialApp.router(
          theme: theme, // Dynamic theme based on accessibility
          // ...
        );
      },
    );
  }
  ```

**Task 3.2: Font Size Multiplier Implementation**
- [ ] Update all Text widgets to use provider multiplier
- [ ] Use mixin or extension: `text.fontSize * accessibilitySettings.fontSizeMultiplier`
- [ ] Test with multipliers: 0.8x, 1.0x, 1.2x, 1.5x, 2.0x

**Task 3.3: Voice Guidance Integration**
- [x] `VoiceAlertService` created (`services/audio/voice_alert_service.dart`)
- [ ] Wire to accessibility provider:
  ```dart
  // When voiceGuidanceEnabled = true:
  - Read screen titles aloud when navigating
  - Announce button actions on focus
  - Read form field labels
  - Announce alert dialogs
  ```

**Task 3.4: High Contrast & Text-Only Mode**
- [ ] Implement color scheme adjustment in `app_theme.dart`
- [ ] Create `HighContrastTheme` extension
- [ ] Update all UI components to respect settings

---

#### ✅ Module 4: SOS Emergency - Verify Implementation

**Task 4.1: Validation**
- [x] Already implemented in `sos_screen.dart`
- [x] 10-second cancellation window implemented in `sos_countdown_screen.dart`
- **VERIFY:**
  - [ ] Medical profile attached to emergency request
  - [ ] GPS location accuracy requirement met
  - [ ] Cancel button only visible to patient (not caregivers)

---

#### ✅ Module 5: Responder Assignment - Complete Logic

**Task 5.1: Nearest Responder Matching**
- [ ] Implement geolocation query:
  ```sql
  -- PostGIS query for nearest responders
  SELECT id, name, current_latitude, current_longitude,
    earth_distance(
      ll_to_earth(current_latitude, current_longitude),
      ll_to_earth(:patient_lat, :patient_lon)
    ) / 1000 as distance_km
  FROM responders
  WHERE is_available = true
  ORDER BY distance_km
  LIMIT 10;
  ```
- [ ] Backend notification endpoint needed:
  - `POST /api/emergency-requests/{emergencyId}/notify-responders`

**Task 5.2: Request Acceptance & Assignment**
- [ ] Implement first-accepted-wins logic:
  ```dart
  // Backend behavior:
  1. Fire emergency_requests to N responders
  2. Listen for first POST /api/emergency-requests/{id}/accept
  3. Update request status to "ACCEPTED"
  4. Broadcast cancellation to other N-1 responders
  5. Create one emergency_tracking record for assigned responder
  ```

**Task 5.3: Escalation Logic**
- [ ] Implement 30-second timeout for acceptance
- [ ] If no acceptance, send to next batch of responders
- [ ] Maximum 3 escalation attempts before SOS expires
- [ ] Backend endpoint: `POST /api/emergencies/{id}/escalate`

---

#### ✅ Module 6: Voice Emergency Alert - CRITICAL

**Task 6.1: Voice Alert Service Integration** ⭐
- [x] Service created (`services/audio/voice_alert_service.dart`)
- [ ] **MUST integrate into responder workflow:**
  ```dart
  // In responder's emergency_request_screen.dart:
  
  // When emergency alert received:
  final voiceService = VoiceAlertService.instance;
  await voiceService.speakEmergencyAlert(emergency);
  
  // Output should include:
  // "EMERGENCY ALERT: CARDIAC EMERGENCY"
  // "Patient: John Doe, Blood Group O+, Allergic to Penicillin"
  // "Chronic disease: Diabetes"
  // "Location: 33.6844, 73.0479"
  // "Distance: 2.5 km, ETA: 5 minutes"
  ```

**Task 6.2: Medical Summary Speech**
- [ ] Implement in responder dashboard:
  ```dart
  // Button: "Read Medical Summary"
  await voiceService.speakMedicalSummary(medicalProfile);
  ```

**Task 6.3: Background Audio**
- [ ] Allow voice playback while driving (don't pause on home button)
- [ ] Implement audio session category: `.playback` with `.duckOthers`

---

#### ✅ Module 7: Live Tracking - Verify Connectivity

**Task 7.1: Real-Time Location Updates**
- [ ] Verify WebSocket subscription:
  ```dart
  // Responder sends location every 5 seconds:
  PUT /api/emergency-tracking/{emergencyId}
  {
    "latitude": 33.6850,
    "longitude": 73.0485,
    "status": "EN_ROUTE"  // or ARRIVED, TREATING, TRANSPORTED
  }
  ```

**Task 7.2: Patient View Updates**
- [ ] Subscribe to tracking via WebSocket:
  ```dart
  // Patient receives:
  {
    "type": "LOCATION_UPDATE",
    "emergencyId": "uuid",
    "responderId": "uuid",
    "latitude": 33.6850,
    "longitude": 73.0485,
    "estimatedArrivalMinutes": 3
  }
  ```

**Task 7.3: Caregiver View Updates**
- [ ] Same subscription as patient
- [ ] Read-only (no action buttons)

---

#### ✅ Module 8: Caregiver Monitoring - Verify Permissions

**Task 8.1: Add Caregiver Workflow**
- [ ] Patient adds caregiver:
  ```dart
  // POST /api/caregivers
  {
    "caregiverId": "uuid",
    "relationship": "PARENT"  // or SIBLING, SPOUSE, FRIEND
  }
  ```

**Task 8.2: Caregiver Notifications**
- [ ] Receive SOS trigger notification
- [ ] Receive real-time location updates
- [ ] **NO permissions for:**
  - Accepting/rejecting responders
  - Modifying assignment
  - Cancelling emergency

---

### PRIORITY 2: Form Validation & Input Sanitization

**Task: Auth Validators**
- [x] Form validators created (`core/utils/validators/auth_validators.dart`)
- [ ] **Implement in screens:**
  - `register_screen.dart` - Validate email, phone, password strength
  - `login_screen.dart` - Validate email/phone format
  - `forgot_password_screen.dart` - Validate email only

**Valid Phone Number Formats:**
```
Pakistan:     +923001234567, 03001234567, 0300-123-4567
International: +1-234-567-8900, +44-20-1234-5678
Minimum:      10 digits, Maximum: 15 digits
```

**Password Requirements:**
```
✓ Minimum 8 characters
✓ At least 1 uppercase letter (A-Z)
✓ At least 1 lowercase letter (a-z)
✓ At least 1 number (0-9)
✓ At least 1 special character (!@#$%^&*)
```

---

### PRIORITY 3: Data Persistence & Offline Support

**Task: Hive Local Storage Setup**
- [ ] Register model adapters in `main.dart`:
  ```dart
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(EmergencyAdapter());
  Hive.registerAdapter(MedicalProfileAdapter());
  ```

**Task: Cache Management**
- [ ] Implement LRU cache eviction
- [ ] Auto-sync when network restored
- [ ] Conflict resolution strategy

---

### PRIORITY 4: Backend Integration Checklist

**REQUIRED Backend Endpoints:**

```
Authentication:
✓ POST   /api/auth/register
✓ POST   /api/auth/login
✓ POST   /api/auth/refresh-token
✓ POST   /api/auth/forgot-password
✓ POST   /api/auth/reset-password

Medical Profile:
✓ GET    /api/medical-profiles/{userId}
✓ PUT    /api/medical-profiles/{userId}
✓ DELETE /api/medical-profiles/{userId}

Emergency:
✓ POST   /api/emergencies
✓ POST   /api/emergencies/{id}/cancel
✓ GET    /api/emergencies/{id}
✓ GET    /api/emergencies?userId={userId}
✓ PUT    /api/emergency-tracking/{emergencyId}

Responder:
✓ GET    /api/responders/nearby-emergencies?lat=&lon=&radius=
✓ POST   /api/emergency-requests/{id}/accept
✓ POST   /api/emergency-requests/{id}/reject
✓ POST   /api/emergencies/{id}/escalate

Medical Reports:
✓ POST   /api/medical-reports/upload
✓ GET    /api/medical-reports/{userId}
✓ DELETE /api/medical-reports/{reportId}

Caregiver:
✓ POST   /api/caregivers
✓ GET    /api/caregivers/my-patients
✓ DELETE /api/caregivers/{id}

WebSocket:
✓ wss://api.medifind.com/ws/notifications
```

---

## 🔧 Implementation Priority Order

### Week 1: Foundation
1. Medical profile persistence (Hive + API)
2. Auth form validators
3. Emergency creation with medical attachment
4. Backend API integration testing

### Week 2: Core Features
5. Voice alert service integration
6. Responder assignment logic
7. Escalation handling
8. Location tracking WebSocket

### Week 3: Polish & Testing
9. Accessibility theme integration
10. Medical reports upload
11. Caregiver UI permissions
12. End-to-end testing

---

## 📝 Code Examples & Templates

### Template: Riverpod Provider with Loading/Error States

```dart
// Usage: ref.watch(medicalProfileProvider(userId))
final medicalProfileProvider = FutureProvider.family<MedicalProfile?, String>(
  (ref, userId) async {
    final repository = ref.watch(medicalProfileRepositoryProvider);
    return repository.getMedicalProfile(userId);
  },
);

// In UI:
ref.watch(medicalProfileProvider('user-id')).when(
  data: (profile) => Text('Profile: ${profile?.bloodGroup}'),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

### Template: Form Validation

```dart
TextFormField(
  decoration: InputDecoration(labelText: 'Email'),
  validator: (value) => AuthValidator.validateEmail(value),
  onSaved: (value) => _email = value,
);
```

### Template: Emergency Creation

```dart
Future<void> createEmergency() async {
  final medicalProfile = await ref.read(
    userMedicalProfileProvider(userId).future,
  );

  final emergency = await ref.read(emergencyNotifierProvider.notifier)
      .createEmergency(
        patientId: userId,
        emergencyType: 'CARDIAC',
        latitude: location.latitude,
        longitude: location.longitude,
        medicalProfile: medicalProfile,
        additionalInfo: 'Severe chest pain',
      );
}
```

---

## ✅ Verification Checklist Before Deployment

- [ ] All form input validates correctly
- [ ] Medical profiles sync with backend
- [ ] Emergency creation includes medical data
- [ ] Voice alerts play on responder notification
- [ ] Accessibility settings affect UI rendering
- [ ] WebSocket connects and receives updates
- [ ] Caregiver can only view (not modify)
- [ ] 10-second SOS cancellation window works
- [ ] Responder assignment escalates after 30s timeout
- [ ] Medical reports upload to cloud storage
- [ ] Offline mode caches data and syncs on restore
- [ ] No sensitive data exposed in logs
- [ ] HIPAA compliance for medical data
- [ ] Battery drain acceptable during tracking
- [ ] App handles network interruptions gracefully

---

**Document Status:** Ready for Implementation  
**Next Action:** Begin with Priority 1 tasks in order of listing
