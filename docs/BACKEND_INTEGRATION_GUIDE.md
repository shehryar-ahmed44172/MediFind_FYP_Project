# MediFind: Backend Integration Guide & Specification

This document serves as the architectural blueprint for the backend development team. The MediFind Flutter frontend is **100% complete** and relies on this specification to function correctly. 

The backend should be built using **Node.js (Express.js)** and **PostgreSQL**.

---

## 🏗️ 1. Core Architecture & Environment

The Flutter app connects to the backend via two primary protocols:
1. **REST API (HTTP/HTTPS)**: Used for authentication, profile management, and static data operations.
2. **WebSockets (WS/WSS)**: Used strictly for real-time emergency telemetry (Live Tracking, ETA, Status Updates).

**Environment Setup:**
- **Local Dev URL (Android Emulator Default)**: `http://10.0.2.2:3000/api/`
- **Local WS URL**: `ws://10.0.2.2:3000/`
- **Production URL**: `https://api.medifind.com/api/`

---

## 🗄️ 2. Database Schema Recommendations (PostgreSQL)

To support the three distinct application roles without dealing with sparse `NULL` matrixes, use the **Base Auth + Profile** table architecture.

### 2.1 The Core `users` Table (Auth Only)
Handles authentication globally.
- `id` (UUID, Primary Key)
- `email` (Varchar, Unique)
- `password_hash` (Varchar)
- `role` (Enum: `'PATIENT'`, `'RESPONDER'`, `'CAREGIVER'`)
- `created_at`, `updated_at`

### 2.2 Profile Tables 
*Inserted via SQL Transactions during Registration based on the `role` enum.*

*   **`patient_profiles`**: `user_id` (FK), `full_name`, `phone_number`, `cnic`, `patient_type` (Enum: `NORMAL`, `DEAF`), `blood_type`.
*   **`caregiver_profiles`**: `user_id` (FK), `full_name`, `phone_number`, `cnic`.
*   **`responder_profiles`**: `user_id` (FK), `full_name`, `phone_number`, `cnic`, `organization`, `license_number`, `responder_type`, `vehicle_type`, `is_verified` (Boolean).

---

## 🔗 3. Required REST API Endpoints

The Flutter app expects standard JSON responses. Secure endpoints must be protected via **JWT (JSON Web Tokens)** passed in the `Authorization: Bearer <token>` header.

### Authentication Module
*   `POST /api/auth/register`
    *   **Body Payload:** `{ email, password, role, fullName, phoneNumber, cnic, ...roleSpecificFields }`
    *   **Backend Logic:** Start Transaction -> Insert into `users` -> Capture new ID -> Insert into appropriate Profile Table -> Commit.
*   `POST /api/auth/login`
    *   **Returns:** JWT Token and base user role.
*   `POST /api/auth/forgot-password`

### Profile & Caregiver Module
*   `GET /api/profile` (Returns merged `users` + specific profile data based on JWT identifier)
*   `PUT /api/profile/update`
*   `POST /api/caregiver/link` 
    *   Links a patient ID to a caregiver ID in a many-to-many relationship table (e.g., `patient_caregivers`).

---

## 📡 4. WebSocket Events (Module 7: Live Tracking)

The frontend uses `web_socket_channel`. When an emergency is active, the app connects to `/ws` and expects real-time bidirectional communication.

### Emitted from Frontend (App -> Server)
*   `["SUBSCRIBE", { "emergency_id": "12345" }]`: Tells the backend to pipe events for this emergency to this user's socket connection.
*   `["LOCATION_UPDATE", { "lat": 24.12, "lng": 65.12 }]`: Responders send this every 10 seconds.

### Received by Frontend (Server -> App)
*   `["ETA_UPDATE", { "distance": "2.5 km", "eta": "5 mins" }]`: Triggers the UI to update the live tracking map.
*   `["STATUS_UPDATE", { "status": "IN_PROGRESS" }]`: Triggers the UI state machine to step the progress banner (INITIATED -> IN_PROGRESS -> COMPLETED).

---

## 🔔 5. Push Notifications (Firebase Cloud Messaging)

The backend MUST hold a Server Account Key to Firebase to trigger Push Notifications. 

When a Patient triggers an SOS, the Backend calculates the nearest Responders and runs a Multicast FCM send.

### 5.1 The Emergency Dispatch Payload
When notifying a responder, payload keys must exactly match what the Flutter `PushNotificationService` expects to trigger the custom UI popup and Text-To-Speech systems:

```json
{
  "message": {
    "tokens": ["device_token_1", "device_token_2", "device_token_3"],
    "data": {
      "type": "EMERGENCY_REQUEST",
      "emergency_id": "emg_789",
      "emergency_type": "CARDIAC", // Triggers specific UI badges
      "patient_name": "Ali Khan",
      "distance": "1.2 km" // Handled by TTS Engine automatically!
    }
  }
}
```

### 5.2 The "Silencing" Broadcast
If Responder A accepts the emergency, the backend must immediately send a **Silent Data Notification** to Responders B and C to collapse their ringing UI modals.

```json
{
  "message": {
    "tokens": ["device_token_2", "device_token_3"],
    "data": {
      "type": "EMERGENCY_ACCEPTED_BY_OTHER",
      "emergency_id": "emg_789"
    }
  }
}
```
*(The Flutter app is already programmed to capture this specific string and safely dismiss the modal without user interaction).*

---

## 🚀 Priority Build Path for Backend Devs

1. **Week 1**: Scaffold Express.js structure. Setup PostgreSQL connection pool. Create DB schema with `users` and Profile variants.
2. **Week 2**: Implement standard JWT Auth Routes (`/register`, `/login`) and test linking them with the Flutter App login screen.
3. **Week 3**: Implement Firebase Admin SDK. Build the "SOS Trigger -> Calculate Nearby -> Send FCM Multicast" pipeline.
4. **Week 4**: Setup Socket.io or standard `ws` server logic to handle the live tracking ETA broadcast.
