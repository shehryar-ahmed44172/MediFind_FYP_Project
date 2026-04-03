# Use Case 5: Medical Profile Management

## Overview
This use case describes how patients create, view, update, and manage their digital medical profiles, which are critical for responder decision-making during emergencies.

---

## Use Case Diagram

```
┌──────────────────────────────────────────────────────────┐
│         Medical Profile Management                       │
├──────────────────────────────────────────────────────────┤
│                                                            │
│        ┌────────────────────────────┐                    │
│        │ Medical Profile            │                    │
│        │ Main View                  │                    │
│        └────────┬───────────────────┘                    │
│                 │                                         │
│    ┌────────────┼────────────┬──────────┬─────────────┐  │
│    ▼            ▼            ▼          ▼             ▼   │
│ ┌─────────┐ ┌────────┐ ┌────────┐ ┌──────────┐ ┌───────┐│
│ │View All │ │Add/Edit│ │Manage  │ │Emergency │ │History││
│ │          │ │Medical │ │Allergies│ │Contacts  │ │       ││
│ │          │ │History │ │& Meds  │ │          │ │       ││
│ └─────────┘ └────────┘ └────────┘ └──────────┘ └───────┘│
│    │            │            │          │          │      │
│    └────────────┼────────────┼──────────┼──────────┘      │
│                 │            │          │                 │
│                 └────────────┴──────────┘                 │
│                              ▼                             │
│                  ┌──────────────────────┐                 │
│                  │ Save to Local DB     │                 │
│                  │ & Sync to Server     │                 │
│                  └──────────────────────┘                 │
│                                                            │
│  ┌──────────┐  ┌──────────┐                              │
│  │ Patient  │  │Caregiver │                              │
│  │(Manage)  │  │(View)    │                              │
│  └──────────┘  └──────────┘                              │
│                                                            │
│  Read by responder during emergency                      │
└──────────────────────────────────────────────────────────┘
```

---

## Actors

### Primary Actors
1. **Patient** - Creates and maintains medical profile
2. **Caregiver** - Views (limited) medical information

### Secondary Actors
3. **Responder** - Views during active emergency
4. **System** - Syncs data between local and server

---

## Use Cases

### UC5.1: Create Medical Profile

**Preconditions:**
- Patient is logged in
- Patient has no existing profile

**Flow:**
1. Patient navigates to "Medical Profile" → "Create Profile"
2. System displays profile creation form with sections:
   - Blood Type (dropdown)
   - Chronic Diseases (multi-select or add custom)
   - Allergies (multi-select or add custom)
   - Current Medications (list with add button)
   - Emergency Contacts (list with add button)
3. User fills in basic information:
   - Blood Type: O+, O-, A+, A-, B+, B-, AB+, AB-
4. User can add chronic diseases:
   - Diabetes (Type 1, Type 2)
   - Hypertension
   - Asthma
   - Heart disease
   - Epilepsy
   - Cancer
   - Custom (type own)
5. User can add allergies:
   - Penicillin
   - Aspirin
   - Peanuts
   - Shellfish
   - Dog/Cat dander
   - Custom (type own)
6. User adds current medications (at least one entry):
   - Medication name
   - Dosage (e.g., "100mg")
   - Frequency (once, twice, thrice daily)
   - Reason (optional)
7. User adds emergency contacts:
   - Contact name
   - Phone number
   - Relationship (spouse, child, parent, friend, etc.)
8. User saves profile
9. System saves to local database
10. System syncs to server
11. Integration tests against emergency APIs

**Postconditions:**
- Medical profile created
- Data saved locally
- Data synced to server

**Validation Rules:**
```
Blood Type: Must be selected from enum
Chronic Diseases: At least 0 (optional)
Allergies: At least 0 (optional)
Medications: At least 1 required
Emergency Contacts: At least 1 required
Contact Phone: Valid phone number format
```

---

### UC5.2: View Medical Profile

**Preconditions:**
- Patient is logged in
- Medical profile exists

**Flow:**
1. Patient navigates to "Medical Profile"
2. System displays profile with sections:
   - **Summary Card:**
     - Blood Type (large, prominent)
     - Last updated timestamp
     - Edit button
   - **Chronic Diseases Section:**
     - List of diseases
     - Edit/Delete buttons
   - **Allergies Section:**
     - List of allergies (highlighted in red for warning)
     - Edit/Delete buttons
   - **Medications Section:**
     - Medication name, dosage, frequency
     - Reason (if provided)
     - Edit/Delete buttons
   - **Emergency Contacts Section:**
     - Contact names with phone numbers
     - Relationship shown
     - Edit/Delete buttons
   - **Medical History Section:**
     - Text area with notes
     - Edit button
3. All sections are read-only in view mode
4. Edit button for each section or entire profile

**Caregiver View (Limited):**
```
Caregiver can see:
✓ Blood Type
✓ Chronic Diseases
✓ Allergies
✓ Medications

Caregiver CANNOT see:
✗ Emergency Contacts (privacy)
✗ Medical History notes (privacy)
```

**Postconditions:**
- Profile displayed
- User can navigate to edit mode

---

### UC5.3: Update Medical Profile

**Preconditions:**
- Patient is logged in
- Medical profile exists

**Flow:**
1. Patient taps "Edit" on any section
2. Section switches to edit mode:
   - Editable form fields
   - Save/Cancel buttons
3. Patient can:
   - Modify existing values
   - Add new entries (medications, contacts)
   - Delete entries (if multiple exist)
4. Patient taps "Save"
5. System validates data
6. System updates local database
7. System syncs to server
8. System shows success message
9. Profile returns to view mode
10. Timestamp updated to current time

**Edit Operations:**
```
Medications:
├─ Add new medication
├─ Edit medication details
├─ Remove medication
└─ Reorder medications

Allergies:
├─ Add allergy
├─ Remove allergy
└─ Note severity (optional)

Emergency Contacts:
├─ Add contact
├─ Edit contact info
├─ Remove contact
└─ Mark as primary contact

Medical History:
├─ Edit text notes
└─ Append new entries
```

**Postconditions:**
- Profile updated
- Changes synced
- History timestamp updated

---

### UC5.4: Add Medication

**Preconditions:**
- Patient is in medical profile edit mode
- Medication list displayed

**Flow:**
1. Patient taps "+ Add Medication"
2. System displays medication entry form:
   - Medication name (text input)
   - Dosage (e.g., "100mg", "5ml")
   - Frequency (dropdown):
     - Once daily
     - Twice daily
     - Thrice daily
     - Every 6 hours
     - Every 8 hours
     - As needed
     - Custom (type own)
   - Reason (optional text)
3. Patient fills in required fields
4. Patient taps "Add"
5. Medication added to list
6. Patient can continue adding more
7. Patient taps "Save Profile" when done

**Postconditions:**
- Medication added to profile

**Validation:**
```
Medication Name: Not empty
Dosage: Not empty
Frequency: Selected or custom provided
```

---

### UC5.5: Add Allergy

**Preconditions:**
- Patient in medical profile edit mode

**Flow:**
1. Patient taps "+ Add Allergy"
2. System displays allergy options:
   - Common allergies (Penicillin, Aspirin, etc.) as chips
   - Or text input for custom allergy
3. Patient selects or types allergy
4. Patient can optionally add severity:
   - Mild (rash, itching)
   - Moderate (swelling, difficulty breathing)
   - Severe (anaphylaxis)
5. Allergy added to list
6. Can add multiple allergies
7. Patient saves profile

**Highlighting for Responders:**
```
Severe Allergies: Shown in RED
Moderate Allergies: Shown in ORANGE
Mild Allergies: Shown in YELLOW
```

**Postconditions:**
- Allergy added
- Severity recorded (if specified)

---

### UC5.6: Add Emergency Contact

**Preconditions:**
- Patient in medical profile edit mode

**Flow:**
1. Patient taps "+ Add Emergency Contact"
2. System displays emergency contact form:
   - Contact name
   - Phone number
   - Relationship (spouse, child, parent, sibling, friend)
3. Patient fills in all fields
4. System validates phone number format
5. Patient taps "Add Contact"
6. Contact added to list
7. Patient can mark as "Primary Contact" (one only)
8. Patient saves profile

**Postconditions:**
- Contact added to profile
- Contact notified during emergency (optional)

---

### UC5.7: Medical History Notes

**Preconditions:**
- Patient in medical profile edit mode

**Flow:**
1. Patient can add/edit medical history text:
   - Previous surgeries
   - Past hospitalizations
   - Family medical history
   - Other relevant information
2. Text area allows multi-line input
3. Patient adds timestamps/dates manually
4. System tracks when notes were last updated
5. Patient saves profile

**Postconditions:**
- Medical history notes saved

---

### UC5.8: View Update History

**Preconditions:**
- Patient is viewing medical profile

**Flow:**
1. Patient taps "View History" or info icon
2. System displays timeline of changes:
   - Date/Time of update
   - What was changed
   - Old value → New value
3. Shows who made change (patient or system)
4. Example:
   ```
   2024-02-25 14:30 - Updated Medication
   Aspirin 100mg daily → Aspirin 500mg twice daily
   
   2024-02-20 09:15 - Added Allergy
   New: Penicillin (Moderate severity)
   
   2024-02-15 16:45 - Added Emergency Contact
   New: John Doe (+1234567890) - Spouse
   ```

**Postconditions:**
- Update history displayed
- Audit trail visible

---

## Data Models

### Medical Profile (Domain Model)
```kotlin
data class MedicalProfile(
    val id: String,
    val userId: String,
    val bloodType: String,                    // O+, O-, A+, etc.
    val chronicDiseases: List<String> = emptyList(),
    val allergies: List<String> = emptyList(),
    val currentMedications: List<Medication> = emptyList(),
    val emergencyContacts: List<EmergencyContact> = emptyList(),
    val medicalHistory: String? = null,
    val lastUpdated: Long = System.currentTimeMillis()
)

data class Medication(
    val name: String,
    val dosage: String,
    val frequency: String,
    val reason: String? = null
)

data class EmergencyContact(
    val name: String,
    val phoneNumber: String,
    val relationship: String
)
```

---

## API Endpoints

### POST /medical/profile
**Create Medical Profile (Protected)**

**Request:**
```json
{
  "blood_type": "O+",
  "chronic_diseases": ["Diabetes Type 2", "Hypertension"],
  "allergies": ["Penicillin", "Aspirin"],
  "medications": [
    {
      "name": "Metformin",
      "dosage": "500mg",
      "frequency": "twice daily",
      "reason": "Diabetes"
    }
  ],
  "emergency_contacts": [
    {
      "name": "Jane Doe",
      "phone_number": "+1234567890",
      "relationship": "Spouse"
    }
  ],
  "medical_history": "Appendectomy in 2015"
}
```

**Response (Created - 201):**
```json
{
  "id": "med_profile_123",
  "user_id": "user_123",
  "blood_type": "O+",
  "chronic_diseases": ["Diabetes Type 2", "Hypertension"],
  "allergies": ["Penicillin", "Aspirin"],
  "medications": [
    {
      "name": "Metformin",
      "dosage": "500mg",
      "frequency": "twice daily",
      "reason": "Diabetes"
    }
  ],
  "emergency_contacts": [
    {
      "name": "Jane Doe",
      "phone_number": "+1234567890",
      "relationship": "Spouse"
    }
  ],
  "medical_history": "Appendectomy in 2015",
  "last_updated": 1677123456000
}
```

---

### GET /medical/profile (Protected)

**Response (Success - 200):**
```json
{
  "id": "med_profile_123",
  "user_id": "user_123",
  "blood_type": "O+",
  "chronic_diseases": ["Diabetes Type 2"],
  "allergies": ["Penicillin"],
  "medications": [...],
  "emergency_contacts": [...],
  "medical_history": "...",
  "last_updated": 1677123456000
}
```

---

### PUT /medical/profile (Protected)

**Request:**
```json
{
  "blood_type": "A+",
  "medications": [
    {
      "name": "Metformin",
      "dosage": "1000mg",
      "frequency": "twice daily"
    }
  ]
}
```

**Response (Updated - 200):**
```json
{
  "id": "med_profile_123",
  "blood_type": "A+",
  "medications": [...],
  "last_updated": 1677123465000
}
```

---

### GET /medical/profile/emergency-summary (Protected - For Responder)

**Response (During Active Emergency):**
```json
{
  "blood_type": "O+",
  "allergies": ["Penicillin (Moderate)", "Aspirin (Mild)"],
  "current_medications": [
    {
      "name": "Metformin",
      "dosage": "500mg",
      "frequency": "twice daily"
    }
  ],
  "chronic_diseases": ["Diabetes Type 2"],
  "emergency_contacts": [
    {
      "name": "Jane Doe",
      "phone_number": "+1234567890"
    }
  ]
}
```

---

## Privacy & Security

### Patient Controls
- [x] Who can view profile (emergency only, always available)
- [x] Share full profile with caregivers (optional)
- [x] Medical history visibility (patient can opt out)
- [x] Emergency contact names visibility

### Responder Access
```
During Emergency:
✓ Can view full medical profile
✓ Cannot edit profile
✓ Can see emergency contacts
✓ Access logged for audit

Outside Emergency:
✗ Cannot access profile
✗ No emergency responder sees inactive profile
```

### Data Encryption
- Medical profile encrypted at rest
- All API calls over HTTPS/TLS
- Password-protected backup option

---

## Data Sync Strategy

### Local-First Approach
```
1. Update local Room database immediately
2. Show success to user
3. Sync to server in background
4. If sync fails, queue for retry
5. Retry every 30 seconds with exponential backoff
6. Conflict resolution: Server version is source of truth
```

### Offline Resilience
```
Offline: Edits saved locally
Online: Immediate sync
Conflict: Log both versions, alert user
Resolution: Server version wins
```

---

## Accessibility

### Large Text Mode
- All text scalable up to 200%
- Medical terms with explanations
- Simple language where possible

### Voice Reading (TTS)
- Section headers can be read aloud
- Medication details spoken
- Allergy warnings emphasized

### High Contrast Mode
- Allergies in red
- Medications in blue
- Clear black/white text

---

## Success Metrics

✅ Profile can be created with all fields
✅ Profile displays accurately with all data
✅ Medications can be added/edited/deleted
✅ Allergies prominently displayed
✅ Emergency contacts stored and retrievable
✅ Updates sync to server within 5 seconds
✅ Works offline with local storage
✅ Responder can access during emergency
✅ Caregiver limited view enforced
✅ Update history tracked
✅ Medical data encrypted
✅ UI accessible to users with mobility impairments
