# Use Case 8: Notification System & Alert Management

## Overview
This use case describes how the system generates, manages, and delivers various types of notifications to patients, responders, caregivers, and administrators.

---

## Use Case Diagram

```
┌────────────────────────────────────────────────────────┐
│       Notification & Alert Management                  │
├────────────────────────────────────────────────────────┤
│                                                          │
│  Notification Types:                                   │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 1. EMERGENCY TRIGGERED (Patient → System)      │   │
│  │    └─ Notify nearby responders                 │   │
│  │    └─ Notify caregivers                        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 2. RESPONDER ASSIGNED (System → All)            │   │
│  │    └─ Notify patient                           │   │
│  │    └─ Notify caregivers                        │   │
│  │    └─ Notify assigned responder (voice alert)  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 3. STATUS UPDATE (Responder → Others)           │   │
│  │    └─ Notify patient + caregivers              │   │
│  │    └─ Real-time location update                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 4. EMERGENCY COMPLETED (System)                 │   │
│  │    └─ Notify patient + caregivers              │   │
│  │    └─ Send completion report                   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  Delivery Channels:                                     │
│  • Push Notification (primary)                         │
│  • In-app Alert                                        │
│  • Audio Alert (for responders)                        │
│  • Voice Alert (TTS for patient)                       │
│  • SMS (fallback)                                      │
│                                                          │
│  Notification Levels:                                  │
│  • CRITICAL: SOS, Emergency assigned                   │
│  • HIGH: Responder arriving                            │
│  • NORMAL: Status updates                              │
│  • LOW: History logs                                   │
└────────────────────────────────────────────────────────┘
```

---

## Notification Types

### 1. Emergency SOS Triggered

**Triggered By:** Patient taps SOS button

**Recipients:** 
- Nearby responders (within 10km, available)
- Linked caregivers (if enabled)

**For Responders:**
```
CRITICAL Alert
[Sound: Loud distinctive alert tone]
[Vibration: Strong pattern]

Emergency Alert
Medical emergency 2.3 km away
Time: Just now

[Accept] [Reject]
```

**For Caregivers:**
```
CRITICAL Alert
[Sound: Priority notification sound]
[Vibration: Pattern]

🚨 Emergency Alert!
John triggered SOS at 14:30
Location: Downtown District

[View] [Dismiss]
```

**Delivery:**
- Push notification (immediate)
- In-app notification (if app open)
- SMS backup (if configured)

---

### 2. Responder Assigned

**Triggered By:** Responder accepts emergency

**Recipients:**
- Patient
- Linked caregivers
- Assigned responder (confirmation)

**For Patient:**
```
✅ Responder Assigned
Jane Smith (Paramedic) is en route
ETA: 7 minutes
Distance: 2.3 km
Rating: 4.8 ⭐

[View Tracking]
```

**For Caregivers:**
```
✅ Update
Responder assigned to John's emergency
Jane Smith - Paramedic, 7 min away
Rating: 4.8 ⭐

[Monitor]
```

**For Responder (Confirmation):**
```
✅ Emergency Accepted
Navigate to: Downtown District
Distance: 2.3 km
ETA: 7 minutes

[Start Navigation]
```

---

### 3. Status Updates

**Responder Status Changes:**

**Responder En Route (to patient):**
```
📍 Update: Responder En Route
Jane Smith is on the way
ETA: 5 minutes
```

**Responder Arrived:**
```
✅ Update: Responder Arrived
Jane Smith has arrived at your location
Assessment in progress
```

**Providing Treatment:**
```
🏥 Update: Treatment Started
Medical assessment complete
Patient stable
Treatment underway
```

**Transporting Patient:**
```
🚑 Update: Patient Transport
Jane Smith is transporting you to City Hospital
Estimated transport time: 12 minutes
```

---

### 4. Emergency Completed

**Triggered By:** Responder marks emergency complete

**Recipients:**
- Patient
- Caregivers
- System/Admin (logging)

**For Patient:**
```
✅ Emergency Complete
Duration: 28 minutes

Final Status: Transported to Hospital
Responder: Jane Smith (4.8 ⭐)

Medical Summary:
- Blood pressure improved
- Heart rate stabilized
- Transported to City Hospital ER

[View Full Report]
```

**For Caregivers:**
```
✅ Emergency Resolved
John's emergency is complete
Status: Transported to Hospital

Responder: Jane Smith
Duration: 28 minutes
Patient Outcome: Stable

[View Details]
```

---

### 5. Notification Settings

**Patient Settings:**
```
Notifications Enabled: [Toggle]

For My Emergencies:
□ SOS confirmation
□ Responder assignment
□ Status updates
□ Emergency completion

Caregiver Notifications:
□ Allow caregivers to receive alerts
□ Show my name to responders
□ Show my location to caregivers

Alert Preferences:
□ Sound enabled
□ Vibration enabled
□ Text size
□ Language
```

**Responder Settings:**
```
Notifications Enabled: [Toggle]

Emergency Alerts:
□ Push notifications
□ Sound (volume slider)
□ Vibration intensity
□ Text-to-speech

Smart Scheduling:
Do Not Disturb Hours: [Set time range]
Allow Alerts During DNT: [Toggle for emergencies only]

Notification Style:
□ Minimal (badge only)
□ Standard (notification + sound)
□ Aggressive (maximum interruption)
```

---

## Notification Routing Logic

### Priority-Based Delivery

```
CRITICAL Emergencies:
├─ Immediate push notification
├─ Wake lock enabled (bypass DND)
├─ Sound + Vibration mandatory
└─ Retry every 2 seconds × 3 times

HIGH Priority:
├─ Immediate push notification
├─ Sound + Vibration (if enabled)
├─ Retry every 5 seconds × 2 times
└─ In-app notification

NORMAL Priority:
├─ Delayed push (batch deliverable)
├─ Sound optional
├─ Retry every 30 seconds × 1 time
└─ In-app notification

LOW Priority:
├─ Queued for batch delivery
├─ Silent (no sound)
├─ No retry
└─ In-app notification only
```

---

## Notification Content

### Dynamic Content Generation

**For SOS Trigger:**
```
Template: "⚠️ Emergency Alert: {EMERGENCY_TYPE} at {DISTANCE}km"
Populated: "⚠️ Emergency Alert: Medical at 2.3km"

Full Body: "Emergency reported {TIME_AGO}. First responder 
notifications sent. {PATIENT_NAME} needs assistance."
```

**For Responder Assignment:**
```
Template: "✅ {RESPONDER_NAME} ({SPECIALIZATION}) is en route 
to {PATIENT_NAME}. ETA: {ETA_MINUTES} minutes."

Populated: "✅ Jane Smith (Paramedic) is en route. ETA: 7 minutes."
```

**For Status Update:**
```
Template: "📍 {STATUS_NAME}: {STATUS_DETAILS}"
Populated: "📍 Responder Arrived: Assessment in progress"
```

---

## Delivery Channels

### 1. Push Notification (Primary)
```
Advantages:
✓ Real-time delivery
✓ Works when app closed
✓ High engagement
✓ Direct to lock screen

Disadvantages:
✗ Requires internet
✗ Network delay possible
✗ User can disable

Delivery SLA: < 2 seconds
Fallback: Retry with exponential backoff
```

### 2. In-App Notification (Secondary)
```
Advantages:
✓ Works offline (after sync)
✓ Rich formatting
✓ Interactive
✓ No system permission needed

Disadvantages:
✗ Only if app open
✗ User might miss
✗ Limited reach

Display: Alert popup, Banner, or Toast
Duration: 3-5 seconds
User Can: Dismiss, Interact, or Ignore
```

### 3. Audio Alert (For Responders)
```
Tone: Distinctive, hard to ignore
Duration: 3-5 seconds
Volume: Escalating
Repeat: Every 2 seconds × 3 times (critical)

Features:
□ Works with muted phone
□ Wakes up silent mode
□ Different tones for different event types
```

### 4. Voice Alert (TTS for Patient)
```
Message Types:
"Emergency alert for John Doe. Medical emergency. 
Blood type O+. Allergies: Penicillin. 
Emergency responders are being notified."

Features:
□ Clear pronunciation
□ Slow speech rate
□ Repeats 1-3 times
□ Can be disabled
```

### 5. SMS Backup
```
Triggers:
- Push notification delivery failed
- Network unavailable
- User opted for SMS backup
- VoIP alternative

Example SMS:
"MEDIFIND ALERT: John, emergency responders have been 
notified. ETA: 7 minutes. Reply HELP for assistance."

SLA: < 60 seconds
Cost: Charged to backend
```

---

## Notification Analytics

### Tracking Metrics

```
For Each Notification:
- User ID
- Event Type
- Recipient Type
- Channel(s) used
- Delivery timestamp
- Display timestamp (if app open)
- Interaction (tapped yes/no)
- Time to interaction
- User action taken

Examples:
Event: SOS_TRIGGERED
User: patient_123
Channel: PUSH, IN_APP
Delivered: 14:30:01.234
Displayed: 14:30:01.450
Interacted: YES (tapped at 14:30:15.000)
Action: Opened emergency details
```

### Reports

```
Daily Report:
- Total notifications sent: 1,247
- Delivery success rate: 98.2%
- Average delivery time: 1.3 seconds
- User interactions: 94.1%

By Priority:
- CRITICAL: 245 sent, 100% delivery, 99.2% interaction
- HIGH: 512 sent, 98.5% delivery, 95.1% interaction
- NORMAL: 367 sent, 96.8% delivery, 89.3% interaction
- LOW: 123 sent, 94.2% delivery, 72.1% interaction
```

---

## Accessibility Features

### Text-to-Speech
- Notifications read aloud automatically
- User can trigger manual reading
- Configurable speech rate
- Multiple language support

### Visual Indicators
- High contrast notification colors
- Large text options
- Icons with text labels
- Color-blind mode (patterns instead of color)

### Haptic Feedback
- Strong vibration patterns for critical alerts
- Different patterns for different alert types
- Customizable intensity

---

## Compliance & Privacy

### GDPR Compliance
- Users can opt-out of notifications
- Data retention: 30 days max
- User can export notification history
- Clear privacy policy

### Data Security
- Encrypted notification content in transit
- Personal data minimized in notifications
- User data not sold to third parties
- Clear consent tracking

---

## Success Metrics

✅ Push notifications delivered within 2 seconds (critical)
✅ 98%+ delivery success rate
✅ 95%+ user interaction with critical alerts
✅ SMS backup activates if push fails
✅ In-app notifications synchronized with push
✅ No more than 3 duplicate notifications
✅ Notification preferences respected
✅ Audio alerts audible even with muted phone
✅ Voice alerts clear and understandable
✅ Accessibility features functional
