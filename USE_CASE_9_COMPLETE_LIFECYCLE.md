# Use Case 9: Complete Emergency Lifecycle

## Overview
Complete end-to-end workflow of an emergency from SOS trigger through responder completion, including all actors and system states.

---

## Complete Emergency Event Sequence

### Timeline Example: Medical Emergency Response

```
TIME : EVENT : ACTOR : SYSTEM STATE : NOTIFICATIONS
────────────────────────────────────────────────────────────

16:30:00 - PREPARATION PHASE
Patient "John Doe" logged in
Patient status: OK
Nearby responder "Jane Smith" on-duty within 2km
Caregiver "Mary Doe" (spouse) has monitoring enabled

16:45:00 - EMERGENCY TRIGGERED
Actor: Patient
Event: Taps SOS button
Location: Downtown District (40.7128, -74.0060)
  
System Actions:
1. Verify user is authenticated ✓
2. Request GPS location ✓
3. Retrieve medical profile ✓
4. Create emergency record:
   - ID: emg_2024_feb25_145330
   - Status: TRIGGERED
   - Type: MEDICAL
   - User: john_doe_123
   - Location: 40.7128, -74.0060
5. Generate voice alert: "Emergency alert for John. 
   Blood type O+. Allergies: Penicillin. 
   Responders being notified."
6. Play alert to patient (confirmation) ✓
7. Save emergency locally ✓

Notifications Sent:
→ Caregiver Mary: 🚨 Emergency - John triggered SOS at 16:45
→ Nearby Responders: ⚠️ Medical emergency 2km away [Accept/Reject]

16:45:05 - RESPONDER NOTIFICATION PHASE
System Actions:
1. Query responders within 10km:
   - Jane Smith (Paramedic): 2.3km away, available ✓
   - Mike Johnson (EMT): 3.5km away, available ✓
   - Sarah Lee (Nurse): 5.2km away, available ✓
2. Send notifications (in order of distance):
   - Jane Smith: Accept/Reject buttons visible
   - Timeout: 5 seconds

Jane Smith receives notification:
- Alert sound (distinctive tone)
- Vibration
- "Medical emergency 2.3km away"
- Displays patient medical info
- ETA if accepted: 7 minutes

16:45:07 - RESPONDER ACCEPTS EMERGENCY
Jane Smith taps [Accept]
System Actions:
1. Validate responder available ✓
2. Assign Jane Smith to emergency
3. Update emergency status: RESPONDER_ASSIGNED
4. Assigned timestamp: 16:45:07
5. Update Jane's status: RESPONDING
6. Send CANCEL to other responders:
   → Mike Johnson: Emergency assigned to another responder
   → Sarah Lee: Emergency assigned to another responder
7. Send notifications to patient & caregiver

Notifications Sent:
→ John: ✅ Responder assigned! Jane Smith (Paramedic) 
         en route. ETA: 7 minutes
→ Mary: ✅ Update - Jane Smith assigned to John's emergency
→ Jane: ✅ Navigation started. Distance: 2.3km, ETA: 7min

16:45:10 - REAL-TIME TRACKING INITIATED
System Actions:
1. Enable location streaming:
   - Jane's location: 40.7140, -74.0055
   - Interval: Every 5 seconds
   - WebSocket connection established
2. Calculate distance: 2.3km
3. Calculate ETA: 7 minutes (based on Google Maps routing)
4. Update UI for patient:
   - Map showing Jane approaching
   - Distance indicator: 2.3km
   - ETA: 7 minutes
   - Can call Jane
5. Update UI for caregiver:
   - Read-only tracking view
   - Cannot interact

[Location updates stream every 5 seconds...]

16:45:15 - LOCATION UPDATE #1
Jane's updated location: 40.7135, -74.0052
Distance: 2.1km
ETA: 6 minutes 30 seconds

16:45:20 - LOCATION UPDATE #2
Jane's updated location: 40.7130, -74.0050
Distance: 1.9km
ETA: 5 minutes 45 seconds

[Multiple updates continue...]

16:50:00 - LOCATION UPDATE #20
Jane's location: 40.7128, -74.0058
Distance: 0.2km (200 meters)
Status: Approaching patient location
ETA: 1 minute

16:50:30 - RESPONDER ARRIVAL
Jane's location: 40.71284, -74.00598
System detects: Within 100m of patient location

System Actions:
1. Prompt Jane: "Have you arrived at patient?"
2. Jane confirms: "Yes"
3. Update emergency status: ON_SITE
4. Stop location streaming
5. Display assessment form for Jane
6. Notify patient & caregivers: Responder arrived

Notifications Sent:
→ John: ✅ Jane Smith has arrived. Assessment starting.
→ Mary: ✅ Update - Responder has arrived at John's location

16:50:32 - ON-SITE ASSESSMENT
Jane begins:
- Patient assessment
- Vital signs check
- Allergy verification
- Medication review
- Observation notes

Assessment Results:
- Patient conscious & alert ✓
- Blood pressure: Elevated
- Heart rate: Rapid but stabilizing
- No allergic reactions visible
- Patient responding well to reassurance

16:52:00 - STATUS UPDATE: PATIENT ASSESSED
Jane updates status in app: "Patient Assessed"

System Actions:
1. Record status update
2. Update timeline
3. Notify patient & caregivers

Notifications Sent:
→ John: 📍 Update - Patient Assessment Complete
→ Mary: 📍 Update - John has been assessed by responder

Emergency Timeline:
- 16:45 SOS Triggered
- 16:45:07 Responder Assigned
- 16:50:30 Responder Arrived
- 16:52:00 Patient Assessed

16:55:00 - STATUS UPDATE: TREATMENT STARTED
Jane updates: "Providing Treatment"
Details: Blood pressure medication administered

Notifications Sent:
→ John: 🏥 Treatment started. Patient stable. Vitals improving.
→ Mary: 🏥 Update - Treatment underway. Patient stable.

16:58:00 - STATUS UPDATE: TRANSPORT DECISION
Jane contacts hospital:
Request ambulance for transport
Hospital confirms: City Hospital - 5 minute ETA

Jane updates: "Awaiting Transport"
Details: Ambulance dispatched by hospital

17:03:00 - AMBULANCE ARRIVAL
Hospital ambulance arrives
Patient transferred to ambulance
Jane remains with patient

17:10:00 - STATUS UPDATE: PATIENT TRANSPORTED
Jane updates: "Patient Transported to Hospital"
Hospital: City Hospital ER
Final vitals: All stable

Notifications Sent:
→ John: 🚑 You are being transported to City Hospital ER
→ Mary: 🚑 Update - John transported to City Hospital

17:15:00 - EMERGENCY COMPLETION
Patient arrives at hospital ER
Jane hands off to hospital staff
Jane marks emergency: COMPLETE

System Actions:
1. Update emergency status: COMPLETED
2. Record completion time: 17:15:00
3. Calculate metrics:
   - Total response time: 30 minutes (16:45 to 17:15)
   - Time on-site: 24 minutes 30 seconds
   - Patient outcome: Transported to hospital
   - Final status: Stable
4. Request responder rating (optional)
5. Update responder status: AVAILABLE (ready for next)
6. Generate emergency report
7. Archive emergency record

Jane rates emergency: 4.8/5 stars
Jane adds notes: "Rapid response. Cooperative patient. 
Good outcome. Patient transported successfully."

Emergency completed successfully!

Notifications Sent:
→ John: ✅ EMERGENCY COMPLETE
         Duration: 30 minutes
         Status: Transported to Hospital
         Responder: Jane Smith (4.8⭐)
         
→ Mary: ✅ EMERGENCY RESOLVED
         John's emergency is complete
         Patient transported to City Hospital
         Responder: Jane Smith
         Duration: 30 minutes
         Patient Status: Stable

17:15:30 - POST-EMERGENCY ACTIONS

John can:
- View full emergency report
- Rate Jane's performance
- Provide feedback
- Request medical records
- Contact hospital for follow-up

Mary can:
- View emergency summary
- Confirm John is safe
- Contact hospital
- Archive emergency

Jane can:
- View response details
- Submit final report
- Receive any feedback
- Return to available status for next emergency

System:
- Logs all data
- Encrypts records
- Archives report
- Updates responder stats
- Updates patient history
- Cleans up real-time data
```

---

## State Transition Diagram

```
State Machine Flow:

┌──────────────┐
│   INITIAL    │ Patient at home, responder on-duty
│   (Ready)    │
└────────┬─────┘
         │ Patient: Tap SOS
         ▼
┌──────────────────┐
│   TRIGGERED      │ Emergency created, location captured
│                  │ Voice alert played, responders notified
└────────┬─────────┘
         │ Responder: Accept/Reject [5 second timeout]
         │ ├─ Accept → proceed
         │ ├─ Reject → try next responder (escalation)
         │ └─ Timeout → escalate to next responder
         ▼
┌──────────────────┐
│ RESPONDER_       │ One responder locked, others cancell ed
│ ASSIGNED         │ Responder navigating to patient
│                  │ Real-time tracking active
└────────┬─────────┘
         │ Responder: Approaching patient
         │ [Location streaming continues]
         ▼
┌──────────────────┐
│   IN_PROGRESS    │ Responder en route or at location
│                  │ Patient being assessed/treated
└────────┬─────────┘
         │ Responder: Assess → Transport → Hospital
         │ [Multiple status updates possible]
         ▼
┌──────────────────┐
│    ON_SITE       │ Responder at patient location
│                  │ Assessment underway
└────────┬─────────┘
         │ Responder: Complete assessment & decide next
         │ ├─ Transport to hospital
         │ ├─ Treat and release
         │ └─ Other outcome
         ▼
┌──────────────────┐
│   COMPLETED      │ Emergency resolved
│                  │ Report filed
│                  │ Responder available again
└──────────────────┘

Alternative paths:
TRIGGERED ────────┐
                  ├─→ ESCALATED (no responder accepts)
                  └─→ CANCELLED (patient or caregiver cancels)
```

---

## Success Criteria - Complete Emergency Response

### Timeliness
✅ SOS activated to first notification: < 1 second
✅ Responder notified to arrival: < 10 minutes average
✅ Responder arrival to assessment start: < 2 minutes
✅ Assessment to treatment start: < 5 minutes
✅ Total response time: < 40 minutes

### Accuracy
✅ Patient location accurate within 100 meters
✅ Patient medical profile complete & current
✅ Responder specialization matches emergency type
✅ ETA estimates within ±2 minutes
✅ All timeline events recorded with timestamps

### Reliability
✅ Emergency created even if network fails (local storage)
✅ Notifications delivered within 2 seconds
✅ Location tracking maintains < 500ms latency
✅ Emergency status updates in real-time
✅ Works with weak network (graceful degradation)

### User Experience
✅ Patient experience: Simple one-tap activation
✅ Responder experience: Clear info, easy navigation
✅ Caregiver experience: Passive monitoring, informed
✅ All UI responsive (no freezing or lag)
✅ Accessibility features functional for all types

### Safety
✅ HIPAA-compliant data handling
✅ Patient location not shared permanently
✅ Medical data encrypted in transit and at rest
✅ Responder authenticated before viewing patient data
✅ Audit logs track all data access

### Completion
✅ Emergency marked complete with final status
✅ Response metrics calculated
✅ Emergency archived for 30 days
✅ Responder returned to available status
✅ Feedback/rating opportunity provided
✅ Medical records available for follow-up

---

## Exception Handling

### What if responder rejects?
- System moves to next closest responder (escalation)
- Retry counter increments
- If all reject/timeout (30 seconds): Mark ESCALATED
- Notify supervisor for manual assignment

### What if GPS unavailable?
- Use last known location (cached)
- Show warning to patient
- Proceed with last known location
- Sync when GPS restored

### What if network drops?
- Emergency created locally in Room DB
- Location tracked locally
- Queued for sync when network restored
- All events logged with timestamps
- No data loss

### What if patient cancels emergency?
- User taps "Cancel Emergency"
- System confirms cancellation
- Status updated to CANCELLED
- Respender notified
- Emergency archived
- Timeline complete

### What if responder becomes unavailable mid-response?
- Responder taps "Unable to Continue"
- Status reverted to emergency previous state
- Escalation triggered
- Next responder from queue offered
- Current responder marked unavailable

---

## Metrics Captured

For each completed emergency:
```
Patient Metrics:
- Response time: 7 min 52 sec
- Time from patient to responder arrival: 7 min 52 sec
- Total incident time: 30 min
- Outcome: Transported

Responder Metrics:
- Acceptance time: 2 sec (quick)
- Navigation time: 7 min 50 sec
- On-site time: 24 min 30 sec
- Performance rating: 4.8/5

System Metrics:
- Notification delivery: 0.8 sec
- State transitions: 5 total
- Location updates: 45 points streamed
- Data accuracy: 100%

Quality Metrics:
- Patient satisfaction: Not yet rated
- Responder professionalism: Not yet rated
- System reliability: 100%
- Outcome quality: Positive (transported, stable)
```

---

## Future Enhancements

- [ ] AI-based responder matching (predict best match)
- [ ] Machine learning for ETA prediction
- [ ] Blockchain for medical record integrity
- [ ] AR navigation for responders
- [ ] Drone dispatch for remote areas
- [ ] Telemedicine pre-assessment by responder
- [ ] Integration with hospital/dispatch systems
- [ ] Multi-language support for international users
- [ ] Family notification cascading
- [ ] Post-emergency telehealth follow-up
