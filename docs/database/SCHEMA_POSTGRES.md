# MediFind PostgreSQL Database Schema

This document defines the server-side database schema for the MediFind application.

## 1. Tables

### `users`
Stores user profile and account status.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(50)` | `PRIMARY KEY` | UUID or custom ID |
| `fullName` | `VARCHAR(100)` | `NOT NULL` | User's full name |
| `email` | `VARCHAR(100)` | `NOT NULL, UNIQUE` | Login email |
| `phoneNumber` | `VARCHAR(20)` | `NOT NULL, UNIQUE` | Contact number |
| `role` | `VARCHAR(20)` | `NOT NULL` | PATIENT, RESPONDER, CAREGIVER, ADMIN |
| `patientType` | `VARCHAR(20)` | `NULL` | NORMAL, DEAF |
| `organization` | `VARCHAR(100)` | `NULL` | For Responders |
| `licenseNumber` | `VARCHAR(50)` | `NULL` | For Responders |
| `responderType` | `VARCHAR(50)` | `NULL` | PARAMEDIC, DOCTOR, etc. |
| `vehicleType` | `VARCHAR(30)` | `NULL` | AMBULANCE, PERSONAL, NONE |
| `profileImageUrl` | `TEXT` | `NULL` | URL to avatar |
| `isActive` | `BOOLEAN` | `DEFAULT TRUE` | Account status |
| `createdAt` | `TIMESTAMP` | `DEFAULT NOW()` | Record creation time |

### `medical_profiles`
Sensitive patient medical data linked to a user.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(50)` | `PRIMARY KEY` | Profile ID |
| `userId` | `VARCHAR(50)` | `UNIQUE, REFERENCES users(id)` | Linked Patient |
| `bloodType` | `VARCHAR(10)` | `NOT NULL` | O+, A-, etc. |
| `chronicDiseases` | `JSONB` | `DEFAULT '[]'` | List of conditions |
| `allergies` | `JSONB` | `DEFAULT '[]'` | List of allergies |
| `medications` | `JSONB` | `DEFAULT '[]'` | List of medications |
| `emergencyContacts` | `JSONB` | `DEFAULT '[]'` | List of contacts |
| `medicalHistory` | `TEXT` | `NULL` | Long-form history |
| `lastUpdated` | `TIMESTAMP` | `DEFAULT NOW()` | Last modification |

### `emergencies`
Logs of all emergency triggers and responses.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(50)` | `PRIMARY KEY` | Incident ID |
| `userId` | `VARCHAR(50)` | `REFERENCES users(id)` | Patient ID |
| `status` | `VARCHAR(30)` | `NOT NULL` | TRIGGERED, ASSIGNED, etc. |
| `emergencyType` | `VARCHAR(30)` | `NOT NULL` | MEDICAL, FALL, etc. |
| `latitude` | `DOUBLE PRECISION` | `NOT NULL` | Incident Latitude |
| `longitude` | `DOUBLE PRECISION` | `NOT NULL` | Incident Longitude |
| `timestamp` | `TIMESTAMP` | `DEFAULT NOW()` | Incident trigger time |
| `assignedResponderId` | `VARCHAR(50)` | `REFERENCES users(id)` | Assigned Responder |
| `estimatedArrivalTime` | `INTEGER` | `NULL` | Minutes to arrival |
| `voiceAlertGenerated` | `BOOLEAN` | `DEFAULT FALSE` | Has system alerted? |
| `additionalInfo` | `TEXT` | `NULL` | Incident notes |

### `responders_tracking`
Live location and availability tracking for responders.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(50)` | `PRIMARY KEY, REFERENCES users(id)` | Responder ID |
| `fullName` | `VARCHAR(100)` | `NOT NULL` | Responder's Name |
| `phoneNumber` | `VARCHAR(20)` | `NOT NULL` | Contact number |
| `latitude` | `DOUBLE PRECISION` | `NOT NULL` | Current lat |
| `longitude` | `DOUBLE PRECISION` | `NOT NULL` | Current lon |
| `status` | `VARCHAR(30)` | `DEFAULT 'AVAILABLE'` | AVAILABLE, BUSY |
| `isActive` | `BOOLEAN` | `DEFAULT TRUE` | Is on duty? |
| `lastUpdated` | `TIMESTAMP` | `DEFAULT NOW()` | Last ping |

## 2. SQL DDL Script

```sql
-- MediFind PostgreSQL Schema

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(50) PRIMARY KEY,
    fullName VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phoneNumber VARCHAR(20) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL,
    patientType VARCHAR(20),
    organization VARCHAR(100),
    licenseNumber VARCHAR(50),
    responderType VARCHAR(50),
    vehicleType VARCHAR(30),
    profileImageUrl TEXT,
    isActive BOOLEAN NOT NULL DEFAULT TRUE,
    createdAt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS medical_profiles (
    id VARCHAR(50) PRIMARY KEY,
    userId VARCHAR(50) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    bloodType VARCHAR(10) NOT NULL,
    chronicDiseases JSONB DEFAULT '[]',
    allergies JSONB DEFAULT '[]',
    medications JSONB DEFAULT '[]',
    emergencyContacts JSONB DEFAULT '[]',
    medicalHistory TEXT,
    lastUpdated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS emergencies (
    id VARCHAR(50) PRIMARY KEY,
    userId VARCHAR(50) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL,
    emergencyType VARCHAR(30) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    assignedResponderId VARCHAR(50) REFERENCES users(id),
    estimatedArrivalTime INTEGER,
    voiceAlertGenerated BOOLEAN DEFAULT FALSE,
    additionalInfo TEXT
);

CREATE INDEX idx_emergency_user ON emergencies(userId);
CREATE INDEX idx_emergency_status ON emergencies(status);
CREATE INDEX idx_medical_user ON medical_profiles(userId);

CREATE TABLE IF NOT EXISTS responders_tracking (
    id VARCHAR(50) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    fullName VARCHAR(100) NOT NULL,
    phoneNumber VARCHAR(20) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    status VARCHAR(30) DEFAULT 'AVAILABLE',
    isActive BOOLEAN DEFAULT TRUE,
    lastUpdated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_responder_status ON responders_tracking(status, isActive);
```
