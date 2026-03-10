# Use Case 2: SOS Emergency Trigger

## Overview
Patient initiates emergency assistance by triggering SOS. System captures location, generates voice alert, retrieves medical profile, and notifies nearby responders.

---

## Use Case Diagram

```
┌─────────────────────────────────────────────────────┐
│         SOS Emergency Trigger                        │
├─────────────────────────────────────────────────────┤
│                                                      │
│    ┌─────────────────────────────────────────┐     │
│    │ Patient in Emergency Situation           │     │
│    │ • Falls, chest pain, accident, etc.      │     │
│    └──────────────────┬──────────────────────┘     │
│                       │                             │
│                       ▼                             │
│    ┌─────────────────────────────────────────┐     │
│    │ TAP SOS BUTTON (or voice command)        │     │
│    │ "Emergency, Emergency!"                  │     │
│    └──────────────────┬──────────────────────┘     │
│                       │                             │
│          ┌────────────┴───────────────┐             │
│          │ System Actions:            │             │
│          │ 1. Verify authentication   │             │
│          │ 2. Request GPS location ◄──┼─ Async     │
│          │ 3. Retrieve medical data ◄─┼─ Async     │
│          │ 4. Generate voice alert ◄──┼─ Async     │
│          │ 5. Create emergency record  │             │
│          │ 6. Display confirmation    │             │
│          └────────────┬────────────────┘            │
│                       ▼                             │
│    ┌─────────────────────────────────────────┐     │
│    │ Location Captured                        │     │
│    │ Latitude & Longitude obtained           │     │
│    │ (with accuracy level)                    │     │
│    └──────────────────┬──────────────────────┘     │
│                       │                             │
│                       ▼                             │
│    ┌─────────────────────────────────────────┐     │
│    │ Medical Profile Retrieved                │     │
│    │ • Blood type                             │     │
│    │ • Allergies                              │     │
│    │ • Current medications                    │     │
│    │ • Chronic conditions                     │     │
│    │ • Emergency contacts                     │     │
│    └──────────────────┬──────────────────────┘     │
│                       │                             │
│                       ▼                             │
│    ┌─────────────────────────────────────────┐     │
│    │ Voice Alert Generated & Played           │     │
│    │ "Emergency alert for [Name].             │     │
│    │  Blood type [Type]. Allergies:           │     │
│    │  [Allergies]. Help is on the way."       │     │
│    └──────────────────┬──────────────────────┘     │
│                       │                             │
│                       ▼                             │
│    ┌─────────────────────────────────────────┐     │
│    │ Emergency Created & Stored               │     │
│    │ Status: TRIGGERED                        │     │
│    │ Timestamp recorded                       │     │
│    │ Location locked                          │     │
│    └──────────────────┬──────────────────────┘     │
│                       │                             │
│          ┌────────────┴──────────────┐              │
│          ▼                           ▼              │
│    ┌──────────────┐          ┌──────────────────┐  │
│    │ Voice Alert  │          │ UI Confirmation  │  │
│    │ Played to    │          │ • Emergency      │  │
│    │ patient      │          │   confirmed      │  │
│    │              │          │ • Help coming    │  │
│    │ ✓ Confirming │          │ • Responder      │  │
│    │   emergency  │          │   search started │  │
│    └──────────────┘          └──────────────────┘  │
│                                                      │
│    ┌─────────────────────────────────────────┐     │
│    │ Notify Nearby Responders                 │     │
│    │ (See USE_CASE_3 for details)             │     │
│    └─────────────────────────────────────────┘     │
│                                                      │
│    ┌─────────────────────────────────────────┐     │
│    │ Notify Linked Caregivers (Optional)      │     │
│    │ (See USE_CASE_6 for details)             │     │
│    └─────────────────────────────────────────┘     │
│                                                      │
│  Actors & Systems:                                 │
│  • Patient (primary)                               │
│  • Mobile App                                      │
│  • GPS/Location Service                            │
│  • Voice Alert System (TTS)                        │
│  • Emergency Backend Server                        │
│  • Local Database (Room)                           │
└─────────────────────────────────────────────────────┘
```

---

## Actors

### Primary Actors
1. **Patient** - User in emergency situation
   - May be disoriented, injured, or panicked
   - Needs accessible one-tap activation
   - May not be able to speak clearly

2. **Mobile Device** - Android phone running MediFind
   - Must function offline (local storage)
   - Background services must be enabled
   - Location services must be enabled

### Secondary Actors
3. **System Backend** - Custom API server
   - Receives emergency records
   - Matches responders
   - Manages emergency lifecycle

4. **Device Sensors** - GPS, accelerometer, microphone
   - Provides location data
   - May trigger auto-SOS (future feature)

---

## Use Cases

### UC2.1: Tap SOS Button

**Preconditions:**
- Patient is authenticated (logged in)
- App is installed and has necessary permissions granted
- GPS location services enabled (or disabled with user warning)
- Internet service available or works offline

**Flow:**
1. Patient is on Home screen
2. Large SOS button displayed prominently
   - Red color, high contrast
   - Accessibility: 48dp minimum size
   - Voice command alternative: "Emergency"
3. Patient taps SOS button with finger
4. System immediately begins emergency process (no confirmation dialog)
5. Progress indicator shown: "Locating you..."
6. Patient may cancel within 3 seconds if accidental
7. If cancel not tapped, emergency is committed

**Alternative Flows:**

**Voice Command (Accessibility):**
1. Patient says "Emergency" or custom trigger word
2. System recognizes voice command
3. Same flow as tap activation
4. Works even with screen off

**Accidental Tap Recovery:**
1. User taps SOS by accident
2. Screen shows "Emergency triggered in 3 seconds..."
3. Countdown visible: "3... 2... 1..."
4. User can tap "Cancel" to abort
5. After 3 seconds passed, cancellation unavailable

**Postconditions:**
- Emergency creation initiated
- System begins location acquisition
- No user input required from this point forward

---

### UC2.2: Verify Authentication

**Preconditions:**
- SOS button tapped
- User session exists

**Flow:**
1. System checks if user is authenticated
2. If authenticated:
   - Get current user ID from session/token
   - Proceed to location capture
3. If not authenticated:
   - Emergency proceeds with anonymous flag
   - Backend may flag for verification
   - Limited functionality (can't link medical profile)

**Error Handling:**
```
If authentication failure:
- User ID: null or "anonymous"
- Medical profile: Not available
- Verification required after emergency
```

**Postconditions:**
- User ID confirmed
- Proceed to location capture

---

### UC2.3: Request GPS Location

**Preconditions:**
- Authentication verified
- Location permissions granted
- GPS enabled (or device will attempt)

**Flow:**
1. System requests location from LocationManager
2. System tries multiple location providers (in order):
   - GPS (high accuracy, 5-15 seconds)
   - Network location (faster, 2-5 seconds)
   - Cached location (instant, may be stale)
3. Timeout: Wait maximum 10 seconds for location
4. If timeout: Use last known location + stale flag
5. Location obtained with metadata:
   - Latitude (double)
   - Longitude (double)
   - Accuracy in meters (0-100m ideal)
   - Timestamp

**Example Location Capture:**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 15.0,
  "provider": "GPS",
  "timestamp": "2024-02-25T14:45:30.123Z"
}
```

**Offline Fallback:**
```
If no location available:
- Use last known location (timestamp)
- Mark as "stale" in UI
- Display warning: "Location approximate"
```

**Postconditions:**
- Location coordinates obtained
- Accuracy level determined
- Timestamp recorded

---

### UC2.4: Retrieve Medical Profile

**Preconditions:**
- User authenticated
- Medical profile exists in local database
- Network available OR offline cached copy available

**Flow:**
1. System queries Room database for medical profile
2. Medical profile retrieved (0-100ms local):
   ```
   Blood Type: O+
   Allergies: Penicillin, Aspirin
   Chronic Diseases: Diabetes, Hypertension
   Current Medications: [list]
   Emergency Contacts: [list]
   ```
3. If not found in local cache:
   - Try to fetch from API (background)
   - Show "Profile loading..." while waiting
   - If fetch succeeds: Cache locally
   - If fetch fails: Continue without profile
4. Profile cached and ready

**Data Cached Examples:**
```
Last update: 2024-02-20 10:30:00
Cached: 5 days old (acceptable)
Will sync when network available
```

**Postconditions:**
- Medical profile ready for use
- Prepared for voice alert generation

---

### UC2.5: Generate Voice Alert

**Preconditions:**
- Location obtained
- Medical profile retrieved
- TTS engine initialized

**Flow:**
1. System generates voice alert message:
   ```
   "Emergency alert for {NAME}. 
    Blood type {BLOOD_TYPE}. 
    Allergies: {ALLERGIES}. 
    Emergency responders have been notified. 
    Help is on the way."
   ```
2. Example generated message:
   ```
   "Emergency alert for John Doe.
    Blood type O+.
    Allergies: Penicillin, Aspirin.
    Emergency responders have been notified.
    Help is on the way."
   ```
3. System initializes Text-to-Speech engine
4. Message queued for immediate playback
5. Audio output:
   - Loud volume (max volume enforced)
   - Clear pronunciation
   - Slow speech rate (for clarity)
   - Can be interrupted by user

**Voice Alert Parameters:**
```kotlin
Speech rate: 0.8 (slower than normal)
Pitch: 1.0 (normal)
Volume: 100% (max)
Language: User's device language
Repeat count: 1 (plays once, user can replay)
Utterance ID: "emergency_alert_{timestamp}"
```

**Alternative: Custom Alert Sound**
- If TTS fails: Play pre-recorded audio file
- Distinctive siren-like sound
- 3-5 seconds duration
- Repeats if patient hasn't acknowledged

**Postconditions:**
- Voice alert played to patient
- Patient aware emergency triggered
- Audio permission acknowledged

---

### UC2.6: Create Emergency Record

**Preconditions:**
- All data collected (location, medical profile, user ID)
- Not in offline mode OR emergency saved locally

**Flow:**
1. System creates emergency record object:
   ```json
   {
     "emergencyId": "emg_2024_feb25_144530",
     "userId": "user_abc123",
     "status": "TRIGGERED",
     "emergencyType": "MEDICAL",
     "latitude": 40.7128,
     "longitude": -74.0060,
     "accuracy": 15.0,
     "timestamp": "2024-02-25T14:45:30.123Z",
     "additionalInfo": null,
     "voiceAlertGenerated": true,
     "medicalProfileSnapshot": {
       "bloodType": "O+",
       "allergies": ["Penicillin", "Aspirin"],
       "medications": [...]
     }
   }
   ```

2. **Save Locally (Immediately):**
   - Insert into Room EmergencyEntity table
   - Stored with status: TRIGGERED
   - Timestamp locked (cannot be edited)
   - Transaction commits: Database saves immediately

3. **Upload to Server (Background):**
   - If network available: Send to API immediately
   - If network unavailable: Queue for later sync
   - Retry logic: Exponential backoff (1s, 2s, 4s, 8s...)

4. **Backup Strategy:**
   - Copy to encrypted file backup
   - Survives app crash
   - Syncs when app relaunches

**Offline Scenario:**
```
Network Down:
1. Emergency saved locally ✓
2. Voice alert played ✓
3. Location captured ✓
4. Medical profile cached ✓
5. When network returns: Auto-sync ✓
6. Responders notified (once online) ✓
```

**Postconditions:**
- Emergency record persisted locally
- Ready for synchronization
- Awaiting responder assignment

---

### UC2.7: Display Confirmation UI

**Preconditions:**
- Emergency record created
- Voice alert played

**Flow:**
1. Screen updates to show:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━
   🚨 EMERGENCY TRIGGERED
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━
   
   Location Captured ✓
   📍 Downtown District
   Accuracy: 15 meters
   
   Medical Profile ✓
   Blood Type: O+
   Allergies: Penicillin, Aspirin
   
   Emergency Responders ➡️
   Finding responders nearby...
   
   [Cancel Emergency] [Call 911]
   
   Stay Calm. Help is on the way.
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

2. Screen displays:
   - Emergency status (TRIGGERED)
   - Location confirmation
   - Medical data summary
   - Responder search status
   - Option to cancel or call 911

3. Auto-locking features:
   - Phone stays awake (no screen timeout)
   - Volume stays loud
   - Screen brightness high
   - Cannot accidentally lock

4. Real-time updates:
   - As responders found: "Found 1 responder"
   - As responder accepts: "Responder assigned"
   - Location sharing: "Location being shared"

**Accessibility Features:**
```
✓ High contrast (red + white)
✓ Large text (32pt minimum)
✓ Voice feedback: Screen reader announces status
✓ Haptic feedback: Vibration confirms actions
✓ Simplified UI: No unnecessary features
```

**Postconditions:**
- Patient sees confirmation
- Aware help is on the way
- Can cancel if false alarm

---

### UC2.8: Optional - Provide Additional Info

**Preconditions:**
- Emergency triggered
- Confirmation screen displayed
- Patient able to provide input

**Flow:**
1. Patient can optionally type additional details
2. Voice input alternative: "Describe your emergency"
3. Examples of additional info:
   - "Chest pain, shortness of breath"
   - "Fall from stairs, possible broken leg"
   - "Traffic accident, conscious"
   - "Severe allergic reaction"

4. Text field with voice-to-text:
   ```
   Additional Details (optional):
   [Text field]
   [Microphone icon for voice input]
   
   OR
   
   Quick tags (tap to select):
   [ Chest Pain ] [ Difficulty Breathing ]
   [ Fall ] [ Accident ] [ Assault ] [ Other ]
   ```

5. Information added to emergency:
   - Visible to all responders
   - Helps with responder matching
   - Aids in treatment preparation

**Postconditions:**
- Optional additional info recorded
- Available to responders

---

## Data Models

### Emergency Record (Created)
```kotlin
data class Emergency(
    val id: String,                    // emg_2024_feb25_144530
    val userId: String,                // user_abc123
    val status: EmergencyStatus,       // TRIGGERED
    val emergencyType: EmergencyType,  // MEDICAL
    val latitude: Double,              // 40.7128
    val longitude: Double,             // -74.0060
    val accuracy: Double?,             // 15.0 meters
    val timestamp: String,             // ISO 8601
    val additionalInfo: String?,       // User-provided details
    val voiceAlertGenerated: Boolean,  // true
    val medicalProfileSnapshot: MedicalProfile?  // Cached at time of trigger
)

enum class EmergencyType {
    MEDICAL,
    FALL,
    ACCIDENT,
    ASSAULT,
    OTHER
}

enum class EmergencyStatus {
    TRIGGERED,
    LOCATING,
    RESPONDER_ASSIGNED,
    IN_PROGRESS,
    ON_SITE,
    COMPLETED,
    ESCALATED,
    CANCELLED
}
```

### Location Data
```kotlin
data class LocationData(
    val latitude: Double,
    val longitude: Double,
    val accuracy: Double,              // in meters
    val provider: String,              // GPS, Network, Cached
    val timestamp: String,             // ISO 8601
    val altitude: Double?,             // optional
    val speed: Float?                  // optional
)
```

---

## Success Metrics

✅ SOS activation time: < 2 seconds from tap to voice alert
✅ Location capture: 95% success within 10 seconds
✅ Voice alert: Clear, audible even with muted phone
✅ Medical data retrieval: < 500ms from local cache
✅ Emergency record creation: Atomic (all or nothing)
✅ Works offline: Emergency saved locally, syncs when online
✅ No data loss: All information persisted before upload
✅ User confirmation: Clear visual + audio feedback
✅ Accessibility: Operable without visual/hearing
✅ Voice command recognition: 90%+ accuracy

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| GPS timeout | Use last known location + stale flag |
| Medical profile missing | Proceed without profile, notify responders |
| Network unavailable | Save locally, queue for sync |
| TTS engine failure | Play backup alarm sound |
| Location permission denied | Use approximate location warning |
| Voice alert playback failure | Display text alert instead |
| Database error | Retry with exponential backoff |

---

## Related Use Cases

→ **UC3: Responder Assignment** - Responders notified after SOS triggered  
→ **UC4: Emergency Tracking** - Real-time location streaming to responders  
→ **UC6: Caregiver Integration** - Caregivers notified of patient emergency  
→ **UC8: Notifications** - Notification delivery to responders/caregivers  
→ **UC9: Complete Lifecycle** - Timeline of emergency from trigger to completion
