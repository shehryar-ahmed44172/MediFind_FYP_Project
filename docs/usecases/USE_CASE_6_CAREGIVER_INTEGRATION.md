# Use Case 6: Caregiver Integration & Monitoring

## Overview
This use case describes how caregivers link to patients, monitor emergency status in real-time, and receive notifications about critical events.

---

## Use Case Diagram

```
┌──────────────────────────────────────────────────────┐
│     Caregiver Monitoring & Support System             │
├──────────────────────────────────────────────────────┤
│                                                        │
│      ┌────────────────────────────┐                  │
│      │ Caregiver Linking          │                  │
│      │ (Pair with Patient)        │                  │
│      └────────┬───────────────────┘                  │
│               ▼                                        │
│      ┌────────────────────────────┐                  │
│      │ Monitor Patient Status     │                  │
│      │ • Location (if SOS active) │                  │
│      │ • Emergency history        │                  │
│      │ • Medical profile access   │                  │
│      └────────┬───────────────────┘                  │
│               ▼                                        │
│      ┌────────────────────────────┐                  │
│      │ Receive Notifications:     │                  │
│      │ • SOS Triggered            │                  │
│      │ • Responder Assigned       │                  │
│      │ • Status Updates           │                  │
│      │ • Emergency Completed      │                  │
│      └────────┬───────────────────┘                  │
│               ▼                                        │
│      ┌────────────────────────────┐                  │
│      │ View Real-Time Location    │                  │
│      │ (during active emergency)  │                  │
│      └────────────────────────────┘                  │
│                                                        │
│   ┌──────────┐  ┌──────────┐                         │
│   │Caregiver │  │ Patient  │                         │
│   │ (Actor)  │  │ (Actor)  │                         │
│   └──────────┘  └──────────┘                         │
│                                                        │
│   Caregiver Permissions:                             │
│   • View emergency history                           │
│   • Monitor active emergency                         │
│   • Trigger emergency on behalf                      │
│   • View limited medical profile                     │
│   • Receive notifications                            │
└──────────────────────────────────────────────────────┘
```

---

## Actors

### Primary Actors
1. **Caregiver** - Guardian, family member, or care provider
2. **Patient** - Individual being monitored
3. **System** - Manages permissions and notifications

### Secondary Actors
4. **Emergency System** - Provides emergency event data
5. **Notification Service** - Sends alerts to caregivers

---

## Use Cases

### UC6.1: Register as Caregiver

**Preconditions:**
- User is not yet registered
- User wants to create caregiver account

**Flow:**
1. User selects "Create Account" → "Caregiver"
2. System displays caregiver registration form:
   - Full name
   - Email address
   - Phone number
   - Password
   - Caregiver type (family, medical professional, facility)
3. User fills in fields
4. System validates inputs
5. System creates caregiver account
6. System generates auth token
7. User redirected to link patient page
8. User logs in as caregiver

**Postconditions:**
- Caregiver account created
- Ready to link to patient

**Caregiver Types:**
- Family member (spouse, child, parent, sibling)
- Friend
- Medical professional (doctor, nurse, therapist)
- Care facility staff
- Other

---

### UC6.2: Link to Patient

**Preconditions:**
- Caregiver is logged in
- Caregiver has no linked patients (or can add more)
- Patient account exists

**Flow - Caregiver Initiates:**
1. Caregiver navigates to "Add Patient"
2. System displays linking options:
   - Enter patient email
   - Scan QR code from patient app
   - Enter patient ID code
3. Caregiver selects option and enters patient info
4. System searches for patient
5. System displays patient profile (partial):
   - Name
   - Photo
   - Status
6. Caregiver confirms: "This is the patient I care for"
7. System creates linking request
8. Notification sent to patient: "Caregiver [Name] wants to monitor you"
9. System waits for patient approval

**Flow - Patient Approves:**
1. Patient receives notification: "Caregiver [Name] requests to monitor"
2. Patient can view caregiver details
3. Patient accepts or rejects
4. If accepted:
   - Link established
   - Caregiver receives confirmation
   - Caregiver gains permissions
5. If rejected:
   - Link denied
   - Caregiver notified
   - Can retry or contact patient

**Postconditions:**
- Caregiver linked to patient
- Permissions granted
- Monitoring can begin

**Exception Scenarios:**
- Patient not found → Show error
- Patient rejects link → Notify caregiver
- Link already exists → Show in linked patients list

---

### UC6.3: View Patient Status Dashboard

**Preconditions:**
- Caregiver is logged in
- Caregiver has linked patients

**Flow:**
1. Caregiver navigates to "My Patients" or "Dashboard"
2. System displays list of linked patients:
   - Patient name
   - Last known status (OK, Emergency, etc.)
   - Last activity timestamp
   - Emergency history count
3. Caregiver taps on patient
4. System displays patient status:
   - Current status (active emergency or normal)
   - Last activity: "Last activity 2 hours ago"
   - Recent emergencies (last 10):
     ```
     2024-02-25 14:30 - Medical Emergency (Completed)
     Responder: Jane Smith | Duration: 22 minutes
     
     2024-02-20 09:15 - Fall (Completed)
     Responder: John Johnson | Duration: 15 minutes
     ```
   - Quick links:
     - View medical profile (limited)
     - Emergency history
     - Contact patient
     - Emergency contact settings

**Status Indicator:**
```
🟢 Green: Patient is OK, no active emergency
🟠 Orange: Emergency in progress, caregiver can monitor
🔴 Red: Requires attention or escalation
```

**Postconditions:**
- Patient status displayed
- Caregiver informed

---

### UC6.4: Monitor Active Emergency

**Preconditions:**
- Patient has active emergency
- Caregiver is linked and has enabled notifications
- Caregiver has opened app or receives notification

**Flow:**
1. System notifies caregiver: "Emergency Alert: [Patient] needs help!"
2. Caregiver opens emergency details:
   - Emergency ID
   - Status (triggered, responder assigned, in-progress, etc.)
   - Emergency type (medical, fall, accident)
   - Time since trigger
   - Assigned responder info:
     - Name (if patient approved sharing)
     - Rating
     - Status
3. Caregiver can view:
   - **Emergency location** (map view)
     - Patient location
     - Responder location (if in-progress)
     - Distance between them
   - **Real-time tracking** (if enabled):
     - Responder approaching
     - ETA
     - Status updates
   - **Timeline** of events:
     - 14:30 - Emergency triggered
     - 14:35 - Responder assigned
     - 14:38 - Responder en route
     - 14:42 - Responder arrived

4. Caregiver can take actions:
   - Call patient directly
   - Call responder
   - View medical profile
   - Request status update

**Postconditions:**
- Caregiver actively monitoring
- Emergency information accessible

---

### UC6.5: Receive Notifications

**Preconditions:**
- Caregiver linked to patient
- Caregiver has notification settings enabled

**Flow:**
1. System monitors patient emergencies
2. When events occur, system sends notifications:

   **Type 1: SOS Triggered**
   ```
   [CRITICAL] John Doe activated SOS at 14:30
   Tap to monitor emergency
   ```

   **Type 2: Responder Assigned**
   ```
   [UPDATE] Responder assigned to John's emergency
   Jane Smith (Paramedic) - 2km away, ETA 5 min
   ```

   **Type 3: Status Update**
   ```
   [UPDATE] Responder arrived at patient location
   Assessment in progress
   ```

   **Type 4: Emergency Completed**
   ```
   [COMPLETED] Emergency resolved at 14:52
   Duration: 22 minutes. Transported to City Hospital
   ```

3. Caregiver receives notifications:
   - As push notifications (if app in background)
   - As in-app notifications (if app open)
   - As SMS (if enabled and configured)
4. Caregiver can tap notification to open emergency details

**Notification Settings (Caregiver):**
```
□ Receive SOS alerts
□ Receive responder assignments
□ Receive status updates
□ Receive completion notifications
□ Receive SMS (backup)
□ Sound enabled
□ Vibration enabled
□ Do Not Disturb hours (e.g., 9pm-7am)
```

**Postconditions:**
- Notifications received
- Caregiver informed of emergencies

---

### UC6.6: Trigger Emergency for Patient

**Preconditions:**
- Caregiver is linked to patient
- Patient has enabled "Emergency by Caregiver" permission
- Caregiver is concerned about patient's safety

**Flow:**
1. Caregiver taps "SOS" or "Emergency" button
2. System displays confirmation dialog:
   - "Are you sure you want to trigger emergency for [Patient]?"
   - Shows 5-second countdown
   - Option to cancel
3. If confirmed after 5 seconds:
   - System attempts to get caregiver's location (alternative)
   - System attempts to get patient's last known location
   - System creates emergency with caregiver as initiator
   - System uses patient's medical profile
   - Nearby responders notified
4. Caregiver switched to monitoring screen
5. System notifies patient: "Emergency triggered by caregiver [Name]"

**Use Cases for Caregiver Emergency:**
- Patient fell and can't reach phone
- Patient unresponsive
- Caregiver witnesses emergency
- Scheduled check-in reveals problem

**Postconditions:**
- Emergency created
- Responders notified
- Caregiver monitoring active

**Exception Scenarios:**
- Patient disabled caregiver override → Show error
- No patient location available → Alert caregiver
- Network error → Queue for retry

---

### UC6.7: View Linked Patient Medical Profile

**Preconditions:**
- Caregiver linked to patient
- Patient approved medical profile sharing

**Flow:**
1. Caregiver navigates to "View Medical Profile"
2. System displays available information:
   ```
   ✓ Blood Type: O+
   ✓ Chronic Diseases: Diabetes, Hypertension
   ✓ Allergies: Penicillin (Moderate), Aspirin (Mild)
   ✓ Current Medications:
     - Metformin 500mg twice daily
     - Lisinopril 10mg daily
   
   ✗ Emergency Contacts (hidden - patient privacy)
   ✗ Medical History Notes (hidden - patient privacy)
   ✗ Option to edit (caregiver is read-only)
   ```

3. Medical profile is read-only for caregiver
4. Last updated timestamp shown
5. Caregiver can note any important observations

**Caregiver Can Access:**
- Blood type
- Chronic diseases
- Allergies
- Current medications

**Caregiver CANNOT Access:**
- Emergency contacts
- Medical history notes
- Edit permissions
- Full medical details (at patient's discretion)

**Postconditions:**
- Medical information available
- Privacy maintained

---

### UC6.8: View Emergency History

**Preconditions:**
- Caregiver linked to patient

**Flow:**
1. Caregiver navigates to "Emergency History"
2. System displays list of patient's emergencies:
   ```
   Recent Emergencies (last 30 days):
   
   2024-02-25 14:30 - MEDICAL
   Status: Completed | Duration: 22 min | Responder: Jane Smith (4.8★)
   
   2024-02-20 09:15 - FALL
   Status: Completed | Duration: 15 min | Responder: John Johnson (4.6★)
   
   2024-02-15 16:45 - MEDICAL
   Status: Completed | Duration: 18 min | Responder: Jane Smith (4.8★)
   ```

3. Caregiver can tap on emergency to see details:
   - Emergency type
   - Time triggered
   - Responder assigned
   - Duration
   - Status
   - Notes (if any)
4. Can export history as PDF
5. Can set reminders for follow-up appointments

**Postconditions:**
- History displayed
- Trends/patterns visible

---

## Data Models

### Caregiver Link
```kotlin
data class CaregiverLink(
    val id: String,
    val caregiverId: String,
    val patientId: String,
    val relationship: String,    // family, friend, professional
    val status: LinkStatus,      // PENDING, ACTIVE, INACTIVE
    val createdAt: Long,
    val linkedAt: Long? = null,
    val permissions: CaregiverPermissions
)

enum class LinkStatus {
    PENDING,      // Waiting for patient approval
    ACTIVE,       // Connected and monitoring
    INACTIVE,     // Deactivated by patient
    BLOCKED       // Patient blocked caregiver
}

data class CaregiverPermissions(
    val canViewMedicalProfile: Boolean = true,
    val canMonitorLocation: Boolean = true,
    val canReceiveNotifications: Boolean = true,
    val canTriggerEmergency: Boolean = false,
    val canViewHistory: Boolean = true,
    val canViewContacts: Boolean = false
)
```

---

## API Endpoints

### POST /caregiver/link
**Request:**
```json
{
  "patient_email": "patient@example.com",
  "relationship": "spouse"
}
```

**Response (Link Created - 201):**
```json
{
  "id": "link_123",
  "caregiver_id": "caregiver_xyz",
  "patient_id": "patient_abc",
  "status": "PENDING",
  "relationship": "spouse",
  "created_at": 1677123456000,
  "permissions": {
    "can_view_medical_profile": true,
    "can_monitor_location": true,
    "can_receive_notifications": true,
    "can_trigger_emergency": false,
    "can_view_history": true,
    "can_view_contacts": false
  }
}
```

---

### POST /caregiver/link/{linkId}/approve
**Patient Approves Linking**

**Response:**
```json
{
  "id": "link_123",
  "status": "ACTIVE",
  "linked_at": 1677123500000
}
```

---

### GET /caregiver/patients (Protected - Caregiver)
**Response:**
```json
{
  "patients": [
    {
      "id": "patient_abc",
      "name": "John Doe",
      "status": "ACTIVE",
      "last_activity": 1677123456000,
      "emergency_history_count": 3,
      "current_emergency": null
    }
  ]
}
```

---

### GET /caregiver/patient/{patientId}/monitoring (Protected - Caregiver)
**During Active Emergency**

**Response:**
```json
{
  "patient": {
    "id": "patient_abc",
    "name": "John Doe"
  },
  "emergency": {
    "id": "emg_123",
    "status": "IN_PROGRESS",
    "triggered_at": 1677123456000,
    "location": {
      "latitude": 40.7128,
      "longitude": -74.0060
    }
  },
  "responder": {
    "id": "resp_xyz",
    "name": "Jane Smith",
    "current_location": {
      "latitude": 40.7135,
      "longitude": -74.0062
    },
    "eta_minutes": 5
  }
}
```

---

### POST /caregiver/emergency/{patientId}/trigger (Protected - Caregiver)
**Trigger Emergency for Patient**

**Response:**
```json
{
  "id": "emg_123",
  "status": "TRIGGERED",
  "initiated_by": "caregiver",
  "created_at": 1677123456000
}
```

---

## Privacy & Permissions

### Patient Controls
```
For each linked caregiver, patient can:
□ Allow/disallow medical profile access
□ Allow/disallow location monitoring
□ Allow/disallow emergency notifications
□ Allow emergency trigger by caregiver
□ View contact history
□ Unlink caregiver anytime
```

### Caregiver Restrictions
```
Caregiver can:
✓ View patient's emergency history
✓ Monitor active emergencies
✓ See medical profile (if allowed)
✓ Receive notifications
✓ Trigger emergency (if allowed)
✓ View responder details

Caregiver CANNOT:
✗ Edit patient profile
✗ Delete emergency records
✗ View other caregiver data
✗ Access patient messages
✗ Change patient settings
```

---

## Accessibility for Caregivers

- Large text options for older caregivers
- Voice notifications for critical alerts
- High contrast mode
- Screen reader compatible interface

---

## Success Metrics

✅ Caregiver can link to patient in < 2 minutes
✅ Patient receives and approves linking
✅ Notifications delivered within 2 seconds of emergency
✅ Real-time location visible during emergency
✅ Medical profile accessible and accurate
✅ Emergency history complete and searchable
✅ Caregiver can trigger emergency when needed
✅ Privacy settings respected
✅ Linked caregiver doesn't see other caregivers' info
✅ Link can be removed anytime by patient
