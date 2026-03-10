# Use Case 1: Authentication & User Management

## Overview
User authentication system handling registration, login, profile management, and logout. Supports role-based access control (Patient, Responder, Caregiver, Admin) with JWT token-based authentication.

---

## Use Case Diagram

```
┌──────────────────────────────────────────────────────┐
│           Authentication & User Management            │
├──────────────────────────────────────────────────────┤
│                                                       │
│  ┌─────────────────────────────────────────────┐   │
│  │ New User / Existing User                     │   │
│  │ (Enter App)                                   │   │
│  └──────────────────┬──────────────────────────┘   │
│                     ▼                               │
│  ┌──────────────────────────────────────────────┐  │
│  │ Check Authentication Status                  │  │
│  │ • Is token valid?                            │  │
│  │ • Is session active?                         │  │
│  │ • Has user logged out?                       │  │
│  └───────┬──────────────────────┬──────────────┘  │
│          │                       │                   │
│      Token Valid            Token Invalid           │
│          │                       │                   │
│          ▼                       ▼                   │
│  ┌──────────────┐    ┌──────────────────────┐      │
│  │ Go to Home   │    │ Either Register or   │      │
│  │ Screen       │    │ Login Existing User  │      │
│  └──────────────┘    └────┬────────┬───────┘      │
│                           │        │                │
│                      New User   Existing User      │
│                           │        │                │
│                  ┌────────▼──┐  ┌─▼──────────┐    │
│                  │ REGISTER  │  │ LOGIN      │    │
│                  └─────┬─────┘  └─┬──────────┘    │
│                        │          │                │
│                  ┌─────▼──────────▼──┐            │
│                  │ Verify Credentials│            │
│                  │ • Email format    │            │
│                  │ • Password strength
│                  │ • Phone format    │            │
│                  │ • Role selection  │            │
│                  └────────┬──────────┘            │
│                           ▼                      │
│                  ┌──────────────────┐            │
│                  │ Create/Update    │            │
│                  │ User Account     │            │
│                  │ with JWT Token   │            │
│                  └────────┬─────────┘            │
│                           ▼                      │
│                  ┌──────────────────┐            │
│                  │ Save Token to    │            │
│                  │ Encrypted Prefs. │            │
│                  └────────┬─────────┘            │
│                           ▼                      │
│                  ┌──────────────────┐            │
│                  │ Navigate to Home │            │
│                  │                  │            │
│                  │ Authenticated ✓  │            │
│                  └──────────────────┘            │
│                                                   │
│  From Home Screen:                               │
│  ┌──────────────────────────────────────────┐   │
│  │ • View Profile (GET /users/{id})         │   │
│  │ • Update Profile (PUT /users/{id})       │   │
│  │ • Change Password                        │   │
│  │ • Logout (DELETE token)                  │   │
│  └──────────────────────────────────────────┘   │
│                                                   │
│  Actors:                                         │
│  • New User (wants to register)                  │
│  • Existing User (wants to login)                │
│  • System (manages authentication)               │
│  • Database (stores user credentials)            │
│  • JWT Engine (generates/validates tokens)       │
└──────────────────────────────────────────────────┘
```

---

## Actors

### Primary Actors
1. **User (New)** - Person creating account
   - Patient, Responder, Caregiver, or Admin
   - No prior account
   - Wants to setup emergency assistance

2. **User (Existing)** - Person with account
   - Returning user
   - Wants to access emergency features
   - May have credentials saved

### Secondary Actors
3. **MediFind Backend Server** - API authentication service
   - Validates credentials
   - Generates JWT tokens
   - Manages sessions

4. **Database** - User data storage
   - Stores user accounts
   - Hashed password storage
   - User profile data

5. **Authentication Service** - Token management
   - JWT generation/validation
   - Token refresh
   - Session management

---

## Use Cases

### UC1.1: User Registration

**Preconditions:**
- User has no existing account
- User has internet connection

**Flow:**
1. User opens app and sees splash screen
2. System checks for authentication token
3. No token found → Redirect to Login/Register screen
4. User taps "Create Account" button
5. Registration form displayed:
   ```
   User Registration Form:
   
   Full Name: [_______________]
   Email: [_______________]
   Phone: [_______________]
   Password: [_______________]
   Confirm Password: [_______________]
   
   Role Selection:
   ○ Patient (needs emergency assistance)
   ○ Responder (can respond to emergencies)
   ○ Caregiver (monitor linked patient)
   
   [Accept Terms] [Create Account]
   ```

6. User fills in form:
   - Full Name: "John Doe"
   - Email: "john@example.com"
   - Phone: "+1-555-0123"
   - Password: "SecurePassword123!"
   - Confirm: "SecurePassword123!"
   - Role: "Patient"

7. Form Validation (Real-time):
   ```
   ✓ Full Name: 3+ characters
   ✓ Email: Valid format (user@domain.com)
   ✗ Email: Must not already exist
   ✓ Phone: Valid format (+1-555-XXXX)
   ✓ Password: 8+ chars, uppercase, lowercase, number, special char
   ✓ Passwords match
   ✓ Role selected
   ✓ Terms accepted
   ```

8. User taps [Create Account]
9. System validates all fields again
10. Request sent to API:
    ```json
    POST /auth/register
    {
      "fullName": "John Doe",
      "email": "john@example.com",
      "phoneNumber": "+1-555-0123",
      "password": "SecurePassword123!",
      "role": "PATIENT"
    }
    ```

11. Backend Hashing (bcrypt):
    ```
    Password Input: "SecurePassword123!"
    Hashed: $2b$12$....(60 character bcrypt hash)
    Stored in DB: Hashed value only (never plaintext)
    ```

12. Check for duplicates:
    ```
    email: "john@example.com" → Already exists?
    → Error: "Email already registered"
    
    OR
    
    email: "unique@example.com" → Available
    → Continue
    ```

13. Create user record:
    ```json
    {
      "id": "user_abc123",
      "fullName": "John Doe",
      "email": "john@example.com",
      "phoneNumber": "+1-555-0123",
      "role": "PATIENT",
      "profileImageUrl": null,
      "isActive": true,
      "createdAt": "2024-02-25T14:35:00Z"
    }
    ```

14. Generate JWT Token:
    ```
    Header: {alg: "HS256", typ: "JWT"}
    Payload: {
      sub: "user_abc123",
      email: "john@example.com",
      role: "PATIENT",
      iat: 1708953300,
      exp: 1708953300 + 172800  // 48 hours
    }
    Signature: HMAC-SHA256(base64(header) + '.' + base64(payload), secret)
    
    Result: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
    ```

15. API Response:
    ```json
    {
      "success": true,
      "message": "User registered successfully",
      "data": {
        "userId": "user_abc123",
        "fullName": "John Doe",
        "email": "john@example.com",
        "phoneNumber": "+1-555-0123",
        "role": "PATIENT",
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "expiresIn": 172800
      }
    }
    ```

16. Token Stored Securely:
    ```kotlin
    val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    
    val encryptedPrefs = EncryptedSharedPreferences.create(
        context, "auth", masterKey,
        PrefKeyEncryptionScheme.AES256_SIV,
        PrefValueEncryptionScheme.AES256_GCM
    )
    encryptedPrefs.edit()
        .putString("auth_token", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
        .putString("user_id", "user_abc123")
        .putString("user_role", "PATIENT")
        .putLong("token_expiry", System.currentTimeMillis() + 172800000)
        .apply()
    ```

17. User navigated to Home Screen
18. Registration Complete ✓

**Error Scenarios:**

**Duplicate Email:**
```json
{
  "success": false,
  "error": "Email already registered",
  "code": "EMAIL_EXISTS"
}
```
→ User shown: "This email is already registered. Please login instead."

**Weak Password:**
```json
{
  "success": false,
  "error": "Password does not meet security requirements",
  "code": "WEAK_PASSWORD"
}
```
→ User shown: "Password must have uppercase, lowercase, number, and special character."

**Postconditions:**
- User account created in database
- Token generated and stored securely
- User authenticated and logged in
- User redirected to Home screen

---

### UC1.2: User Login

**Preconditions:**
- User has existing account
- User not currently authenticated

**Flow:**
1. User opens app with no valid token
2. Splash screen → Redirect to Login
3. Login form displayed:
   ```
   MediFind Login
   
   Email or Phone: [_______________]
   Password: [_______________]
   
   [Forgot Password?] [Login]
   [Create Account]
   ```

4. User enters credentials:
   - Email: "john@example.com"
   - Password: "SecurePassword123!"

5. User taps [Login]
6. Input validation:
   ```
   ✓ Email/Phone: Not empty
   ✓ Email format: Valid (if email)
   ✓ Password: Not empty
   ```

7. API Call:
   ```json
   POST /auth/login
   {
     "email": "john@example.com",
     "password": "SecurePassword123!"
   }
   ```

8. Backend Processing:
   ```
   1. Query database for user by email
      SELECT * FROM users WHERE email = "john@example.com"
   
   2. User found: { id, email, passwordHash, role, ... }
   
   3. Verify password (bcrypt.compare):
      bcrypt.compare("SecurePassword123!", "$2b$12$...")
      → true (passwords match) ✓
   
   4. Check if account active:
      isActive == true ✓
   
   5. Generate JWT token (exp: 48 hours)
   
   6. Return success response
   ```

9. Success Response:
   ```json
   {
     "success": true,
     "message": "Login successful",
     "data": {
       "userId": "user_abc123",
       "fullName": "John Doe",
       "email": "john@example.com",
       "role": "PATIENT",
       "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
       "expiresIn": 172800
     }
   }
   ```

10. Token stored securely (same as registration)

11. User navigated to Home Screen

**Error Scenarios:**

**User Not Found:**
```
Email: "nonexistent@example.com"
Backend: No user found
Response: {
  "error": "Invalid credentials",
  "code": "AUTH_FAILED"
}
```
→ Shown to user: "Email or password incorrect"

**Wrong Password:**
```
Email: "john@example.com"
Password: "WrongPassword123!"
Backend: bcrypt.compare fails
Response: {
  "error": "Invalid credentials",
  "code": "AUTH_FAILED"
}
```
→ Shown to user: "Email or password incorrect"
→ Failed attempt logged (rate limiting after 5 attempts)

**Account Suspended:**
```
Email: "john@example.com"
Backend: isActive == false
Response: {
  "error": "Account suspended",
  "code": "ACCOUNT_SUSPENDED"
}
```
→ Shown to user: "Your account has been suspended. Contact support."

**Rate Limiting:**
```
Consecutive failed attempts: 5
Action: Lock account for 15 minutes
Response: {
  "error": "Too many failed attempts",
  "code": "RATE_LIMITED",
  "retryAfter": 900
}
```

**Postconditions:**
- User authenticated with valid token
- Session active for 48 hours
- User logged in to Home screen

---

### UC1.3: View User Profile

**Preconditions:**
- User authenticated (valid token)
- User logged in

**Flow:**
1. User taps "Profile" from Home menu
2. Navigation to Profile screen
3. System requests profile data:
   ```
   GET /users/user_abc123
   Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

4. Backend Processing:
   ```
   1. Validate token in Authorization header
   2. Extract user ID from token: user_abc123
   3. Verify user can access own profile
   4. Query database: SELECT * FROM users WHERE id = "user_abc123"
   5. Return user data (exclude password hash)
   ```

5. Response:
   ```json
   {
     "success": true,
     "data": {
       "userId": "user_abc123",
       "fullName": "John Doe",
       "email": "john@example.com",
       "phoneNumber": "+1-555-0123",
       "role": "PATIENT",
       "profileImageUrl": "https://api.medifind.com/images/user_abc123.jpg",
       "isActive": true,
       "createdAt": "2024-02-25T14:35:00Z"
     }
   }
   ```

6. Profile Screen displays:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   👤 My Profile
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   
   [Profile Photo]
   
   Name: John Doe
   Email: john@example.com
   Phone: +1-555-0123
   Role: Patient
   Member Since: Feb 25, 2024
   
   Status: ✓ Active
   
   [Edit Profile]
   [Change Password]
   [View Medical Profile]
   [Logout]
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

7. User can:
   - Edit profile information
   - Change password
   - View medical profile
   - Logout

**Postconditions:**
- Profile data displayed
- User can edit if desired

---

### UC1.4: Update User Profile

**Preconditions:**
- User authenticated
- User on profile screen
- User taps [Edit Profile]

**Flow:**
1. Edit mode activated
2. Editable fields:
   ```
   Full Name: [John Doe___________] ✏️
   Phone: [+1-555-0123___________] ✏️
   Profile Photo: [Upload New] ✏️
   
   Non-editable:
   Email: john@example.com (locked)
   Role: Patient (locked)
   ```

3. User updates information:
   - Full Name: "John Michael Doe"
   - Phone: "+1-555-0124"
   - Profile Photo: [Upload new image]

4. Image processing (if changed):
   ```
   1. User selects image from gallery
   2. Compress image (max 2MB)
   3. Resize to 500x500px
   4. Convert to JPEG
   5. Upload to API
   ```

5. Update API Call:
   ```json
   PUT /users/user_abc123
   Authorization: Bearer token
   
   {
     "fullName": "John Michael Doe",
     "phoneNumber": "+1-555-0124",
     "profileImageUrl": "https://api.medifind.com/images/user_abc123_new.jpg"
   }
   ```

6. Backend Processing:
   ```
   1. Validate token
   2. Verify user can edit own profile
   3. Validate new email (if changed):
      - Check for duplicates
      - Verify ownership via confirmation email
   4. Validate new phone:
      - Check format
      - Check for duplicates
   5. Update database:
      UPDATE users SET fullName=?, phoneNumber=?, 
                       profileImageUrl=?, updatedAt=?
                WHERE id=?
   6. Return updated user data
   ```

7. Success Response:
   ```json
   {
     "success": true,
     "message": "Profile updated",
     "data": {
       "userId": "user_abc123",
       "fullName": "John Michael Doe",
       "phoneNumber": "+1-555-0124",
       "profileImageUrl": "https://api.medifind.com/images/user_abc123_new.jpg",
       "updatedAt": "2024-02-25T16:00:00Z"
     }
   }
   ```

8. Profile screen updated with new data
9. Confirmation shown: "Profile updated successfully"

**Error Scenarios:**

**Duplicate Phone:**
```json
{
  "error": "Phone number already in use",
  "code": "PHONE_DUPLICATE"
}
```

**Image Too Large:**
```json
{
  "error": "Image exceeds 2MB limit",
  "code": "FILE_TOO_LARGE"
}
```

**Postconditions:**
- Profile information updated
- Changes persisted in database
- User aware of successful update

---

### UC1.5: Change Password

**Preconditions:**
- User authenticated
- User on profile screen
- User taps [Change Password]

**Flow:**
1. Change Password dialog shown:
   ```
   Current Password: [_______________]
   New Password: [_______________]
   Confirm Password: [_______________]
   
   [Show/Hide password]
   [Cancel] [Change]
   ```

2. User enters:
   - Current: "SecurePassword123!"
   - New: "NewPassword456!@"
   - Confirm: "NewPassword456!@"

3. Validation:
   ```
   ✓ Current password: Not empty
   ✓ New password: 8+ chars, complexity rules
   ✓ Passwords match
   ✓ New != Current
   ```

4. API Call:
   ```json
   PUT /auth/password
   Authorization: Bearer token
   
   {
     "currentPassword": "SecurePassword123!",
     "newPassword": "NewPassword456!@"
   }
   ```

5. Backend Processing:
   ```
   1. Validate token
   2. Get user from token ID
   3. Verify current password (bcrypt):
      bcrypt.compare(currentPassword, user.passwordHash)
      → true ✓
   4. Hash new password:
      newPasswordHash = bcrypt.hash(newPassword, 12)
   5. Update database:
      UPDATE users SET passwordHash=?, updatedAt=?
                WHERE id=?
   6. Invalidate all existing tokens (force re-login)
   7. Generate new token for current session
   ```

6. Success Response:
   ```json
   {
     "success": true,
     "message": "Password changed successfully",
     "data": {
       "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
     }
   }
   ```

7. New token stored securely
8. Confirmation: "Password changed successfully"
9. Other logged-in sessions terminated

**Error Scenarios:**

**Wrong Current Password:**
```json
{
  "error": "Current password is incorrect",
  "code": "PASSWORD_MISMATCH"
}
```

**Weak New Password:**
```json
{
  "error": "New password does not meet security requirements",
  "code": "WEAK_PASSWORD"
}
```

**Postconditions:**
- Password changed in database
- New token issued
- Old tokens invalidated
- User still logged in

---

### UC1.6: Forgot Password / Password Reset

**Preconditions:**
- User has account but forgot password
- User not authenticated

**Flow:**
1. User on Login screen
2. User taps [Forgot Password?]
3. Password Reset form shown:
   ```
   Enter your email to reset password
   
   Email: [_______________]
   
   [Send Reset Link]
   ```

4. User enters email: "john@example.com"
5. Taps [Send Reset Link]
6. API Call:
   ```json
   POST /auth/forgot-password
   
   {
     "email": "john@example.com"
   }
   ```

7. Backend Processing:
   ```
   1. Find user by email
      SELECT * FROM users WHERE email = "john@example.com"
   
   2. If user not found:
      Return generic message (privacy: don't reveal if email exists)
      "If email exists, reset link sent"
   
   3. If user found:
      a. Generate reset token (random + timestamp):
         resetToken = crypto.randomBytes(32).toString('hex')
         tokenExpiry = now + 24 hours
      
      b. Store in database:
         UPDATE users SET resetToken=?, resetTokenExpiry=?
                   WHERE id=?
      
      c. Send email with reset link:
         https://app.medifind.com/reset-password?token=xyz...
         Email body:
         "Click link to reset password (expires in 24 hours)"
      
      d. Return success
   ```

8. Response (same for found/not found):
   ```json
   {
     "success": true,
     "message": "If email exists, reset link has been sent"
   }
   ```

9. User sees: "Check your email for reset instructions"

10. User opens email:
    ```
    Subject: Reset Your MediFind Password
    
    Hi John,
    
    Click the link below to reset your password:
    https://app.medifind.com/reset-password?token=abc123...
    
    This link expires in 24 hours.
    If you didn't request this, ignore.
    
    -MediFind Team
    ```

11. User taps link → Reset Password screen
12. Email verified (token validates)
13. New Password form shown:
    ```
    New Password: [_______________]
    Confirm Password: [_______________]
    
    [Reset Password]
    ```

14. User enters new password: "ResetPassword789!"
15. API Call:
    ```json
    POST /auth/reset-password
    
    {
      "token": "abc123...",
      "newPassword": "ResetPassword789!"
    }
    ```

16. Backend Processing:
    ```
    1. Find user by token:
       SELECT * FROM users WHERE resetToken = "abc123..."
    
    2. Validate token:
       a. Token exists
       b. Token not expired (now < resetTokenExpiry)
       c. One-time use only (set to null after use)
    
    3. Hash new password
    4. Update database:
       UPDATE users SET passwordHash=?, resetToken=NULL,
                        resetTokenExpiry=NULL
             WHERE id=?
    
    5. Clear all active sessions (invalidate old tokens)
    6. Return success
    ```

17. Success: "Password reset successfully. Please login."
18. User redirected to Login screen

**Error Scenarios:**

**Invalid/Expired Token:**
```json
{
  "error": "Reset link expired or invalid",
  "code": "INVALID_TOKEN"
}
```
→ User: "Link expired. Request new reset email."

**Postconditions:**
- Password reset confirmed
- User can login with new password
- Reset token invalidated (one-time use)

---

### UC1.7: Logout

**Preconditions:**
- User authenticated
- User logged in

**Flow:**
1. User taps [Logout] from menu
2. Confirmation dialog shown:
   ```
   Are you sure you want to logout?
   
   [Cancel] [Logout]
   ```

3. User confirms logout
4. API Call (optional - can be local only):
   ```json
   POST /auth/logout
   Authorization: Bearer token
   ```

5. Backend Processing (if API called):
   ```
   1. Validate token
   2. Find active session
   3. Mark session as inactive:
      UPDATE sessions SET isActive=false
                  WHERE userId=? AND token=?
   4. Return success
   ```

6. Local Token Removal:
   ```kotlin
   encryptedPrefs.edit()
       .remove("auth_token")
       .remove("user_id")
       .remove("user_role")
       .remove("token_expiry")
       .apply()
   ```

7. Navigation reset:
   ```
   Clear all back-stack
   Navigate to Login screen
   Splash → Login
   ```

8. User returned to Login screen
9. All local cache cleared
10. Logout complete ✓

**Postconditions:**
- Token deleted locally
- Session marked inactive on backend
- User redirected to Login screen
- App restart requires re-authentication

---

## Data Models

### User (Domain Model)
```kotlin
data class User(
    val id: String,
    val fullName: String,
    val email: String,
    val phoneNumber: String,
    val role: UserRole,
    val profileImageUrl: String?,
    val isActive: Boolean,
    val createdAt: String
)

enum class UserRole {
    PATIENT,      // Needs emergency assistance
    RESPONDER,    // Provides emergency response
    CAREGIVER,    // Monitors linked patient
    ADMIN         // System administrator
}
```

### UserEntity (Room Database)
```kotlin
@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey
    val id: String,
    val fullName: String,
    val email: String,
    val phoneNumber: String,
    val role: String,           // Enum as string
    val profileImageUrl: String?,
    val isActive: Boolean = true,
    val createdAt: String
)
```

### Registration Request
```json
{
  "fullName": "John Doe",
  "email": "john@example.com",
  "phoneNumber": "+1-555-0123",
  "password": "SecurePassword123!",
  "role": "PATIENT"
}
```

### JWT Token Payload
```json
{
  "sub": "user_abc123",
  "email": "john@example.com",
  "role": "PATIENT",
  "iat": 1708953300,
  "exp": 1708953300 + 172800
}
```

---

## Security Implementation

### Password Hashing
```
Algorithm: bcrypt
Cost factor: 12 (salt rounds)
Never store plaintext
Never log passwords
```

### Token Management
```
Algorithm: JWT (HS256)
Expiration: 48 hours
Refresh: Generate new on login
Revocation: Remove locally on logout
Storage: EncryptedSharedPreferences
```

### Session Security
```
Protocol: HTTPS/TLS 1.2+
Headers: Authorization header with Bearer token
Validation: Token signature verified server-side
Rate limiting: 5 failed attempts → 15 min lockout
```

---

## Role-Based Access Control

### PATIENT
```
✓ Trigger SOS emergencies
✓ View own medical profile
✓ View own emergency history
✓ Manage caregivers
✓ View assigned responder
✗ Accept emergencies
✗ View other users' data
```

### RESPONDER
```
✓ Accept emergencies
✓ View assigned patient location
✓ View assigned patient medical profile
✓ Update emergency status
✓ View response history
✗ View inactive patient data
✗ Modify patient data
```

### CAREGIVER
```
✓ View linked patient status
✓ Monitor active emergency
✓ Receive emergency notifications
✓ Access limited medical profile
✗ Modify patient data
✗ View full medical history
```

### ADMIN
```
✓ Access all user data
✓ View analytics
✓ Manage responder qualifications
✓ Suspend accounts
✗ Modify patient data directly
✗ Delete records (archive only)
```

---

## Success Metrics

✅ Registration time: < 3 seconds
✅ Login time: < 2 seconds
✅ Login success rate: 99.5%
✅ Token validation: < 100ms
✅ Password reset email delivery: < 5 minutes
✅ Failed login detection: Immediate
✅ Rate limiting effectiveness: 100%
✅ Session timeout: Automatic after 48 hours
✅ Encryption algorithm compliance: AES-256 + bcrypt
✅ HTTPS/TLS compliance: 100% of API calls

---

## Error Handling

| Error | Cause | User Message |
|-------|-------|--------------|
| INVALID_REQUEST | Missing fields | "Please fill all required fields" |
| EMAIL_EXISTS | Duplicate email | "Email already registered" |
| WEAK_PASSWORD | Password too weak | "Password must meet security requirements" |
| INVALID_CREDENTIALS | Wrong password/email | "Email or password incorrect" |
| ACCOUNT_SUSPENDED | Account disabled | "Account suspended. Contact support" |
| RATE_LIMITED | Too many failed attempts | "Too many attempts. Try in 15 min" |
| NETWORK_ERROR | No connection | "Check internet connection" |
| SERVER_ERROR | Backend issue | "Server error. Try again later" |

---

## Related Use Cases

→ **UC2: SOS Emergency** - Authenticated patient triggers emergency  
→ **UC5: Medical Profile** - User creates medical profile after registration  
→ **UC6: Caregiver Integration** - User links caregivers  
→ **UC7: Responder Operations** - Responder role operations  
→ **UC9: Complete Lifecycle** - Auth required for emergency workflow
