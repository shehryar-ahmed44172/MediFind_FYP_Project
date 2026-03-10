# Use Case 7: Responder Operations & Management

## Overview
This use case describes the responder's workflow from accepting emergencies, navigating to patients, providing care, and completing emergency documentation.

---

## Use Case Diagram

```
┌──────────────────────────────────────────────────────┐
│         Responder Operations & Management             │
├──────────────────────────────────────────────────────┤
│                                                        │
│     ┌────────────────────────────┐                   │
│     │ Receive Emergency Call      │                   │
│     │ (notification)             │                   │
│     └────────┬───────────────────┘                   │
│              ▼                                         │
│     ┌────────────────────────────┐                   │
│     │ View Emergency Details:    │                   │
│     │ • Patient location         │                   │
│     │ • Distance from responder  │                   │
│     │ • Medical profile          │                   │
│     │ • Emergency type           │                   │
│     └────────┬───────────────────┘                   │
│              ▼                                         │
│     ┌──────────────────┬──────────────────┐          │
│     ▼                  ▼                   ▼          │
│  ┌────────┐        ┌────────┐        ┌────────┐     │
│  │ Accept │        │ Reject │        │Timeout │     │
│  │        │        │        │        │(auto)  │     │
│  └────┬───┘        └────────┘        └────────┘     │
│       ▼                                               │
│  ┌──────────────────────────────┐                   │
│  │ Start Navigation             │                   │
│  │ • Route to patient           │                   │
│  │ • ETA calculation            │                   │
│  │ • Real-time updates          │                   │
│  └────┬───────────────────────────┘                 │
│       ▼                                               │
│  ┌──────────────────────────────┐                   │
│  │ On Arrival:                  │                   │
│  │ • Mark as arrived            │                   │
│  │ • Begin assessment           │                   │
│  │ • Update status              │                   │
│  └────┬───────────────────────────┘                 │
│       ▼                                               │
│  ┌──────────────────────────────┐                   │
│  │ Complete Emergency:          │                   │
│  │ • Final status               │                   │
│  │ • Actions taken              │                   │
│  │ • Notes & observations       │                   │
│  │ • Transport status           │                   │
│  └──────────────────────────────┘                   │
│                                                        │
│  ┌──────────────┐                                   │
│  │ Responder    │                                   │
│  │ (Actor)      │                                   │
│  └──────────────┘                                   │
│                                                        │
│  Responder Dashboard:                                │
│  • Availability toggle                               │
│  • Active emergency                                  │
│  • Response history                                 │
│  • Rating & performance                             │
└──────────────────────────────────────────────────────┘
```

---

## Actors

### Primary Actors
1. **Responder** - Emergency service provider
   - Paramedic, EMT, nurse, or trained responder
   - Accepts emergencies and provides assistance

### Secondary Actors
2. **Patient** - Receiving emergency assistance
3. **System** - Manages emergency assignment and tracking
4. **Maps Service** - Navigation to patient

---

## Use Cases

### UC7.1: Set Availability Status

**Preconditions:**
- Responder is logged in
- User is registered responder

**Flow:**
1. Responder opens app dashboard
2. System displays availability toggle
3. Responder taps "Go On Duty" or "Go Off Duty"
4. If going on duty:
   - System requests permission to access location
   - Location enabled for GPS tracking
   - Responder marked as AVAILABLE
   - Status changes to green indicator
5. If going off duty:
   - System stops location tracking
   - Responder marked as UNAVAILABLE
   - Status changes to gray indicator
   - Responder stops receiving emergency notifications
6. Responder's status is broadcast to system

**Availability Status:**
```
🟢 ON DUTY - Can receive emergencies
🔴 OFF DUTY - Cannot receive emergencies
🟠 RESPONDING - Currently handling emergency
🟡 BREAK - Temporary unavailability (appears off-duty)
```

**Postconditions:**
- Availability status changed
- System updated
- Location services enabled/disabled

---

### UC7.2: Receive Emergency Alert

**Preconditions:**
- Responder is on-duty
- Responder location known
- Emergency triggered nearby

**Flow:**
1. System identifies available responders within 10km
2. System sends push notification to responder:
   ```
   [URGENT] Emergency Alert
   Medical emergency 2.3 km away
   Tap to view details
   ```
3. Responder receives notification:
   - Alert sound (loud/distinctive)
   - Vibration pattern
   - If app in foreground: in-app alert popup
   - If app in background: system notification with action buttons
4. Notification includes:
   - Emergency type
   - Distance from responder
   - Quick "Accept" or "Reject" buttons
5. Responder can:
   - Tap notification to view full details
   - Tap "Accept" to accept emergency
   - Tap "Reject" to reject emergency
   - Wait (timeout after 5 seconds)

**Alert Customization:**
```
Responder settings:
□ Alert sound volume
□ Vibration intensity
□ Text-to-speech: "Medical emergency 2 kilometers away"
□ Allow do-not-disturb hours (e.g., sleep time)
□ Quick reject if unable to respond
```

**Postconditions:**
- Responder notified
- Awaiting acceptance/rejection

---

### UC7.3: View Emergency Details

**Preconditions:**
- Responder has received emergency alert
- Responder taps to view details

**Flow:**
1. System displays emergency detail screen:
   ```
   Emergency Type: MEDICAL
   Time Since Alert: 2 minutes
   Distance: 2.3 km
   ETA if Accepted: 7 minutes
   
   Patient Information:
   Location: [Map showing patient location]
   
   Medical Alert:
   Blood Type: O+
   ⚠️ Allergies: Penicillin, Aspirin
   Medications: Metformin 500mg, Lisinopril 10mg
   Chronic Conditions: Type 2 Diabetes
   
   [Accept Button]  [Reject Button]
   ```

2. Responder can:
   - View full patient medical profile
   - View patient location on map
   - View distance and ETA calculation
   - Call patient (optional)
3. Responder makes decision:
   - Accept: Yes, I can respond
   - Reject: I'm unavailable

**Emergency Information Shown:**
```
✓ Patient blood type
✓ Major allergies (highlighted in red)
✓ Current medications
✓ Chronic diseases
✓ Distance from responder
✓ Estimated arrival time
✓ Emergency type (medical, fall, accident)

✗ Patient name (if privacy enabled)
✗ Patient address details
✗ Emergency contact information
```

**Postconditions:**
- Emergency details displayed
- Responder ready to decide

---

### UC7.4: Accept Emergency

**Preconditions:**
- Responder viewing emergency details
- Responder can respond
- Emergency is still unassigned

**Flow:**
1. Responder taps "Accept"
2. System validates:
   - Responder still available
   - Emergency still unassigned
   - No active emergency for responder
3. System updates responder status: RESPONDING
4. System assigns emergency to responder
5. System cancels notifications to other responders
6. System displays navigation screen:
   - Route to patient
   - Turn-by-turn navigation
   - Distance and ETA
7. System notifies patient: "Responder assigned"
8. System notifies caregivers: "Responder en route"
9. Responder starts navigation

**Response Message to Responder:**
```
✓ Emergency Accepted
✓ En route to patient
✓ Location sharing started
✓ ETA: 7 minutes
```

**Postconditions:**
- Emergency locked to responder
- Navigation started
- Real-time tracking active
- Patient and caregivers notified

---

### UC7.5: Reject Emergency

**Preconditions:**
- Responder viewing emergency details
- Responder cannot respond

**Flow:**
1. Responder taps "Reject"
2. System records rejection:
   - Rejection timestamp
   - Responder ID
3. System removes responder from candidate list
4. System selects next available responder
5. System sends notification to next responder
6. Responder returns to normal on-duty screen
7. No status change

**Rejection Reasons (Optional):**
```
□ Too far away
□ Already handling another emergency
□ Unavailable right now
□ Not my specialization
□ Other (specify)
```

**Postconditions:**
- Responder removed from assignment
- Next responder notified
- Responder remains on-duty

---

### UC7.6: Navigate to Patient

**Preconditions:**
- Responder has accepted emergency
- Navigation screen displayed

**Flow:**
1. System displays navigation interface:
   - Map view with patient location
   - Current responder location
   - Route highlighted
2. System gets turn-by-turn directions from Google Maps API
3. Display information:
   ```
   Distance: 2.3 km
   ETA: 7 minutes
   Current street: Main Street
   Next turn: Left onto 5th Avenue (in 500 feet)
   ```
4. Responder can:
   - Tap "Start Navigation" to open Google Maps (full app)
   - Or follow in-app directions
   - See real-time traffic updates
   - Switch between map and list view
5. Optional voice guidance via TTS:
   "Turn left onto 5th Avenue"
6. System recalculates route if responder deviates

**Navigation Features:**
```
□ Turn-by-turn directions
□ Real-time traffic info
□ Alternative routes
□ Parking suggestions
□ Estimated arrival countdown
□ Voice guidance (on/off)
□ Hands-free calling
```

**Postconditions:**
- Responder navigating to patient
- Real-time updates streaming

---

### UC7.7: Mark Arrived

**Preconditions:**
- Responder approaching patient location
- Within 100-200 meters of patient
- Emergency is IN_PROGRESS

**Flow:**
1. System detects proximity
2. System prompts responder:
   ```
   Have you arrived at patient location?
   [Yes] [Cancel]
   ```
3. Responder confirms "Yes"
4. System updates emergency status: ON_SITE
5. System stops real-time location updates
6. System notifies patient: "Responder arrived"
7. System displays assessment form
8. Responder can assess patient and update status

**Information on Arrival:**
```
Patient Details:
- Name: John Doe
- Location: 123 Main St, Apt 5B
- [Call Patient Button]
- [View Medical Profile Button]

Assessment Status:
[Start Assessment]
```

**Postconditions:**
- Status updated to ON_SITE
- Assessment form displayed
- Tracking paused

---

### UC7.8: Update Status During Response

**Preconditions:**
- Responder on-site with patient
- Emergency is ON_SITE

**Flow:**
1. Responder completes assessment
2. Responder updates status:
   ```
   Status Update Options:
   ○ Patient Assessed
   ○ Providing Treatment
   ○ Awaiting Transport
   ○ Contacting Hospital
   ○ Transporting Patient
   ○ Transferred to Hospital
   ○ Other (custom)
   ```
3. Responder can add notes:
   - What they found
   - Actions taken
   - Patient response
   - Any complications
4. Responder taps "Update Status"
5. System records:
   - New status
   - Timestamp
   - Notes
6. System notifies patient and caregivers
7. Timeline updated in real-time

**Status Timeline (Example):**
```
16:47 - Emergency Triggered
16:49 - Responder Assigned (Jane Smith)
16:53 - Responder Arrived
16:55 - Patient Assessed
        Note: Patient conscious, alert
16:58 - Providing Treatment
        Note: Blood pressure stabilized
17:05 - Transporting to City Hospital
17:15 - Transferred to Hospital
        Note: Patient handed off to ER staff
```

**Postconditions:**
- Status updated
- Emergency timeline advanced
- All parties notified

---

### UC7.9: Complete Emergency

**Preconditions:**
- Responder has transported or completed care
- Emergency is being closed

**Flow:**
1. Responder navigates to "Complete Emergency"
2. System displays completion form:
   ```
   Final Status:
   - Patient Assessment: [Summary field]
   - Actions Taken: [Summary field]
   - Final Patient Condition: [Dropdown]
     ○ Stable
     ○ Improving
     ○ Critical
     ○ Transported
   - Transport Status: [Dropdown]
     ○ No transport needed
     ○ Transported to Hospital
     ○ Transported to Facility
     ○ Other
   ```
3. Responder adds final notes:
   - What was done
   - Patient outcome
   - Any follow-ups needed
4. Responder taps "Complete Emergency"
5. System updates emergency status: COMPLETED
6. System calculates response metrics:
   - Total response time
   - Time on-site
   - Patient outcome
7. System requests responder rating (optional):
   - "Rate this emergency response" (1-5 stars)
   - Any additional notes
8. System notifies:
   - Patient: Emergency completed
   - Caregivers: Emergency resolved
9. Responder returned to on-duty dashboard

**Final Emergency Record:**
```
Emergency ID: emg_abc123
Patient: John Doe
Responder: Jane Smith
Duration: 28 minutes
Status: COMPLETED
Patient Outcome: Transported to Hospital
Responder Rating: 4.8 stars
```

**Postconditions:**
- Emergency marked complete
- Response archived
- Responder returned to available status
- Metrics recorded

---

### UC7.10: View Response History

**Preconditions:**
- Responder is logged in

**Flow:**
1. Responder navigates to "My Responses" or "History"
2. System displays list of past emergencies:
   ```
   Recent Responses (Last 30 Days):
   
   2024-02-25 16:47 - MEDICAL
   Patient: John Doe
   Duration: 28 min | Outcome: Transported
   Rating: 4.8/5 ⭐
   
   2024-02-20 09:15 - FALL
   Patient: Jane Smith
   Duration: 15 min | Outcome: Stable
   Rating: 4.6/5 ⭐
   ```

3. Responder can tap each to see:
   - Full emergency details
   - Actions taken
   - Patient outcome
   - Time spent
   - Self-rating given
   - Any patient feedback (if provided)

4. Statistics available:
   ```
   Performance Metrics:
   Total Responses: 142
   Average Response Time: 6.2 minutes
   Average Rating: 4.7/5 stars
   Patient Satisfaction: 96%
   ```

**Postconditions:**
- Response history visible
- Performance tracked

---

## Data Models

### Responder (Complete)
```kotlin
data class Responder(
    val id: String,
    val fullName: String,
    val email: String,
    val phoneNumber: String,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val specialization: String? = null,    // Paramedic, EMT, Nurse, etc.
    val isAvailable: Boolean = true,
    val activeEmergencyId: String? = null,
    val completedEmergencies: Int = 0,
    val rating: Float = 0f,
    val responseCount: Int = 0,
    val totalResponseTime: Int = 0,        // in minutes
    val averageResponseTime: Int = 0        // in minutes
)

enum class ResponderStatus {
    AVAILABLE,      // Ready to respond
    RESPONDING,     // Handling emergency
    ON_SITE,        // At patient location
    OFF_DUTY,       // Not available
    BREAK            // Temporary break
}
```

---

## Success Metrics

✅ Responder can toggle availability status easily
✅ Emergency alert received within 2 seconds
✅ Responder can view emergency details clearly
✅ Navigation integrated with Google Maps
✅ Status updates reflected in real-time
✅ Emergency completion documented properly
✅ Response history accurate and searchable
✅ Performance metrics tracked
✅ ETA accurate within ±2 minutes
✅ No duplicate emergencies assigned
