# Use Case 4: Emergency Tracking & Real-Time Navigation

## Overview
This use case describes the real-time tracking of responders, live location sharing with patients and caregivers, and navigation assistance during emergency response.

---

## Use Case Diagram

```
┌────────────────────────────────────────────────────────┐
│    Real-Time Tracking & Responder Navigation           │
├────────────────────────────────────────────────────────┤
│                                                          │
│         ┌──────────────────────────┐                   │
│         │ Responder Accepted       │                   │
│         │ Emergency                │                   │
│         └────────┬─────────────────┘                   │
│                  ▼                                       │
│    ┌─────────────────────────────┐                    │
│    │ Start Location Sharing       │                    │
│    │ (Real-time updates)          │                    │
│    └────────┬────────────────────┘                    │
│             ▼                                           │
│    ┌──────────────────────────────┐                   │
│    │ Share Patient Location to    │                   │
│    │ Responder & Caregivers       │                   │
│    └────────┬─────────────────────┘                   │
│             ▼                                           │
│    ┌──────────────────────────────┐                   │
│    │ Display:                     │                   │
│    │ • Responder location         │                   │
│    │ • Patient location           │                   │
│    │ • ETA                        │                   │
│    │ • Route to patient           │                   │
│    └────────┬─────────────────────┘                   │
│             ▼                                           │
│    ┌──────────────────────────────┐                   │
│    │ Stream Real-Time Updates     │                   │
│    │ (every 2-5 seconds)          │                   │
│    └──────────────────────────────┘                   │
│                                                          │
│  ┌───────────┐  ┌─────────────┐  ┌──────────────┐     │
│  │ Patient   │  │ Responder   │  │ Caregiver    │     │
│  │ (view)    │  │ (navigate)  │  │ (monitor)    │     │
│  └───────────┘  └─────────────┘  └──────────────┘     │
│                                                          │
│  • Updates every 2-5 seconds                           │
│  • WebSocket for real-time sync                        │
│  • Fallback to HTTP polling if needed                  │
└────────────────────────────────────────────────────────┘
```

---

## Actors

### Primary Actors
1. **Responder** - Navigating to patient location
2. **Patient** - Monitoring responder approach
3. **Caregiver** - Monitoring emergency in real-time

### Secondary Actors
4. **Location Service** - Provides real-time GPS updates
5. **Maps Service** - Provides routing and navigation (Google Maps)
6. **WebSocket Server** - Real-time location streaming

---

## Use Cases

### UC4.1: Start Location Sharing

**Preconditions:**
- Emergency status is RESPONDER_ASSIGNED
- Responder has accepted emergency
- Both responder and patient have location permissions

**Flow:**
1. System initiates location sharing session
2. System subscribes responder to location updates:
   - Responder's location captured every 5 seconds
   - Timestamp and accuracy recorded
3. System subscribes patient to location updates:
   - Responder's location sent to patient every 5 seconds
   - ETA calculated based on current route
4. System subscribes caregivers (if enabled):
   - Reduced location update frequency (10 seconds)
   - Read-only access
5. WebSocket connection established for real-time updates
6. Fallback to HTTP polling if WebSocket unavailable

**Postconditions:**
- Location sharing active
- Real-time updates streaming
- Tracking UI populated

**Exception Scenarios:**
- Location permission denied → Request permission
- GPS unavailable → Use last known location
- Network error → Fallback to polling
- WebSocket connection lost → Retry connection
- User disables location → Pause tracking

---

### UC4.2: Display Tracking Information

**Preconditions:**
- Location sharing active
- Real-time location data available

**Flow - Patient View:**
1. Display patient location (center of map)
2. Display responder location with distance
3. Display route from responder to patient
4. Display ETA (estimated time of arrival)
5. Show responder details:
   - Name (if privacy enabled)
   - Avatar/photo
   - Response rating
6. Display emergency status
7. Enable call/chat with responder

**Flow - Responder View:**
1. Display navigation map to patient
2. Show turn-by-turn directions
3. Display patient location
4. Show current speed and distance remaining
5. Display patient info:
   - Name
   - Address (if available)
   - Medical alerts (allergies, conditions)
6. Enable call/chat with patient
7. Show emergency details and notes

**Flow - Caregiver View:**
1. Display map with both locations
2. Show responder approaching patient
3. Display ETA
4. Show emergency status
5. Read-only view (no navigation)
6. Unable to call/chat directly

**Postconditions:**
- Tracking information displayed
- User can monitor or navigate

---

### UC4.3: Real-Time Location Updates

**Preconditions:**
- Location sharing active
- Location tracking enabled

**Flow:**
1. Every 5 seconds (responder) or 10 seconds (caregiver):
   - Capture current GPS location
   - Calculate distance to destination
   - Recalculate ETA
   - Send update via WebSocket
2. If WebSocket unavailable:
   - Queue updates locally
   - Send batch update via HTTP every 30 seconds
3. Update UI with new location
4. Recalculate route if responder deviates
5. Log all location points to database

**Update Frequency:**
```
Active Responder: Every 5 seconds
Passive Caregiver: Every 10 seconds
Historical Archive: Stored for 24 hours
```

**Data Sent in Update:**
```json
{
  "emergency_id": "emg_abc123",
  "responder_id": "resp_xyz789",
  "latitude": 40.7135,
  "longitude": -74.0062,
  "accuracy_meters": 12,
  "speed_kmh": 25,
  "heading": 285,
  "timestamp": 1677123465000
}
```

**Postconditions:**
- Location updated
- UI refreshed
- ETA recalculated

---

### UC4.4: Navigate to Patient

**Preconditions:**
- Responder has accepted emergency
- Patient location known
- Responder has GPS enabled

**Flow:**
1. System integrates with Google Maps API
2. System calculates optimal route to patient
3. Display turn-by-turn navigation:
   - Current street name
   - Next turn distance
   - Turn direction (Left, Right, Straight)
4. Responder can tap "Start Navigation"
5. System opens Google Maps with route
6. Responder follows turn-by-turn directions
7. System recalculates route if responder deviates:
   - If deviation > 100 meters
   - Suggest new route
   - Alert responder
8. Display remaining distance and ETA at all times

**Optional Features:**
- Voice guidance (turn-by-turn via TTS)
- Traffic updates
- Alternative routes
- Parking suggestions

**Postconditions:**
- Navigation begun
- Responder following route to patient

---

### UC4.5: Mark Arrival

**Preconditions:**
- Responder has navigated to patient location
- Responder is within 100 meters of patient
- Emergency is IN_PROGRESS

**Flow:**
1. System detects proximity to patient location
2. System prompts responder: "Have you arrived?"
3. Responder confirms arrival
4. System updates emergency status to "ON_SITE"
5. Stop location updates (location no longer needed)
6. Notify patient: Responder arrived
7. Notify caregiver: Responder on-site
8. Display responder assessment form

**Postconditions:**
- Status updated to ON_SITE
- Location tracking paused
- Assessment interface displayed

---

### UC4.6: Update Status During Response

**Preconditions:**
- Responder is on-site
- Emergency is actively being handled

**Flow:**
1. Responder can update status:
   - "Patient Assessed"
   - "Providing Treatment"
   - "Awaiting Transport"
   - "Transporting Patient"
   - "Transferred to Hospital"
2. Each status update:
   - Recorded with timestamp
   - Sent to patient
   - Sent to caregivers
   - Archived for history
3. Status timestamps create timeline

**Example Status Timeline:**
```
16:45 - SOS Triggered
16:47 - Responder Assigned
16:53 - Responder Arrived
16:55 - Patient Assessed
17:02 - Treatment Started
17:15 - Transporting Patient
17:22 - Transferred to Hospital (Emergency Complete)
```

**Postconditions:**
- Emergency history updated
- Timeline created
- All parties notified

---

## Data Models

### Location Update (Real-Time)
```kotlin
data class LocationUpdate(
    val emergencyId: String,
    val responderId: String,
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Int,
    val speedKmh: Double,
    val heading: Int? = null,
    val timestamp: Long = System.currentTimeMillis()
)

data class EmergencyTrackingData(
    val emergency: Emergency,
    val responder: Responder,
    val currentLocation: LocationUpdate,
    val distance_km: Double,
    val eta_minutes: Int,
    val patient: User,
    val route: List<LocationUpdate> // Historical route
)
```

---

## API Endpoints

### WebSocket: /ws/emergency/{emergencyId}
**Connection Upgrade** (requires auth token in query)

**Subscribe Message:**
```json
{
  "action": "SUBSCRIBE",
  "emergency_id": "emg_abc123",
  "user_type": "PATIENT"
}
```

**Location Update Stream:**
```json
{
  "type": "LOCATION_UPDATE",
  "emergency_id": "emg_abc123",
  "responder_id": "resp_xyz789",
  "latitude": 40.7135,
  "longitude": -74.0062,
  "accuracy_meters": 12,
  "speed_kmh": 25,
  "timestamp": 1677123465000,
  "eta_minutes": 5
}
```

**Status Update Stream:**
```json
{
  "type": "STATUS_UPDATE",
  "emergency_id": "emg_abc123",
  "status": "ON_SITE",
  "updated_at": 1677123485000
}
```

---

### GET /emergency/{emergencyId}/tracking
**Protected (requires auth token)**

**Response (Current State):**
```json
{
  "emergency": {
    "id": "emg_abc123",
    "status": "IN_PROGRESS",
    "created_at": 1677123456000
  },
  "responder": {
    "id": "resp_xyz789",
    "name": "Jane Smith",
    "rating": 4.8
  },
  "current_location": {
    "latitude": 40.7135,
    "longitude": -74.0062,
    "accuracy_meters": 12,
    "timestamp": 1677123465000
  },
  "distance_km": 0.5,
  "eta_minutes": 3,
  "patient_location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  }
}
```

---

### PUT /emergency/{emergencyId}/status
**Protected (responder auth)**

**Request:**
```json
{
  "status": "ON_SITE"
}
```

**Response:**
```json
{
  "id": "emg_abc123",
  "status": "ON_SITE",
  "updated_at": 1677123485000
}
```

---

## Real-Time Communication

### WebSocket vs HTTP Polling

**WebSocket (Primary):**
- Real-time bidirectional communication
- Lower latency (< 100ms)
- Lower bandwidth
- Connection maintained persistently

**HTTP Polling (Fallback):**
- Every 500ms for responder location
- Every 1000ms for patient/caregiver
- Used if WebSocket unavailable
- Higher latency but more compatible

**Connection Failover Logic:**
```
1. Attempt WebSocket connection
   └─ Success → Use WebSocket
   └─ Failure → Retry after 1s (exponential backoff)
   
2. After 3 failures → Switch to HTTP polling
   └─ Poll every 500ms
   
3. If polling inconsistent → Attempt WebSocket retry
   
4. Keep-alive heartbeat every 30s (for both)
```

---

## Privacy & Location Data

### Location Sharing Rules
```
During Emergency (Active Tracking):
✓ Responder location → Patient
✓ Responder location → Caregivers (if enabled)
✓ Patient location → Responder
✓ Patient location NOT shared with caregiver
  (only responder and system know)

After Emergency Completion:
✗ Location data NOT retained long-term
✓ Historical points archived for 24 hours (audit)
✓ User can request deletion
```

### Location Privacy Settings
```
Patient Can Control:
□ Allow caregiver location tracking
□ Show name to responder
□ Show address pre-emergency
□ Retain location history (or delete after 24h)
```

---

## Performance Optimization

### Battery & Data Usage
```
For Responder:
- GPS enabled continuously
- Location update every 5 seconds
- Approximate battery drain: 2-3% per hour
- Data usage: ~1MB per 30-minute emergency

For Patient/Caregiver:
- GPS not required
- Location updates received every 5-10 seconds
- Minimal battery impact
- Data usage: ~200KB per 30-minute emergency
```

### Optimization Strategies
1. **Throttle Updates:** Reduce frequency if network congested
2. **Compress Data:** Use binary protocol instead of JSON
3. **Delta Updates:** Only send changed coordinates
4. **Cache Route:** Cache Google Maps route locally
5. **Batch Requests:** Combine multiple updates into one request

---

## Accessibility Features

### Voice Guidance (For Responder)
```
"Turn left onto 5th Avenue in 500 feet"
"Continue straight on 5th Avenue"
"You have arrived at destination"
```

### Alternative Navigation
```
□ Large text directions
□ High contrast maps
□ Screen reader compatible
□ Voice command (accept/reject)
□ Haptic feedback for turns
```

---

## Success Metrics

✅ Location update delivered within 500ms
✅ ETA accurate within ±2 minutes
✅ Map displays both locations simultaneously
✅ Responder can navigate without alternate app
✅ Patient sees responder approaching in real-time
✅ Caregiver monitor option works reliably
✅ Connection switches to polling if WebSocket fails
✅ No location history retained after 24 hours
✅ Battery impact minimized
✅ Works in weak network conditions
