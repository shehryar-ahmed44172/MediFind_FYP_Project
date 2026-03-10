# Use Case 3: Responder Assignment & Matching

## Overview
System identifies nearby available responders, sends emergency notifications, responder accepts/rejects, and assignment is locked. Escalation triggers if responder doesn't respond within timeout.

---

## Use Case Diagram

```
┌──────────────────────────────────────────────────────┐
│        Responder Assignment & Matching                │
├──────────────────────────────────────────────────────┤
│                                                       │
│   Emergency Triggered (UC2) ─────┐                  │
│                                   │                  │
│                                   ▼                  │
│   ┌────────────────────────────────────────┐        │
│   │ Query Nearby Responders                │        │
│   │ • Location: Patient's GPS              │        │
│   │ • Radius: 10 km default                │        │
│   │ • Filter: Available + On-duty          │        │
│   │ • Sort: By distance (closest first)    │        │
│   └────────────┬──────────────────────────┘        │
│                │                                     │
│                ▼                                     │
│   ┌────────────────────────────────────────┐        │
│   │ Responders Found (1-5 candidates)      │        │
│   │                                         │        │
│   │ 1. Jane Smith (Paramedic)  2.3 km ⭐⭐⭐│        │
│   │ 2. Mike Johnson (EMT)      3.5 km ⭐⭐ │        │
│   │ 3. Sarah Lee (Nurse)       5.2 km ⭐ │        │
│   └────────────┬──────────────────────────┘        │
│                │                                     │
│       ┌────────┴──────────┬──────────────┐           │
│       │                   │              │           │
│       ▼                   ▼              ▼           │
│  ┌──────────┐       ┌──────────┐   ┌──────────┐    │
│  │ Send to  │       │ Send to  │   │ Send to  │    │
│  │ Jane     │       │ Mike     │   │ Sarah    │    │
│  │ PUSH     │       │ PUSH     │   │ PUSH     │    │
│  │ ALERT    │       │ ALERT    │   │ ALERT    │    │
│  └─────┬────┘       └──────────┘   └──────────┘    │
│        │                                            │
│        ▼                                            │
│  ┌──────────────────────────────────┐              │
│  │ Jane Receives Alert:              │              │
│  │ "Emergency 2.3km away"            │              │
│  │ [Accept] [Reject]                 │              │
│  │ Timeout: 5 seconds                │              │
│  └──────────┬───────────┬────────────┘             │
│             │           │                          │
│         Accept          Reject/Timeout             │
│             │           │                          │
│             ▼           ▼                          │
│        ┌─────────────────────┐                    │
│        │ RESPONDER ASSIGNED   │                    │
│        │ OR                   │                    │
│        │ TRY NEXT RESPONDER   │                    │
│        └─────────────────────┘                    │
│                                                       │
│  Success Path:                                       │
│  ┌──────────────────────────────────────┐           │
│  │ Jane Accepted Emergency              │           │
│  │ Status: RESPONDER_ASSIGNED           │           │
│  │ Lock assignment (no other responders)│           │
│  │ Notify:                              │           │
│  │ • Patient: Responder assigned        │           │
│  │ • Caregivers: Responder assigned     │           │
│  │ • Jane: Emergency details + nav      │           │
│  │ • Mike/Sarah: Assignment cancelled   │           │
│  └──────────────────────────────────────┘           │
│                                                       │
│  Failure Path (escalation):                          │
│  ┌──────────────────────────────────────┐           │
│  │ No Responders Within Radius          │           │
│  │ OR All Reject                        │           │
│  │ Status: ESCALATED                    │           │
│  │ Actions:                             │           │
│  │ • Expand search radius to 20km       │           │
│  │ • Query different specializations    │           │
│  │ • Notify supervisor for manual       │           │
│  │   assignment                         │           │
│  │ • Escalate to 911 (if enabled)       │           │
│  └──────────────────────────────────────┘           │
│                                                       │
│  Actors & Systems:                                  │
│  • Emergency System (Backend)                       │
│  • Responder Candidate Pool                         │
│  • Location Database                                │
│  • Push Notification System                         │
│  • Assignment Manager                               │
└──────────────────────────────────────────────────────┘
```

---

## Actors

### Primary Actors
1. **System/Backend** - Manages responder matching
2. **Responder** - Potential assignee
3. **Emergency Database** - Tracks assignments

### Secondary Actors
4. **Patient** - Receiving help
5. **Notification Service** - Sends alerts
6. **Supervisor** - Manual escalation (if needed)

---

## Use Cases

### UC3.1: Query Nearby Responders

**Preconditions:**
- Emergency created with location data
- Patient location latitude/longitude available
- Responder database populated with active responders

**Flow:**
1. Backend receives emergency trigger
2. Extract patient location: (40.7128, -74.0060)
3. Query responder database:
   ```sql
   SELECT * FROM responders 
   WHERE isAvailable = true
   AND status = 'ON_DUTY'
   AND distance(latitude, longitude, 40.7128, -74.0060) <= 10 km
   ORDER BY distance ASC
   LIMIT 5
   ```

4. Distance calculation (Haversine formula):
   ```
   Jane Smith: 2.3 km away
   Mike Johnson: 3.5 km away
   Sarah Lee: 5.2 km away
   ```

5. Filter additional criteria:
   - ✓ On-duty status
   - ✓ Not handling another emergency
   - ✓ Rating > 3.0 (optional threshold)
   - ✓ Recent activity (within 24 hours)

6. Sorted results by proximity (closest first)

**Responder Query Result:**
```json
[
  {
    "responderId": "resp_def456",
    "fullName": "Jane Smith",
    "specialization": "Paramedic",
    "latitude": 40.7140,
    "longitude": -74.0055,
    "distance": 2.3,
    "isAvailable": true,
    "rating": 4.8,
    "responseTime": 6.2
  },
  {
    "responderId": "resp_ghi789",
    "fullName": "Mike Johnson",
    "specialization": "EMT",
    "latitude": 40.7200,
    "longitude": -74.0100,
    "distance": 3.5,
    "isAvailable": true,
    "rating": 4.6,
    "responseTime": 7.1
  }
]
```

**Postconditions:**
- Responder list obtained
- Sorted by distance
- Ready for notification

---

### UC3.2: Send Emergency Notifications

**Preconditions:**
- Responder candidates identified
- Notification channels functional

**Flow:**
1. For each responder (in order):
   ```
   Jane Smith (2.3 km away)
   ↓
   Send PUSH notification (critical priority)
   ↓
   Timeout: 5 seconds (await response)
   ↓
   If no response: Try Mike Johnson (next)
   ```

2. **Push Notification Payload:**
   ```json
   {
     "type": "EMERGENCY_ALERT",
     "priority": "CRITICAL",
     "title": "Emergency Alert",
     "body": "Medical emergency 2.3 km away",
     "data": {
       "emergencyId": "emg_2024_feb25_144530",
       "patientName": "John Doe",
       "distance": 2.3,
       "latitude": 40.7128,
       "longitude": -74.0060,
       "emergencyType": "MEDICAL",
       "eta": 7,
       "additionalInfo": "Chest pain"
     },
     "actions": [
       {
         "action": "ACCEPT",
         "title": "Accept",
         "icon": "ic_accept"
       },
       {
         "action": "REJECT",
         "title": "Reject",
         "icon": "ic_reject"
       }
     ]
   }
   ```

3. **Delivery Mechanism:**
   - Firebase Cloud Messaging (FCM)
   - Bypasses quiet hours
   - Wake lock enabled
   - Sound + Vibration
   - Availability: < 2 seconds delivery

4. **Alert Display on Responder Device:**
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━
   🚨 EMERGENCY ALERT
   Medical emergency 2.3 km away
   
   Duration: Just now
   [ACCEPT] [REJECT]
   ━━━━━━━━━━━━━━━━━━━━━━━━━
   
   Auto-dismiss: 5 seconds
   (becomes REJECT if not responded)
   ```

5. **Primary Responder Window:**
   ```
   Responder 1 (Jane): 5 seconds
   ↓ [No response after 5 seconds]
   Responder 2 (Mike): 5 seconds
   ↓ [Still no response]
   Responder 3 (Sarah): 5 seconds
   ↓ [Timeout]
   All rejected/no response: ESCALATE
   ```

**Postconditions:**
- Push notification sent
- Awaiting responder action

---

### UC3.3: Responder Receives & Reviews Alert

**Preconditions:**
- Responder on-duty with notification enabled
- Push notification received

**Flow:**
1. Responder receives alert:
   - Sound plays (distinctive tone)
   - Vibration pattern
   - Notification appears on lock screen or banner

2. Responder can:
   - Tap notification to view full details
   - Tap [Accept] directly from notification
   - Tap [Reject] directly from notification
   - Ignore (timeout after 5 seconds)

3. **If Responder Taps Notification:**
   - Opens full emergency details screen:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Emergency Details
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   
   Type: MEDICAL
   Distance: 2.3 km
   ETA: 7 minutes
   
   [Map showing patient location]
   
   Patient Medical Info:
   Blood Type: O+
   ⚠️ Allergies: Penicillin, Aspirin
   Medications: Metformin, Lisinopril
   Chronic: Diabetes, Hypertension
   
   Additional Info:
   "Chest pain, shortness of breath"
   
   [ACCEPT]  [REJECT]
   ```

4. Responder reviews information before deciding

**Postconditions:**
- Responder viewed details
- Ready to accept/reject

---

### UC3.4: Responder Accepts Emergency

**Preconditions:**
- Responder tapped [Accept]
- Emergency still unassigned (no other responder accepted)
- Responder still available

**Flow:**
1. Responder taps [Accept] button
2. Backend validates:
   - Responder still available ✓
   - Emergency still unassigned ✓
   - No active emergency for responder ✓
3. Atomic transaction:
   ```
   BEGIN TRANSACTION
     a) Lock emergency with responder ID
     b) Update responder status: RESPONDING
     c) Record acceptance timestamp
     d) Cancel other responder notifications
   COMMIT
   ```

4. **If Validation Fails:**
   - Show error: "Emergency already assigned"
   - Return to available status
   - Responder can receive other emergencies

5. **Success Path:**
   ```
   Status updated: RESPONDER_ASSIGNED
   Emergency locked to responder
   Other responders cancelled:
   ├─ Mike: "Emergency assigned to another responder"
   └─ Sarah: "Emergency assigned to another responder"
   ```

6. **Responder Receives Confirmation:**
   ```
   ✅ Emergency Accepted
   Navigate to: Downtown District
   Distance: 2.3 km
   ETA: 7 minutes
   
   Patient waiting at:
   [Map view]
   
   [Start Navigation]
   ```

**Postconditions:**
- Emergency locked to responder
- Other responders notified of cancellation
- Navigation ready for responder
- Patient notified of assigned responder

---

### UC3.5: Responder Rejects Emergency

**Preconditions:**
- Responder tapped [Reject]
- Emergency still unassigned

**Flow:**
1. Responder taps [Reject] button
2. System records:
   - Rejection timestamp
   - Responder ID
   - Rejection reason (optional)
3. Remove responder from candidate pool
4. Try next responder in queue:
   ```
   Jane: REJECTED
   ↓ Send to Mike
   Mike: [Awaiting response]
   ```

5. Responder returns to normal on-duty state
6. Can receive other emergencies

**Optional: Rejection Reason**
```
Why are you rejecting?
☐ Too far away
☐ Already handling emergency
☐ Unavailable right now
☐ Not my specialization
☐ Other (specify)
```

**Postconditions:**
- Responder removed from this emergency
- Next responder notified

---

### UC3.6: Responder Timeout (No Response)

**Preconditions:**
- Responder sent alert
- 5 seconds elapsed
- No accept/reject received

**Flow:**
1. System detects timeout
2. Treat as implicit rejection
3. Proceed to next responder:
   ```
   Jane: No response after 5 seconds
   Auto-reject
   ↓ Send to Mike
   ```

4. Retry counter increments
5. If all responders timeout/reject:
   ```
   Retry count: 3
   Result: 0 acceptances
   Status: ESCALATION TRIGGERED
   ```

**Postconditions:**
- Auto-rejection recorded
- Escalation logic activated if needed

---

### UC3.7: Assignment Lock (Success)

**Preconditions:**
- Responder accepted
- Validation passed

**Flow:**
1. Create assignment record:
   ```json
   {
     "emergencyId": "emg_2024_feb25_144530",
     "responderId": "resp_def456",
     "status": "ASSIGNED",
     "assignedAt": "2024-02-25T14:45:35Z",
     "estimatedArrivalTime": 7,
     "assignmentLocked": true
   }
   ```

2. Lock properties (immutable):
   - emergencyId ← cannot change
   - responderId ← cannot change
   - assignedAt ← recorded
   - assignmentLocked ← true (prevents re-assignment)

3. Update responder status:
   ```
   Status: RESPONDING
   ActiveEmergencyId: emg_2024_feb25_144530
   IsAvailable: false (no new emergencies)
   ```

4. Archive other candidate notifications:
   - Mike: Cancelled
   - Sarah: Cancelled
   - Their devices cleared of this alert

5. Immutability:
   ```
   ✗ Cannot reassign to different responder
   ✓ Can be escalated if responder unavailable
   ✗ Cannot be auto-reassigned
   ✓ Requires manual supervisor intervention
   ```

**Postconditions:**
- Assignment locked
- Responder committed
- Cannot be changed (only escalated)

---

### UC3.8: Escalation (No Responders Available)

**Preconditions:**
- All nearby responders rejected OR no responders within radius
- Escalation counter reached (3+ rejections)
- Emergency still TRIGGERED or RESPONDER_ASSIGNED

**Flow:**
1. System detects escalation condition:
   ```
   Responders queried: 3
   Accepted: 0
   Rejected: 3 (Jane, Mike, Sarah)
   Retry attempts: 1/3
   Status: ESCALATION REQUIRED
   ```

2. **Escalation Actions:**

   **Step 1: Expand Search Radius**
   ```
   Original radius: 10 km
   New radius: 20 km
   Query new responders within 20 km
   Send alerts to closest responders
   ```

   **Step 2: Query Different Specializations**
   ```
   Priority 1: Paramedics (preferred)
   Priority 2: EMTs
   Priority 3: Nurses
   Priority 4: First Responders
   ```

   **Step 3: Notify Supervisor**
   ```
   Supervisor Alert:
   "Emergency esig_2024_feb25_144530 escalated.
    Location: Downtown District.
    3 responders rejected.
    Manual assignment needed?"
   ```

   **Step 4: Optional 911 Escalation**
   ```
   If enabled in patient settings:
   Contact local 911 dispatch
   Share emergency details
   Dispatch official responders
   ```

3. **Escalation Timeline:**
   ```
   t=0s: Emergency triggered
   t=5s: Jane notified, rejects (t=5s)
   t=10s: Mike notified, rejects (t=10s)
   t=15s: Sarah notified, rejects (t=15s)
   t=16s: ESCALATION TRIGGERED
   t=16s: Expand radius, query 20km
   t=20s: 5 new responders found
   t=21s: Robert notified (first in expanded search)
   t=22s: Robert ACCEPTS
   t=22s: Emergency ASSIGNED to Robert
   ```

**Postconditions:**
- Escalation status recorded
- New responders queried
- Supervisor notified
- Retry attempts tracked

---

### UC3.9: Assignment Notification to Patient

**Preconditions:**
- Responder accepted
- Assignment locked

**Flow:**
1. Patient receives notification:
   ```
   ✅ Responder Assigned!
   Jane Smith (Paramedic)
   Rating: 4.8 ⭐
   ETA: 7 minutes
   Distance: 2.3 km
   
   Location:
   [Map showing Jane approaching]
   
   [View Tracking] [Call Jane] [Cancel]
   ```

2. Push notification sent:
   ```
   Title: "Responder Assigned!"
   Body: "Jane Smith is en route. ETA: 7 minutes"
   ```

3. In-app notification:
   - Large banner
   - Persistent (user can dismiss)
   - Action buttons: View tracking, Call, Cancel

4. Voice alert (optional):
   ```
   "Responder assigned. Jane Smith is on the way.
    Estimated arrival time: seven minutes."
   ```

**Postconditions:**
- Patient notified
- Aware of responder identity
- Can track arrival

---

### UC3.10: Assignment Notification to Caregivers

**Preconditions:**
- Patient has linked caregivers
- Caregiver notifications enabled

**Flow:**
1. Query linked caregivers:
   ```
   Patient: John Doe (user_abc123)
   Linked caregivers:
   ├─ Mary Doe (spouse) - notifications enabled
   └─ Robert Doe (son) - notifications enabled
   ```

2. Send notification to each caregiver:
   ```
   Title: "Emergency Update"
   Body: "Responder Jane Smith assigned to John's emergency.
          ETA: 7 minutes"
   ```

3. Caregiver notification includes:
   - Responder name
   - Responder rating
   - ETA
   - Medical profile summary
   - Option to monitor

4. Caregiver dashboard updates:
   ```
   John's Status: EMERGENCY - Responder Assigned
   Responder: Jane Smith (Paramedic) 4.8 ⭐
   ETA: 7 minutes
   Location: Downtown District
   
   [Monitor Live] [Contact] [Status]
   ```

**Postconditions:**
- Caregivers notified
- Can monitor emergency

---

## Data Models

### Assignment Record
```kotlin
data class Assignment(
    val assignmentId: String,
    val emergencyId: String,
    val responderId: String,
    val status: AssignmentStatus,
    val assignedAt: String,
    val acceptedAt: String?,
    val estimatedArrivalTime: Int,    // minutes
    val assignmentLocked: Boolean = true
)

enum class AssignmentStatus {
    PENDING,
    ACCEPTED,
    ACTIVE,
    COMPLETED,
    CANCELLED
}
```

### Responder Query Result
```kotlin
data class ResponderMatch(
    val responderId: String,
    val fullName: String,
    val specialization: String,
    val latitude: Double,
    val longitude: Double,
    val distance: Double,              // km
    val isAvailable: Boolean,
    val rating: Float,
    val completedEmergencies: Int,
    val responseTime: Float            // minutes
)
```

---

## Success Metrics

✅ Responders queried within 1 second
✅ Notifications delivered within 2 seconds
✅ 95%+ of emergencies assigned within 30 seconds
✅ Responder acceptance rate > 80%
✅ Escalation triggered if no acceptance within 20 seconds
✅ Average ETA accuracy within ±2 minutes
✅ Assignment lock prevents duplicate assignments
✅ Caregiver notifications sent within 5 seconds
✅ No responder receives multiple conflicting alerts
✅ Timeout logic prevents infinite queuing

---

## Error Handling

| Scenario | Action |
|----------|--------|
| No responders within 10km | Expand to 20km radius |
| All responders reject | Escalate, expand radius |
| Network failure | Queue notifications, retry |
| Double acceptance | Second accept fails with error |
| Responder becomes unavailable | Escalate, try next responder |
| Database lock timeout | Log error, retry transaction |

---

## Related Use Cases

← **UC2: SOS Emergency** - Emergency triggered, queried for responder  
→ **UC4: Emergency Tracking** - Responder navigates to patient  
→ **UC7: Responder Operations** - Responder accepts/navigates/completes  
→ **UC8: Notifications** - Responder/patient notifications sent  
→ **UC9: Complete Lifecycle** - Full timeline of emergency
