# PostgreSQL Queries for MediFind (Categorized by Table)

This document contains useful PostgreSQL queries interacting with the schema defined in `SCHEMA_POSTGRES.md`, categorized explicitly by the primary table they interact with.

---

## 1. `users` Table Queries 
*(Handles Core Accounts, Login, Roles, and Responders)*

### 1.1 Create a New User (Registration)
```sql
INSERT INTO users (id, fullName, email, phoneNumber, role, profileImageUrl) 
VALUES (
    'usr_1234567890', 
    'John Doe', 
    'john.doe@example.com', 
    '+1234567890', 
    'PATIENT', 
    'https://example.com/avatar.jpg'
) RETURNING *;
```

### 1.2 Get User by Email (Login Authentication)
```sql
SELECT * FROM users 
WHERE email = 'john.doe@example.com' 
AND isActive = true;
```

### 1.3 Update User's Profile Picture
```sql
UPDATE users 
SET profileImageUrl = 'https://example.com/new-avatar.jpg' 
WHERE id = 'usr_1234567890' 
RETURNING id, profileImageUrl;
```

### 1.4 Deactivate a User Account
```sql
UPDATE users 
SET isActive = false 
WHERE id = 'usr_1234567890';
```

---

## 2. `medical_profiles` Table Queries
*(Handles Sensitive Health Data using JSONB arrays)*

### 2.1 Insert a New Medical Profile for a User
```sql
INSERT INTO medical_profiles (
    id, userId, bloodType, chronicDiseases, allergies, medications, emergencyContacts
) VALUES (
    'med_xyz987',
    'usr_1234567890',
    'O+',
    '["Type 2 Diabetes", "Hypertension"]'::jsonb,
    '[{"substance": "Penicillin", "severity": "High"}]'::jsonb,
    '[{"name": "Metformin", "dosage": "500mg"}]'::jsonb,
    '[{"name": "Jane Doe", "phone": "+1987654321", "relation": "Spouse"}]'::jsonb
);
```

### 2.2 Get Medical Profile Detail for a Patient
```sql
SELECT *
FROM medical_profiles
WHERE userId = 'usr_1234567890';
```

### 2.3 Append a New Allergy to an Existing Profile (JSONB Update)
```sql
UPDATE medical_profiles
SET allergies = allergies || '{"substance": "Peanuts", "severity": "Severe"}'::jsonb,
    lastUpdated = CURRENT_TIMESTAMP
WHERE userId = 'usr_1234567890';
```

### 2.4 Update Blood Type and Medical History
```sql
UPDATE medical_profiles
SET bloodType = 'A-', 
    medicalHistory = 'Patient had appendectomy in 2015.',
    lastUpdated = CURRENT_TIMESTAMP
WHERE userId = 'usr_1234567890';
```

---

## 3. `emergencies` Table Queries
*(Handles SOS Alerts, Responder Assignment, and Location Tracking)*

### 3.1 Trigger a New SOS Emergency
```sql
INSERT INTO emergencies (
    id, userId, status, emergencyType, latitude, longitude, additionalInfo
) VALUES (
    'emg_alert_001',
    'usr_1234567890',
    'TRIGGERED',
    'CHEST_PAIN',
    34.052235, 
    -118.243683,
    'Patient is feeling severe chest pain and shortness of breath.'
) RETURNING *;
```

### 3.2 Assign a Responder to an Active Emergency
```sql
UPDATE emergencies
SET status = 'ASSIGNED',
    assignedResponderId = 'usr_responder_999',
    estimatedArrivalTime = 8  -- minutes
WHERE id = 'emg_alert_001' AND status = 'TRIGGERED'
RETURNING id, status, assignedResponderId;
```

### 3.3 Confirm Voice Alert was Generated
```sql
UPDATE emergencies
SET voiceAlertGenerated = true
WHERE id = 'emg_alert_001';
```

### 3.4 Resolve an Emergency Scenario
```sql
UPDATE emergencies
SET status = 'RESOLVED',
    additionalInfo = CONCAT(additionalInfo, E'\n\n[RESOLVED] Patient stabilized and handed over to ER.')
WHERE id = 'emg_alert_001';
```

---

## 4. Cross-Table / Analytics Queries
*(Queries that JOIN multiple tables for complete views)*

### 4.1 Lookup a Patient's Medical Profile with their User Details
```sql
SELECT mp.*, u.fullName, u.phoneNumber, u.email 
FROM medical_profiles mp
JOIN users u ON u.id = mp.userId
WHERE mp.userId = 'usr_1234567890';
```

### 4.2 Find Nearest Available Responder (Using Haversine Formula)
*(Finds the closest responder from `users` based on an emergency location)*
```sql
-- Note: Assuming responders coordinates are temporarily stored in `additionalInfo` or via a separate tracking mechanism/table not explicitly defined in the base schema, but if they were on `users` it would look like this:
SELECT r.id, r.fullName, r.phoneNumber, 
    -- Calculate distance in Kilometers from emergency point (34.0522, -118.2436)
    6371 * acos(
        cos(radians(34.0522)) 
        * cos(radians(r.latitude)) 
        * cos(radians(r.longitude) - radians(-118.2436)) 
        + sin(radians(34.0522)) 
        * sin(radians(r.latitude))
    ) AS distance_km
FROM responders_tracking r -- Temporary tracking table or view
WHERE r.isActive = true 
AND r.status = 'AVAILABLE'
ORDER BY distance_km ASC
LIMIT 1;
```

### 4.3 Get Complete Emergency History for a Patient (With Responder Name)
```sql
SELECT e.id, e.timestamp, e.emergencyType, e.status, 
       r.fullName AS responderName, e.additionalInfo
FROM emergencies e
LEFT JOIN users r ON r.id = e.assignedResponderId
WHERE e.userId = 'usr_1234567890'
ORDER BY e.timestamp DESC;
```

### 4.4 Dashboard Analytics: Active Emergencies by Type
```sql
SELECT emergencyType, COUNT(*) as active_count
FROM emergencies
WHERE status IN ('TRIGGERED', 'ASSIGNED')
GROUP BY emergencyType
ORDER BY active_count DESC;
```
