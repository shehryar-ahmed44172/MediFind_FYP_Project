# Database Schema Documentation

## Overview

The MediFind app uses **Room** (Android JetPack) as the local database. The database contains 3 main tables with relationships to handle the emergency response workflow.

**Database Name:** `medifind_db`  
**Version:** 1  
**Type:** SQLite (encrypted in production)

---

## Entity Diagrams

```
┌─────────────────────┐
│      users          │
├─────────────────────┤
│ PK: id (String)    │
│ email (String)     │
│ fullName (String)  │
│ phoneNumber        │
│ role (String)      │
│ profileImageUrl    │
│ isActive (Boolean) │
│ createdAt          │
└─────────────────────┘
         │
         │ One-to-Many
         │
         ▼
┌──────────────────────────┐
│    emergencies           │
├──────────────────────────┤
│ PK: id (String)         │
│ FK: userId (String)     │
│ status (String)         │
│ emergencyType (String)  │
│ latitude (Double)       │
│ longitude (Double)      │
│ timestamp               │
│ assignedResponderId     │
│ estimatedArrivalTime    │
│ voiceAlertGenerated     │
│ additionalInfo          │
└──────────────────────────┘

┌────────────────────────┐
│  medical_profiles      │
├────────────────────────┤
│ PK: id (String)       │
│ FK: userId (String)   │
│ bloodType (String)    │
│ chronicDiseases (JSON)│
│ allergies (JSON)      │
│ medications (JSON)    │
│ emergencyContacts     │
│ medicalHistory        │
│ lastUpdated           │
└────────────────────────┘
```

---

## Table 1: users

Stores user account information

```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY NOT NULL,
    fullName TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phoneNumber TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL,  -- PATIENT, RESPONDER, ADMIN, CAREGIVER
    profileImageUrl TEXT,
    isActive BOOLEAN NOT NULL DEFAULT 1,
    createdAt TEXT NOT NULL
);
```

### Columns

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PRIMARY KEY | Unique user UUID |
| fullName | String | NOT NULL | User's full name |
| email | String | UNIQUE, NOT NULL | Email address for login |
| phoneNumber | String | UNIQUE, NOT NULL | Contact phone number |
| role | String | NOT NULL | User role (enum as string) |
| profileImageUrl | String | NULLABLE | URL to profile photo |
| isActive | Boolean | NOT NULL, DEFAULT 1 | Account status |
| createdAt | String | NOT NULL | ISO 8601 timestamp |

### Indices

```kotlin
@Entity(
    tableName = "users",
    indices = [
        Index(value = ["email"], unique = true),
        Index(value = ["phoneNumber"], unique = true)
    ]
)
```

### Room Entity Implementation

```kotlin
@Entity(
    tableName = "users",
    indices = [
        Index(value = ["email"], unique = true),
        Index(value = ["phoneNumber"], unique = true)
    ]
)
data class UserEntity(
    @PrimaryKey
    val id: String,
    val fullName: String,
    val email: String,
    val phoneNumber: String,
    val role: String,
    val profileImageUrl: String?,
    val isActive: Boolean = true,
    val createdAt: String
)
```

---

## Table 2: emergencies

Stores emergency request and response data

```sql
CREATE TABLE emergencies (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL,
    status TEXT NOT NULL,  -- TRIGGERED, ASSIGNED, IN_PROGRESS, ON_SITE, COMPLETED, ESCALATED, CANCELLED
    emergencyType TEXT NOT NULL,  -- MEDICAL, FALL, ACCIDENT, ASSAULT, OTHER
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    timestamp TEXT NOT NULL,
    assignedResponderId TEXT,
    estimatedArrivalTime INTEGER,  -- In minutes
    voiceAlertGenerated BOOLEAN DEFAULT 0,
    additionalInfo TEXT,
    FOREIGN KEY (userId) REFERENCES users(id)
);
```

### Columns

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PRIMARY KEY | Emergency UUID |
| userId | String | FOREIGN KEY | Patient who triggered |
| status | String | NOT NULL | Current emergency status |
| emergencyType | String | NOT NULL | Type of emergency |
| latitude | Double | NOT NULL | Patient location latitude |
| longitude | Double | NOT NULL | Patient location longitude |
| timestamp | String | NOT NULL | When emergency occurred |
| assignedResponderId | String | NULLABLE | Assigned responder ID |
| estimatedArrivalTime | Integer | NULLABLE | ETA in minutes |
| voiceAlertGenerated | Boolean | NOT NULL, DEFAULT 0 | Voice alert played? |
| additionalInfo | String | NULLABLE | Additional details |

### Indices

```kotlin
@Entity(
    tableName = "emergencies",
    indices = [
        Index(value = ["userId"]),
        Index(value = ["status"]),
        Index(value = ["timestamp"]),
        Index(value = ["assignedResponderId"])
    ],
    foreignKeys = [
        ForeignKey(
            entity = UserEntity::class,
            parentColumns = ["id"],
            childColumns = ["userId"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
```

### Room Entity Implementation

```kotlin
@Entity(
    tableName = "emergencies",
    indices = [
        Index(value = ["userId"]),
        Index(value = ["status"]),
        Index(value = ["timestamp"]),
        Index(value = ["assignedResponderId"])
    ],
    foreignKeys = [
        ForeignKey(
            entity = UserEntity::class,
            parentColumns = ["id"],
            childColumns = ["userId"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
data class EmergencyEntity(
    @PrimaryKey
    val id: String,
    val userId: String,
    val status: String,
    val emergencyType: String,
    val latitude: Double,
    val longitude: Double,
    val timestamp: String,
    val assignedResponderId: String?,
    val estimatedArrivalTime: Int?,
    val voiceAlertGenerated: Boolean = false,
    val additionalInfo: String?
)
```

---

## Table 3: medical_profiles

Stores patient medical information

```sql
CREATE TABLE medical_profiles (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL UNIQUE,
    bloodType TEXT NOT NULL,
    chronicDiseases TEXT,  -- JSON array
    allergies TEXT,  -- JSON array
    medications TEXT,  -- JSON array of objects
    emergencyContacts TEXT,  -- JSON array of objects
    medicalHistory TEXT,
    lastUpdated TEXT NOT NULL,
    FOREIGN KEY (userId) REFERENCES users(id)
);
```

### Columns

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PRIMARY KEY | Medical profile UUID |
| userId | String | UNIQUE FOREIGN KEY | Patient's user ID |
| bloodType | String | NOT NULL | Blood type (O+, A-, etc.) |
| chronicDiseases | Text | NULLABLE | JSON array of diseases |
| allergies | Text | NULLABLE | JSON array of allergies |
| medications | Text | NULLABLE | JSON array of medications |
| emergencyContacts | Text | NULLABLE | JSON array of contacts |
| medicalHistory | Text | NULLABLE | Long text field |
| lastUpdated | String | NOT NULL | ISO 8601 timestamp |

### JSON Schema Examples

**chronicDiseases:**
```json
[
  "Type 2 Diabetes",
  "Hypertension",
  "COPD"
]
```

**allergies:**
```json
[
  "Penicillin",
  "Aspirin",
  "Shellfish"
]
```

**medications:**
```json
[
  {
    "name": "Metformin",
    "dosage": "500mg",
    "frequency": "Twice daily",
    "reason": "Diabetes management"
  },
  {
    "name": "Lisinopril",
    "dosage": "10mg",
    "frequency": "Once daily",
    "reason": "Hypertension"
  }
]
```

**emergencyContacts:**
```json
[
  {
    "name": "Mary Doe",
    "phoneNumber": "+1-555-0789",
    "relationship": "Spouse"
  },
  {
    "name": "John Smith",
    "phoneNumber": "+1-555-0999",
    "relationship": "Son"
  }
]
```

### Room Entity Implementation

```kotlin
@Entity(
    tableName = "medical_profiles",
    indices = [
        Index(value = ["userId"], unique = true)
    ],
    foreignKeys = [
        ForeignKey(
            entity = UserEntity::class,
            parentColumns = ["id"],
            childColumns = ["userId"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
data class MedicalProfileEntity(
    @PrimaryKey
    val id: String,
    val userId: String,
    val bloodType: String,
    val chronicDiseases: String?,  // JSON string
    val allergies: String?,  // JSON string
    val medications: String?,  // JSON string
    val emergencyContacts: String?,  // JSON string
    val medicalHistory: String?,
    val lastUpdated: String
)
```

---

## Relationships

### One-to-Many: users → emergencies
```
User (1) ──────> (Many) Emergencies
Each user can have multiple emergencies over time.
Cascade delete: When user deleted, all emergencies deleted.
```

### One-to-One: users ↔ medical_profiles
```
User (1) ──────> (1) Medical Profile
Each user has zero or one medical profile.
Cascade delete: When user deleted, medical profile deleted.
```

---

## Query Patterns (DAO Methods)

### UserDao

```kotlin
// Get user by ID
suspend fun getUserById(userId: String): UserEntity?

// Get user by email
suspend fun getUserByEmail(email: String): UserEntity?

// Save/Insert user
suspend fun insertUser(user: UserEntity)

// Update user
suspend fun updateUser(user: UserEntity)

// Delete user
suspend fun deleteUser(user: UserEntity)

// Get all active users
fun getAllActiveUsers(): Flow<List<UserEntity>>
```

### EmergencyDao

```kotlin
// Get emergency by ID
suspend fun getEmergencyById(emergencyId: String): EmergencyEntity?

// Get emergencies by user ID
fun getEmergenciesByUserId(userId: String): Flow<List<EmergencyEntity>>

// Get emergencies by status
fun getEmergenciesByStatus(status: String): Flow<List<EmergencyEntity>>

// Get active emergency for user
suspend fun getActiveEmergencyByUserId(userId: String): EmergencyEntity?

// Insert emergency
suspend fun insertEmergency(emergency: EmergencyEntity)

// Update emergency
suspend fun updateEmergency(emergency: EmergencyEntity)

// Update emergency status
suspend fun updateEmergencyStatus(emergencyId: String, status: String)

// Delete emergency
suspend fun deleteEmergency(emergency: EmergencyEntity)

// Get emergencies with pagination
fun getEmergenciesWithPagination(
    userId: String,
    limit: Int,
    offset: Int
): Flow<List<EmergencyEntity>>
```

### MedicalProfileDao

```kotlin
// Get medical profile by user ID
suspend fun getMedicalProfileByUserId(userId: String): MedicalProfileEntity?

// Insert medical profile
suspend fun insertMedicalProfile(medicalProfile: MedicalProfileEntity)

// Update medical profile
suspend fun updateMedicalProfile(medicalProfile: MedicalProfileEntity)

// Delete medical profile
suspend fun deleteMedicalProfile(medicalProfile: MedicalProfileEntity)

// Get user medical profile as Flow
fun getMedicalProfileByUserIdFlow(userId: String): Flow<MedicalProfileEntity?>
```

---

## Data Integrity

### Constraints

1. **Primary Keys:** All entities have unique IDs
2. **Foreign Keys:** emergencies.userId references users.id
3. **Unique Constraints:** 
   - users.email (unique)
   - users.phoneNumber (unique)
   - medical_profiles.userId (unique, at most one profile per user)
4. **Not Null Constraints:** Critical fields marked NOT NULL
5. **Cascade Delete:** Deleting user cascades to emergencies and medical profiles

### Indices

Indices created on frequently queried columns for performance:
- users.email
- users.phoneNumber
- emergencies.userId
- emergencies.status
- emergencies.timestamp
- emergencies.assignedResponderId
- medical_profiles.userId

---

## Data Migration Strategy

### Version 1 → Version 2 (Future)

```kotlin
val migrationFrom1To2 = object : Migration(1, 2) {
    override fun migrate(database: SupportSQLiteDatabase) {
        // Example additions for future expanding schema
        // database.execSQL("ALTER TABLE users ADD COLUMN role_updated TEXT")
        // etc.
    }
}

Room.databaseBuilder(context, AppDatabase::class.java, "medifind_db")
    .addMigrations(migrationFrom1To2)
    .build()
```

---

## Backup & Recovery

### Automatic Backup (Android 12+)
```xml
<!-- android:allowBackup="true" in AndroidManifest.xml -->
<dataExtractionRules>
    <domain-config>
        <domain includeSubdomains="true">medifind.com</domain>
        <exclude-domain includeSubdomains="true">example.com</exclude-domain>
    </domain-config>
</dataExtractionRules>
```

### Manual Export
```kotlin
// Export database
val dbFile = File(context.getDatabasePath("medifind_db").absolutePath)
// Save to backup location
```

---

## Performance Considerations

### Query Optimization
- Use indices on frequently filtered columns
- Pagination implemented for large result sets
- Use Flow<> for reactive updates
- Batch operations for multiple inserts/updates

### Storage Size
```
Estimated sizes:
- User record: ~200 bytes
- Emergency record: ~300 bytes
- Medical profile: ~500 bytes

Example: 1000 emergencies = ~300KB
```

### Caching Strategy
- Use Room's Flow for automatic cache invalidation
- Keep frequently accessed data in memory
- Implement cache expiration for medical profiles (24 hours)

---

## Security

### Encryption
```kotlin
// Use EncryptedSharedPreferences for sensitive data
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val encryptedDB = Room.databaseBuilder(context, AppDatabase::class.java, "medifind_db")
    .openHelperFactory(FrameworkSQLCipherOpenHelperFactory())
    .build()
```

### Access Control
- Medical profile data requires user authentication
- Emergency data only accessible to patient and assigned responder
- Location data purged after 24 hours

### Audit Logging
```
Future: Implement audit table to track:
- Who accessed what data
- When access occurred
- What changes were made
- IP address / device
```

---

## Database Version Info

```kotlin
@Database(
    entities = [UserEntity::class, EmergencyEntity::class, MedicalProfileEntity::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
    abstract fun emergencyDao(): EmergencyDao
    abstract fun medicalProfileDao(): MedicalProfileDao
}
```
