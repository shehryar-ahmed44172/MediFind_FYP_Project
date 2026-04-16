# MediFind API Integration Guide

This guide provides all the necessary endpoints and integration details required to connect the Flutter mobile application to the MediFind backend.

## 🔑 Authentication
All protected routes require an `Authorization` header with a Bearer token:
`Authorization: Bearer <YOUR_ACCESS_TOKEN>`

---

## 🛠️ API Modules & Endpoints

### 1. Authentication & Identity (`/api/auth`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| POST | `/register` | User registration (Patient/Responder/Caregiver) |
| POST | `/login` | User login (returns tokens) |
| POST | `/refresh-token` | Obtain a new access token using a refresh token |
| POST | `/logout` | Revoke refresh tokens |
| GET | `/me` | Get current authenticated user profile |
| PUT | `/fcm-token` | Update device FCM token for push notifications |

### 2. User Management (`/api/users`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| GET | `/profile` | Get user profile details |
| PUT | `/profile` | Update profile (Name, Phone, Image) |
| PATCH | `/upgrade` | **[PATIENT]** Upgrade subscription plan (Professional/Executive) |
| PATCH | `/:id/verify` | **[ADMIN]** Manual responder activation |

### 3. Emergency SOS (`/api/emergencies`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| POST | `/` | **[PATIENT]** Trigger a new SOS alert |
| GET | `/` | **[RESPONDER/ADMIN]** List all active emergencies |
| GET | `/:id` | Get full details of a specific emergency |
| POST | `/:id/cancel` | **[PATIENT]** Cancel SOS (within 10s window) |

### 4. Responder Actions (`/api/responders`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| POST | `/location` | Update responder's current GPS coordinates |
| PATCH | `/availability` | Toggle responder availability (Online/Offline) |
| POST | `/emergencies/:id/accept` | Accept an active SOS assignment |
| POST | `/emergencies/:id/reject` | Reject/Ignore an SOS request |
| POST | `/emergencies/:id/resolve` | Mark emergency as completed/resolved |
| GET | `/nearby` | Find responders within a specific radius |

### 5. Caregiver Management (`/api/caregivers`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| POST | `/link` | **[PATIENT]** Send invitation to a caregiver email |
| GET | `/` | List currently linked caregivers/patients |
| GET | `/invitations` | **[CAREGIVER]** View pending invitations |
| POST | `/invitations/:id/respond` | **[CAREGIVER]** Accept/Reject invitation |
| DELETE | `/:id` | **[PATIENT]** Remove a linked caregiver |

### 6. Medical Data (`/api/profile` & `/api/reports`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| GET | `/profile/` | Get patient medical history/profile |
| PUT | `/profile/` | Update medical profile (Vitals, Allergies) |
| POST | `/reports/:id` | Upload medical report for a specific SOS |
| GET | `/reports/:id` | Retrieve reports for an emergency |

### 7. Real-time Tracking (`/api/tracking`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| POST | `/` | **[RESPONDER]** Submit live location during active SOS |
| GET | `/:emergencyId` | Get historical path of responder for an SOS |
| GET | `/:emergencyId/latest` | Get the single latest position of the responder |

---

## 📡 Live Socket.io Events
The backend uses **Socket.io** for real-time updates.
- **Connect URL**: `http://<your-server-ip>:3000`
- **Room Join**: `socket.emit('join', 'emergency:<emergencyId>')`

| Event Name | Direction | Description |
| :--- | :--- | :--- |
| `NEW_EMERGENCY` | Server -> Responder | Alert nearby responders of a new SOS |
| `RESPONDER_LOCATION_UPDATE` | Server -> Everyone | Live GPS movement on the map |
| `EMERGENCY_STATUS_CHANGE` | Server -> Everyone | SOS updated to Assigned/Resolved/Cancelled |
| `RESPONDER_ARRIVED` | Server -> Patient | Notification that help is on-site |

---

## 📦 Deployment Strategy

### Quick Testing (Mock)
Use **Ngrok** to expose your local 3000 port:
`ngrok http 3000`
Then use the Ngrok URL in your Flutter `baseUrl`.

### Production Hardware
1. **Backend Host**: [Render.com](https://render.com) or [Railway.app](https://railway.app) (Direct GitHub integration).
2. **Database**: [Supabase](https://supabase.com) (PostgreSQL with PostGIS for location).
3. **Storage**: [Firebase Storage](https://firebase.google.com/products/storage) for CNIC and Medical Report images.

> [!TIP]
> **Environment Variables Checklist**:
> Ensure these variables are set on your deployment platform:
> - `DATABASE_URL`: Your PostgreSQL connection string.
> - `JWT_SECRET`: A long random string for auth.
> - `PORT`: Default 3000.
