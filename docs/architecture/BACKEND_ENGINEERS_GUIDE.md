# MediFind Mobile Application - Backend Engineer's Guide

**Version:** 1.0  
**Date:** March 10, 2026  
**Audience:** Backend Engineers  
**Project:** MediFind Emergency Response & Healthcare Management App

---

## 📋 Table of Contents

1. [Tech Stack Overview](#tech-stack-overview)
2. [Frontend Architecture](#frontend-architecture)
3. [Database Schema](#database-schema)
4. [API Requirements](#api-requirements)
5. [Authentication & Security](#authentication--security)
6. [Real-Time Communication](#real-time-communication)
7. [Data Models & Entities](#data-models--entities)
8. [Integration Points](#integration-points)
9. [Backend Services Required](#backend-services-required)
10. [Development Guidelines](#development-guidelines)

---

## Tech Stack Overview

### Mobile (Frontend) Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Framework** | Flutter | 3.41.2 | Cross-platform mobile app |
| **Language** | Dart | 3.11.0 | Mobile app development |
| **State Management** | Riverpod | 2.4.0 | Reactive state management |
| **HTTP Client** | Dio | 5.3.0 | API communication |
| **Real-Time** | WebSocket | 2.4.0 | Live notifications & tracking |
| **Navigation** | GoRouter | 12.0.0 | In-app routing |
| **Local Storage** | Hive | 2.2.0 | Offline data storage |
| **Serialization** | Freezed + json_serializable | 2.4.0 | Data model generation |
| **Location** | Geolocator | 13.0.2 | GPS tracking |
| **Maps** | Google Maps Flutter | 2.5.0 | Live tracking maps |
| **Permissions** | permission_handler | 11.4.0 | Runtime permissions |

### Backend Requirements (What You Need to Build)

| Component | Recommended | Alternative | Purpose |
|-----------|-------------|-------------|---------|
| **Framework** | ASP.NET Core 8 | Node.js/Express, Python/FastAPI | Backend API server |
| **Database** | PostgreSQL | MySQL, SQL Server | Primary data storage |
| **Cache** | Redis | Memcached | Session & data caching |
| **Message Queue** | RabbitMQ | Redis Queue, Kafka | Async task processing |
| **WebSocket Server** | SignalR/.NET | Socket.io, Channels | Real-time notifications |
| **API Documentation** | Swagger/OpenAPI | GraphQL | API specs |
| **Authentication** | JWT + OAuth2 | Sessions | User authentication |
| **File Storage** | Azure Blob Storage | AWS S3, MinIO | Medical reports, profiles |
| **SMS Gateway** | Twilio | AWS SNS, Nexmo | SMS fallback (emergency backup) |
| **Email Service** | SendGrid | AWS SES, Mailgun | Email notifications |
| **Logging** | Application Insights | ELK Stack, Datadog | Monitoring & debugging |

### Infrastructure (Deployment)

| Component | Recommended | Alternative |
|-----------|-------------|-------------|
| **Cloud Platform** | Microsoft Azure | AWS, Google Cloud |
| **Container** | Docker | Podman |
| **Orchestration** | Kubernetes | Docker Swarm |
| **CI/CD** | Azure DevOps/GitHub Actions | GitLab CI, Jenkins |
| **Database Hosting** | Azure Database for PostgreSQL | AWS RDS, Google Cloud SQL |

---

## Frontend Architecture

### Clean Architecture Pattern

The Flutter app uses **Clean Architecture** with 3 main layers:

```
┌─────────────────────────────────────────┐
│     PRESENTATION LAYER (UI)             │
│  • Screens (Widgets)                    │
│  • Providers (Riverpod state)           │
│  • Theme & Navigation                   │
└──────────────┬──────────────────────────┘
               │ Depends on
               ▼
┌─────────────────────────────────────────┐
│      DOMAIN LAYER (Business Logic)      │
│  • Entities (Business models)           │
│  • Repository Interfaces (Abstract)     │
│  • Use Cases                            │
└──────────────┬──────────────────────────┘
               │ Implements
               ▼
┌─────────────────────────────────────────┐
│       DATA LAYER (External APIs)        │
│  • Repository Implementations           │
│  • Remote DataSources (API Client)      │
│  • Local DataSources (Hive DB)          │
│  • Models (API request/response)        │
└─────────────────────────────────────────┘
```

### Riverpod State Management

The app uses **Riverpod** for reactive state management:

```dart
// Providers structure:
FutureProvider       - Async data fetching (API calls)
StateNotifierProvider - Mutable state (user actions)
StreamProvider       - Real-time updates (WebSocket)
```

### HTTP Client Configuration (Dio)

```dart
// Connection details your API must support:
Dio()
  - Base URL: Will be set at runtime
  - Timeout: 30 seconds
  - Interceptors: JWT token injection
  - Error handling: Custom exception mapping
```

---

## Database Schema

### Core Entities & Relationships

#### 1. **Users Table**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone_number VARCHAR(20) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL,  -- 'PATIENT', 'RESPONDER', 'CAREGIVER', 'ADMIN'
  profile_image_url VARCHAR(255),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes needed:
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_role ON users(role);
```

#### 2. **Medical Profile Table**
```sql
CREATE TABLE medical_profiles (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blood_group VARCHAR(5),  -- O+, A-, B+, AB-, etc.
  allergies TEXT[],  -- Array of allergy strings
  chronic_diseases TEXT[],  -- Array of disease names
  medications TEXT[],  -- Array of medication names
  disabilities TEXT[],  -- Array of disability descriptions
  emergency_contact_name VARCHAR(255),
  emergency_contact_phone VARCHAR(20),
  medical_history TEXT,
  last_updated TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id)
);

CREATE INDEX idx_medical_profiles_user ON medical_profiles(user_id);
```

#### 3. **Emergency Table**
```sql
CREATE TABLE emergencies (
  id UUID PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emergency_type VARCHAR(50) NOT NULL,  -- 'CARDIAC', 'RESPIRATORY', 'TRAUMA', etc.
  status VARCHAR(50) DEFAULT 'ACTIVE',  -- 'ACTIVE', 'RESOLVED', 'CANCELLED'
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  additional_info TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  cancellation_reason TEXT
);

-- Indexes for queries:
CREATE INDEX idx_emergencies_patient ON emergencies(patient_id);
CREATE INDEX idx_emergencies_status ON emergencies(status);
CREATE INDEX idx_emergencies_created ON emergencies(created_at DESC);
CREATE INDEX idx_emergencies_location ON emergencies USING GIST(
  ll_to_earth(latitude, longitude)
);  -- For geographic queries
```

#### 4. **Responders Table**
```sql
CREATE TABLE responders (
  id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  license_number VARCHAR(50) UNIQUE NOT NULL,
  license_expiry DATE NOT NULL,
  specialization VARCHAR(100)[],  -- ['EMT', 'Paramedic', etc.]
  current_latitude DECIMAL(10, 8),
  current_longitude DECIMAL(11, 8),
  is_available BOOLEAN DEFAULT true,
  average_response_time INTEGER,  -- in seconds
  total_responses_handled INTEGER DEFAULT 0,
  rating DECIMAL(3, 2),  -- 0.00 to 5.00
  last_location_update TIMESTAMP,
  
  UNIQUE(user_id)
);

CREATE INDEX idx_responders_available ON responders(is_available);
CREATE INDEX idx_responders_location ON responders USING GIST(
  ll_to_earth(current_latitude, current_longitude)
);
```

#### 5. **Emergency Requests (Responder Assignment) Table**
```sql
CREATE TABLE emergency_requests (
  id UUID PRIMARY KEY,
  emergency_id UUID NOT NULL REFERENCES emergencies(id) ON DELETE CASCADE,
  responder_id UUID NOT NULL REFERENCES responders(id),
  request_status VARCHAR(50) DEFAULT 'PENDING',  -- 'PENDING', 'ACCEPTED', 'REJECTED', 'COMPLETED'
  distance_km DECIMAL(5, 2),  -- Distance from responder to patient
  estimated_arrival_minutes INTEGER,
  sent_at TIMESTAMP DEFAULT NOW(),
  accepted_at TIMESTAMP,
  rejected_at TIMESTAMP,
  completed_at TIMESTAMP,
  rejection_reason TEXT,
  
  UNIQUE(emergency_id, responder_id)  -- One request per responder per emergency
);

CREATE INDEX idx_emergency_requests_emergency ON emergency_requests(emergency_id);
CREATE INDEX idx_emergency_requests_responder ON emergency_requests(responder_id);
CREATE INDEX idx_emergency_requests_status ON emergency_requests(request_status);
```

#### 6. **Caregivers Table**
```sql
CREATE TABLE caregivers (
  id UUID PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  caregiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  relationship VARCHAR(50),  -- 'PARENT', 'SIBLING', 'SPOUSE', 'FRIEND'
  joined_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(patient_id, caregiver_id)
);

CREATE INDEX idx_caregivers_patient ON caregivers(patient_id);
CREATE INDEX idx_caregivers_caregiver ON caregivers(caregiver_id);
```

#### 7. **Emergency Tracking Table** (Real-time updates)
```sql
CREATE TABLE emergency_tracking (
  id UUID PRIMARY KEY,
  emergency_id UUID NOT NULL REFERENCES emergencies(id) ON DELETE CASCADE,
  responder_id UUID REFERENCES responders(id),
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  status VARCHAR(50),  -- 'EN_ROUTE', 'ARRIVED', 'TREATING', 'TRANSPORTED'
  timestamp TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tracking_emergency ON emergency_tracking(emergency_id);
CREATE INDEX idx_tracking_timestamp ON emergency_tracking(timestamp DESC);
```

#### 8. **Medical Reports Table**
```sql
CREATE TABLE medical_reports (
  id UUID PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_name VARCHAR(255) NOT NULL,
  file_url VARCHAR(500) NOT NULL,  -- Azure Blob Storage URL
  report_type VARCHAR(50),  -- 'LAB', 'IMAGING', 'PRESCRIPTION', etc.
  uploaded_at TIMESTAMP DEFAULT NOW(),
  file_size_bytes INTEGER
);

CREATE INDEX idx_medical_reports_patient ON medical_reports(patient_id);
```

---

## API Requirements

### Authentication Endpoints

#### 1. **POST /api/auth/register**
```json
Request Body:
{
  "fullName": "Shehryar Ahmed",
  "email": "shehryar@example.com",
  "phoneNumber": "+923001234567",
  "password": "SecurePassword123!",
  "role": "PATIENT"  // or "RESPONDER", "CAREGIVER"
}

Response (201):
{
  "userId": "uuid-string",
  "token": "jwt-token-string",
  "refreshToken": "refresh-token-string",
  "role": "PATIENT"
}
```

#### 2. **POST /api/auth/login**
```json
Request Body:
{
  "email": "user@example.com",
  "password": "Password123!"
}

Response (200):
{
  "userId": "uuid-string",
  "token": "jwt-token-string",
  "refreshToken": "refresh-token-string",
  "role": "PATIENT"
}
```

#### 3. **POST /api/auth/refresh-token**
```json
Request Body:
{
  "refreshToken": "refresh-token-string"
}

Response (200):
{
  "token": "new-jwt-token",
  "refreshToken": "new-refresh-token"
}
```

#### 4. **POST /api/auth/forgot-password**
```json
Request Body:
{
  "email": "user@example.com"
}

Response (200):
{
  "message": "Password reset email sent"
}
```

### Medical Profile Endpoints

#### 5. **GET /api/medical-profiles/{userId}** (Authenticated)
```json
Response (200):
{
  "id": "uuid",
  "userId": "uuid",
  "bloodGroup": "O+",
  "allergies": ["Penicillin", "Lactose"],
  "chronicDiseases": ["Diabetes", "Asthma"],
  "medications": ["Metformin 500mg", "Adrenaline Pen"],
  "disabilities": ["Wheelchair-bound"],
  "emergencyContactName": "John Doe",
  "emergencyContactPhone": "+923001234567"
}
```

#### 6. **PUT /api/medical-profiles/{userId}** (Authenticated)
```json
Request Body:
{
  "bloodGroup": "A-",
  "allergies": ["Penicillin"],
  "chronicDiseases": ["Diabetes"],
  "medications": ["Insulin"],
  "disabilities": []
}

Response (200): Updated medical profile
```

### Emergency Endpoints

#### 7. **POST /api/emergencies** (Authenticated Patient)
```json
Request Body:
{
  "emergencyType": "CARDIAC",
  "latitude": 33.6844,
  "longitude": 73.0479,
  "additionalInfo": "Severe chest pain, difficulty breathing"
}

Response (201):
{
  "emergencyId": "uuid",
  "status": "ACTIVE",
  "createdAt": "2026-03-10T10:30:00Z",
  "cancellationDeadline": "2026-03-10T10:30:10Z"  // 10 seconds
}
```

#### 8. **POST /api/emergencies/{emergencyId}/cancel** (Within 10 seconds)
```json
Request Body:
{
  "cancellationReason": "False alarm"
}

Response (200):
{
  "emergencyId": "uuid",
  "status": "CANCELLED",
  "cancelledAt": "2026-03-10T10:30:05Z"
}
```

#### 9. **GET /api/emergencies/{emergencyId}** (Authenticated)
```json
Response (200):
{
  "emergencyId": "uuid",
  "patientId": "uuid",
  "emergencyType": "CARDIAC",
  "status": "ACTIVE",
  "latitude": 33.6844,
  "longitude": 73.0479,
  "patientInfo": {
    "fullName": "Patient Name",
    "phone": "+923001234567",
    "medicalProfile": { ...medical profile... }
  },
  "assignedResponder": {
    "responderId": "uuid",
    "name": "Responder Name",
    "onTheWay": true
  }
}
```

### Responder Endpoints

#### 10. **GET /api/responders/nearby-emergencies** (Authenticated Responder)
```json
Query Params:
- latitude: 33.6844
- longitude: 73.0479
- radius_km: 5

Response (200):
{
  "emergencies": [
    {
      "emergencyId": "uuid",
      "type": "CARDIAC",
      "latitude": 33.6844,
      "longitude": 73.0479,
      "distanceKm": 2.5,
      "estimatedArrivalMinutes": 5,
      "patientName": "Patient Name"
    }
  ]
}
```

#### 11. **POST /api/emergency-requests/{requestId}/accept** (Authenticated Responder)
```json
Response (200):
{
  "emergencyRequestId": "uuid",
  "status": "ACCEPTED",
  "acceptedAt": "2026-03-10T10:31:00Z"
}
```

#### 12. **POST /api/emergency-requests/{requestId}/reject** (Authenticated Responder)
```json
Request Body:
{
  "reason": "Too far away"
}

Response (200):
{
  "emergencyRequestId": "uuid",
  "status": "REJECTED"
}
```

#### 13. **PUT /api/emergency-tracking/{emergencyId}** (Authenticated Responder)
```json
Request Body:
{
  "latitude": 33.6850,
  "longitude": 73.0485,
  "status": "EN_ROUTE"  // or "ARRIVED", "TREATING", "TRANSPORTED"
}

Response (200):
{
  "trackingId": "uuid",
  "timestamp": "2026-03-10T10:32:00Z"
}
```

### Medical Reports Endpoints

#### 14. **GET /api/medical-reports/{userId}** (Authenticated)
```json
Response (200):
{
  "reports": [
    {
      "reportId": "uuid",
      "fileName": "lab_report_march.pdf",
      "reportType": "LAB",
      "downloadUrl": "https://storage.azure.com/...",
      "uploadedAt": "2026-03-10T09:30:00Z"
    }
  ]
}
```

#### 15. **POST /api/medical-reports/upload** (Authenticated)
```
Content-Type: multipart/form-data
- file: [binary file]
- reportType: "LAB"

Response (201):
{
  "reportId": "uuid",
  "fileName": "lab_report.pdf",
  "downloadUrl": "https://storage.azure.com/...",
  "uploadedAt": "2026-03-10T10:33:00Z"
}
```

### Caregiver Endpoints

#### 16. **POST /api/caregivers** (Authenticated Patient)
```json
Request Body:
{
  "caregiverId": "uuid",
  "relationship": "PARENT"
}

Response (201):
{
  "assignmentId": "uuid",
  "caregiverName": "Caregiver Name"
}
```

#### 17. **GET /api/caregivers/my-patients** (Authenticated Caregiver)
```json
Response (200):
{
  "patients": [
    {
      "patientId": "uuid",
      "patientName": "Patient Name",
      "relationship": "PARENT",
      "lastEmergency": {
        "emergencyId": "uuid",
        "type": "CARDIAC",
        "status": "RESOLVED",
        "createdAt": "2026-03-10T09:00:00Z"
      }
    }
  ]
}
```

---

## Authentication & Security

### JWT Token Structure

```
Header:
{
  "alg": "HS256",
  "typ": "JWT"
}

Payload:
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "role": "PATIENT",
  "iat": 1678500000,
  "exp": 1678586400  // 24 hours
}
```

### Security Requirements

1. **HTTPS Only** - All API calls must use HTTPS
2. **Token Injection** - Every request includes `Authorization: Bearer <token>`
3. **Token Expiry** - Access tokens: 24 hours, Refresh tokens: 30 days
4. **Password Hashing** - Use bcrypt with salt rounds ≥ 10
5. **Rate Limiting** - Implement rate limiting (100 requests/minute per IP)
6. **CORS** - Configure CORS for Flutter app origins
7. **Input Validation** - Validate all inputs on backend
8. **SQL Injection** - Use parameterized queries
9. **Error Handling** - Don't expose sensitive info in error messages

### Refresh Token Flow

```
1. User logs in
   → Returns access_token (short-lived) + refresh_token (long-lived)

2. Access token expires
   → App calls POST /api/auth/refresh-token with refresh_token
   → Returns new access_token

3. Refresh token expires
   → App redirects to login screen
```

---

## Real-Time Communication

### WebSocket Connection (SignalR/.NET or Socket.io)

The mobile app expects WebSocket connection for:
- Real-time emergency notifications
- Live location updates
- Emergency status changes
- Request accept/reject responses

#### Connection Setup

```
WebSocket URL: wss://api.medifind.com/ws/notifications

Headers:
- Authorization: Bearer <jwt-token>
- X-User-Id: <user-uuid>
- X-User-Role: <PATIENT|RESPONDER|CAREGIVER>
```

#### Message Types

**1. Notification - Emergency Alert (Server → Responder)**
```json
{
  "type": "EMERGENCY_ALERT",
  "data": {
    "emergencyId": "uuid",
    "emergencyType": "CARDIAC",
    "patientName": "Patient Name",
    "latitude": 33.6844,
    "longitude": 73.0479,
    "distanceKm": 2.5,
    "estimatedArrivalMinutes": 5,
    "messageExpiry": 60  // seconds
  }
}
```

**2. Notification - Location Update (Server → Caregiver/Patient)**
```json
{
  "type": "LOCATION_UPDATE",
  "data": {
    "emergencyId": "uuid",
    "responderId": "uuid",
    "responderName": "Responder Name",
    "latitude": 33.6850,
    "longitude": 73.0485,
    "status": "EN_ROUTE",
    "estimatedArrivalMinutes": 3
  }
}
```

**3. Notification - Status Change**
```json
{
  "type": "EMERGENCY_STATUS_CHANGE",
  "data": {
    "emergencyId": "uuid",
    "newStatus": "RESOLVED",
    "timestamp": "2026-03-10T10:45:00Z"
  }
}
```

**4. Subscription - Subscribe to Emergency (Client → Server)**
```json
{
  "type": "SUBSCRIBE",
  "data": {
    "emergencyId": "uuid"
  }
}
```

**5. Subscription - Subscribe to User (For responder tracking)**
```json
{
  "type": "SUBSCRIBE",
  "data": {
    "userId": "uuid"
  }
}
```

---

## Data Models & Entities

### Frontend Entity Models (Dart/Freezed)

```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String role,  // PATIENT, RESPONDER, CAREGIVER
    String? profileImageUrl,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
class Emergency with _$Emergency {
  const factory Emergency({
    required String id,
    required String patientId,
    required String emergencyType,
    required String status,
    required double latitude,
    required double longitude,
    String? additionalInfo,
    required DateTime createdAt,
    DateTime? resolvedAt,
    DateTime? cancelledAt,
  }) = _Emergency;

  factory Emergency.fromJson(Map<String, dynamic> json) => 
    _$EmergencyFromJson(json);
}

@freezed
class MedicalProfile with _$MedicalProfile {
  const factory MedicalProfile({
    required String id,
    required String userId,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? chronicDiseases,
    List<String>? medications,
    List<String>? disabilities,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DateTime? lastUpdated,
  }) = _MedicalProfile;

  factory MedicalProfile.fromJson(Map<String, dynamic> json) => 
    _$MedicalProfileFromJson(json);
}
```

---

## Integration Points

### 1. **Authentication Flow**
```
App → POST /api/auth/register/login
  ↓
Backend → Validate credentials, hash password
  ↓
Backend → Return JWT + Refresh token
  ↓
App → Stores token in Hive (local secure storage)
  ↓
App → Every request includes token in Authorization header
```

### 2. **Emergency Creation Flow**
```
App (Patient) → POST /api/emergencies
  ↓
Backend → Create emergency record
  ↓
Backend → Get patient's medical profile
  ↓
Backend → Find nearby responders (using geospatial queries)
  ↓
Backend → Send WebSocket notifications to responders
  ↓
Backend → Return emergency ID to app
  ↓
App → Shows 10-second cancellation window
```

### 3. **Responder Assignment Flow**
```
Backend → Identifies nearby responders
  ↓
Backend → Sends emergency request via WebSocket
  ↓
App (Responder) → Displays emergency alert
  ↓
Responder → Accept/Reject via button
  ↓
App → POST /api/emergency-requests/{id}/accept or reject
  ↓
Backend → Updates request status in DB
  ↓
Backend → Sends confirmation via WebSocket to patient & caregiver
```

### 4. **Live Tracking Flow**
```
App (Responder) → Periodic location updates every 5 seconds
  ↓
App → PUT /api/emergency-tracking/{emergencyId}
  ↓
Backend → Updates location in database
  ↓
Backend → Broadcasts via WebSocket to patient & caregivers
  ↓
App (Patient/Caregiver) → Receives update via WebSocket
  ↓
App → Updates map with new responder location
```

---

## Backend Services Required

### 1. **API Server** (ASP.NET Core 8)
- User authentication & authorization
- CRUD operations for all entities
- Location-based queries (nearest responders)
- Real-time WebSocket support
- JWT token validation

### 2. **Database Server** (PostgreSQL)
- Store all user, medical, and emergency data
- Geospatial indexes for location queries
- Transaction support for critical operations
- Backup & replication for data safety

### 3. **Cache Server** (Redis)
- Store active sessions
- Cache medical profiles
- Cache frequently accessed data
- Rate limiting counters

### 4. **WebSocket Server** (SignalR)
- Broadcast emergency alerts
- Send real-time location updates
- Manage subscriptions
- Handle client connections/disconnections

### 5. **Message Queue** (RabbitMQ)
- Queue SMS notifications
- Queue email notifications
- Async task processing
- Remove load from main API

### 6. **File Storage** (Azure Blob Storage)
- Store medical report files
- Store profile pictures
- Return signed URLs for app access

### 7. **SMS Service** (Twilio)
- Emergency SMS alerts (when internet unavailable)
- Backend → Queue message → SMS service
- Used as fallback when app notification fails

### 8. **Email Service** (SendGrid)
- Send password reset emails
- Send medical reports
- Send alerts to caregivers

---

## Development Guidelines

### API Response Format

**Success Response (200, 201):**
```json
{
  "success": true,
  "data": { ... },
  "message": "Operation completed successfully"
}
```

**Error Response (400, 500, etc.):**
```json
{
  "success": false,
  "error": {
    "code": "INVALID_INPUT",
    "message": "Email is required",
    "details": ["email: Email field cannot be empty"]
  }
}
```

### Status Codes

| Code | Usage |
|------|-------|
| 200 | OK - Successful GET/PUT |
| 201 | Created - Successful POST |
| 400 | Bad Request - Invalid input |
| 401 | Unauthorized - Missing/invalid token |
| 403 | Forbidden - Access denied |
| 404 | Not Found - Resource doesn't exist |
| 409 | Conflict - Duplicate record |
| 500 | Server Error - Backend issue |
| 503 | Service Unavailable - Maintenance |

### Pagination

For listing endpoints:
```
GET /api/emergencies?page=1&pageSize=20&sort=createdAt&order=desc

Response:
{
  "items": [...],
  "totalCount": 100,
  "pageNumber": 1,
  "pageSize": 20,
  "totalPages": 5
}
```

### Logging

Log all API calls with:
- Timestamp
- User ID
- Request path
- Request method
- Response status
- Response time
- Error (if any)

### Database Transactions

Use transactions for:
- Emergency creation + responder notification
- Emergency request acceptance + status update
- Payment processing (if added later)

### Geographic Queries

For finding nearby responders (PostGIS):
```sql
SELECT id, name, 
  earth_distance(
    ll_to_earth(latitude, longitude),
    ll_to_earth(:patient_lat, :patient_lon)
  ) / 1000 as distance_km
FROM responders
WHERE is_available = true
ORDER BY distance_km
LIMIT 10;
```

### Performance Tips

1. **Use Connection Pooling** - For database connections
2. **Cache Medical Profiles** - Frequently accessed data
3. **Index Location Columns** - For fast geo-queries
4. **Batch Notifications** - Send multiple via WebSocket
5. **Archive Old Data** - Move resolved emergencies to archive
6. **Use CDN** - For static assets & profile pictures

### Monitoring & Alerts

Monitor these metrics:
- API response time (target: <200ms)
- Database query time (target: <100ms)
- WebSocket connection count
- Active emergencies
- Error rate (target: <0.1%)
- System uptime (target: 99.9%)

---

## Testing Checklist

### Manual Testing (Before Deployment)

- [ ] User registration with different roles
- [ ] Login with valid/invalid credentials
- [ ] Token refresh mechanics
- [ ] Medical profile CRUD
- [ ] Emergency creation and cancellation
- [ ] Responder nearby emergencies query
- [ ] Emergency request accept/reject
- [ ] Location tracking updates
- [ ] WebSocket notifications
- [ ] Caregiver view of patient emergencies
- [ ] File upload (medical reports)

### Automated Testing

- [ ] Unit tests for business logic
- [ ] Integration tests for API endpoints
- [ ] Load testing (simulate 100+ concurrent users)
- [ ] Geo-query performance tests
- [ ] WebSocket connection tests

---

## Environment Setup

### Development Environment Variables

```
DATABASE_URL=postgresql://user:pass@localhost:5432/medifind
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key-here
JWT_EXPIRY=86400  // 24 hours in seconds
CORS_ORIGINS=http://localhost:8080

AZURE_STORAGE_CONNECTION_STRING=...
AZURE_BLOB_CONTAINER=medical-reports

TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=+1...

SENDGRID_API_KEY=...
```

---

## Deployment Checklist

Before going to production:

- [ ] Enable HTTPS/TLS
- [ ] Configure rate limiting
- [ ] Set up database backups
- [ ] Enable logging & monitoring
- [ ] Configure alerting
- [ ] Load balancing setup
- [ ] Security audit completed
- [ ] Performance tests passed
- [ ] Disaster recovery plan ready
- [ ] Team training completed

---

## Contact Points

### Mobile App Connection Details

| Component | What to Provide |
|-----------|-----------------|
| API Base URL | `https://api.medifind.com` |
| WebSocket URL | `wss://api.medifind.com/ws` |
| Auth Endpoint | `/api/auth/login` |
| Emergency Endpoint | `/api/emergencies` |
| Responder Endpoint | `/api/responders` |

### Team Communication

- Backend Team Lead: [To be assigned]
- Frontend Lead: Mobile/Dart expertise
- DevOps Lead: Infrastructure & CI/CD
- Database Admin: PostgreSQL management

---

## Quick Reference

**Key Technologies:**
- Backend: ASP.NET Core 8
- Database: PostgreSQL with PostGIS
- Cache: Redis
- Real-time: WebSocket/SignalR
- Storage: Azure Blob Storage

**API Count:** 17+ endpoints

**Database Tables:** 8 core tables

**Response Time Target:** <200ms

**Uptime Target:** 99.9%

---

**Document Version:** 1.0  
**Last Updated:** March 10, 2026  
**Status:** Complete & Ready for Backend Development
