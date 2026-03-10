# 📚 MediFind Documentation Index

**Quick Navigation to All Project Documentation**

---

## 🚀 Getting Started

### First-Time Setup
1. **[README.md](README.md)** - Project overview and quick start
2. **[FOLDER_HIERARCHY.md](FOLDER_HIERARCHY.md)** - Complete project structure guide
3. **[docs/architecture/TECH_STACK_AND_ALGORITHMS.md](docs/architecture/TECH_STACK_AND_ALGORITHMS.md)** - Technology details

---

## 📊 Project Status & Planning

### Current Status
- **[PROJECT_REVIEW_REPORT.md](PROJECT_REVIEW_REPORT.md)** - Comprehensive project review and assessment
- **[ISSUES_FIXED.md](ISSUES_FIXED.md)** - Bug fixes and resolutions applied
- **[docs/requirements/SRS_PROJECT_STATUS.md](docs/requirements/SRS_PROJECT_STATUS.md)** - Implementation status by module

---

## 🏗️ Architecture & Design

### System Architecture
- **[docs/architecture/TECH_STACK_AND_ALGORITHMS.md](docs/architecture/TECH_STACK_AND_ALGORITHMS.md)**
  - Technology stack overview
  - Riverpod state management
  - Dio HTTP client configuration
  - Database architecture

### Design System
- **[docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md](docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md)**
  - UI/UX guidelines
  - Color schemes
  - Typography
  - Component library

### Migration Documentation
- **[docs/architecture/FLUTTER_MIGRATION.md](docs/architecture/FLUTTER_MIGRATION.md)**
  - Kotlin → Flutter conversion guide
  - Architecture mapping
  - Directory structure
  - Development patterns

---

## 💾 Database Documentation

### Schema & Queries
- **[docs/database/DATABASE_SCHEMA.md](docs/database/DATABASE_SCHEMA.md)** - Complete database schema
- **[docs/database/SCHEMA_POSTGRES.md](docs/database/SCHEMA_POSTGRES.md)** - PostgreSQL schema details
- **[docs/database/QUERIES_POSTGRES.md](docs/database/QUERIES_POSTGRES.md)** - Sample PostgreSQL queries

---

## 📋 Use Case Documentation

### All Use Cases (9 total - Now in docs/usecases/)

#### 1. Authentication & Account Management
- **[docs/usecases/USE_CASE_1_AUTHENTICATION.md](docs/usecases/USE_CASE_1_AUTHENTICATION.md)**
  - User registration
  - Login workflows
  - Password reset
  - Role-based access

#### 2. SOS Emergency & Cancellation
- **[docs/usecases/USE_CASE_2_SOS_EMERGENCY.md](docs/usecases/USE_CASE_2_SOS_EMERGENCY.md)**
  - Emergency trigger mechanism
  - 10-second cancellation window
  - Location capture
  - Emergency categorization

#### 3. Responder Assignment
- **[docs/usecases/USE_CASE_3_RESPONDER_ASSIGNMENT.md](docs/usecases/USE_CASE_3_RESPONDER_ASSIGNMENT.md)**
  - Nearest responder matching
  - Assignment algorithm
  - Response acceptance/rejection
  - Escalation workflow

#### 4. Emergency Tracking
- **[docs/usecases/USE_CASE_4_EMERGENCY_TRACKING.md](docs/usecases/USE_CASE_4_EMERGENCY_TRACKING.md)**
  - Real-time location tracking
  - Map visualization
  - ETA calculation
  - Live status updates

#### 5. Medical Profile Management
- **[docs/usecases/USE_CASE_5_MEDICAL_PROFILE.md](docs/usecases/USE_CASE_5_MEDICAL_PROFILE.md)**
  - Medical history
  - Allergies & medications
  - Chronic diseases
  - Disability information

#### 6. Caregiver Integration
- **[docs/usecases/USE_CASE_6_CAREGIVER_INTEGRATION.md](docs/usecases/USE_CASE_6_CAREGIVER_INTEGRATION.md)**
  - Caregiver assignment
  - Read-only monitoring
  - Emergency notifications
  - Patient management

#### 7. Responder Operations
- **[docs/usecases/USE_CASE_7_RESPONDER_OPERATIONS.md](docs/usecases/USE_CASE_7_RESPONDER_OPERATIONS.md)**
  - Responder dashboard
  - Emergency requests
  - Patient information access
  - Status updates

#### 8. Notifications & Alerts
- **[docs/usecases/USE_CASE_8_NOTIFICATIONS.md](docs/usecases/USE_CASE_8_NOTIFICATIONS.md)**
  - Push notifications
  - Voice alerts
  - SMS fallback
  - Email notifications

#### 9. Complete Lifecycle
- **[docs/usecases/USE_CASE_9_COMPLETE_LIFECYCLE.md](docs/usecases/USE_CASE_9_COMPLETE_LIFECYCLE.md)**
  - End-to-end emergency flow
  - Full patient journey
  - Resolution & follow-up
  - Data persistence

---

## 🔄 Technical Roadmaps

### Firebase Replacement
- **[FIREBASE_REPLACEMENT_ROADMAP.md](FIREBASE_REPLACEMENT_ROADMAP.md)**
  - Push notifications replacement
  - Custom WebSocket implementation
  - Redis message queue
  - Authentication token management

---

## 📁 Project Structure

### Detailed Hierarchy
- **[FOLDER_HIERARCHY.md](FOLDER_HIERARCHY.md)** - Complete folder organization

### Key Directories

#### lib/
```
lib/
├── config/                 # App routing
├── core/                   # Constants, utils, exceptions
├── data/                   # Repositories, data sources
├── domain/                 # Business entities
├── presentation/           # UI screens & state management
└── services/               # Cross-cutting services
```

#### docs/
```
docs/
├── architecture/          # Tech stack & migration
├── requirements/          # SRS & project status
├── database/             # Schema & queries
├── usecases/             # All 9 use cases
└── design/               # Design system
```

---

## 🎯 Navigation by Role

### 👨‍💻 Frontend Developer
**What you need to know:**
1. [FOLDER_HIERARCHY.md](FOLDER_HIERARCHY.md) - Project structure
2. [docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md](docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md) - UI guidelines
3. [docs/architecture/FLUTTER_MIGRATION.md](docs/architecture/FLUTTER_MIGRATION.md) - Flutter patterns
4. Specific use case docs for features you're building

### 🏗️ Backend Developer
**What you need to know:**
1. [docs/database/DATABASE_SCHEMA.md](docs/database/DATABASE_SCHEMA.md) - Database structure
2. [docs/database/QUERIES_POSTGRES.md](docs/database/QUERIES_POSTGRES.md) - Query examples
3. [FIREBASE_REPLACEMENT_ROADMAP.md](FIREBASE_REPLACEMENT_ROADMAP.md) - Backend services
4. All use case docs for API requirements

### 📊 Project Manager
**What you need to know:**
1. [PROJECT_REVIEW_REPORT.md](PROJECT_REVIEW_REPORT.md) - Current status
2. [docs/requirements/SRS_PROJECT_STATUS.md](docs/requirements/SRS_PROJECT_STATUS.md) - Module status
3. [ISSUES_FIXED.md](ISSUES_FIXED.md) - Recent fixes
4. [docs/usecases/](docs/usecases/) - All functionality specs

### 🎨 Designer
**What you need to know:**
1. [docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md](docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md) - Design system
2. [docs/architecture/FLUTTER_MIGRATION.md](docs/architecture/FLUTTER_MIGRATION.md) - Screen organization
3. Specific use case docs for features you're designing

### 🧪 QA/Tester
**What you need to know:**
1. [docs/requirements/SRS_PROJECT_STATUS.md](docs/requirements/SRS_PROJECT_STATUS.md) - What's implemented
2. [docs/usecases/](docs/usecases/) - Feature specifications
3. [PROJECT_REVIEW_REPORT.md](PROJECT_REVIEW_REPORT.md) - Known issues
4. [ISSUES_FIXED.md](ISSUES_FIXED.md) - Recent fixes to verify

---

## 📈 Documentation Maintenance

### How to Update Documentation
1. **Outdated Info?** Update the relevant doc in `docs/` folder
2. **New Feature?** Create new file in appropriate `docs/` category
3. **Bug Fix?** Update [ISSUES_FIXED.md](ISSUES_FIXED.md)
4. **Code Changes?** Update [PROJECT_REVIEW_REPORT.md](PROJECT_REVIEW_REPORT.md)

### File Organization Rules
```
Use Case Documentation  → docs/usecases/
Architecture Docs      → docs/architecture/
Database Docs         → docs/database/
Design Docs           → docs/design/
Requirements Docs     → docs/requirements/
Implementation Docs   → Root level (ISSUES_FIXED.md, etc.)
Project Overview      → Root level (README.md, FOLDER_HIERARCHY.md)
```

---

## 🔗 Quick Links

| Document | Purpose | Updated |
|----------|---------|---------|
| [README.md](README.md) | Project overview | - |
| [FOLDER_HIERARCHY.md](FOLDER_HIERARCHY.md) | Project structure | ✅ Mar 10, 2026 |
| [PROJECT_REVIEW_REPORT.md](PROJECT_REVIEW_REPORT.md) | Full project review | ✅ Mar 10, 2026 |
| [ISSUES_FIXED.md](ISSUES_FIXED.md) | Bug fixes applied | ✅ Mar 10, 2026 |
| [docs/](docs/) | All documentation | ✅ Mar 10, 2026 |

---

## 📞 Need Help Finding Something?

### By Topic
- **Flutter Setup** → [docs/architecture/FLUTTER_MIGRATION.md](docs/architecture/FLUTTER_MIGRATION.md)
- **Database Schema** → [docs/database/DATABASE_SCHEMA.md](docs/database/DATABASE_SCHEMA.md)
- **UI Design** → [docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md](docs/design/DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md)
- **Feature Specs** → [docs/usecases/](docs/usecases/) (pick specific use case)
- **Tech Stack** → [docs/architecture/TECH_STACK_AND_ALGORITHMS.md](docs/architecture/TECH_STACK_AND_ALGORITHMS.md)
- **Project Status** → [PROJECT_REVIEW_REPORT.md](PROJECT_REVIEW_REPORT.md)
- **What's Fixed** → [ISSUES_FIXED.md](ISSUES_FIXED.md)

### By Role
- **Frontend** → See "Navigation by Role" section above
- **Backend** → See "Navigation by Role" section above
- **Design** → See "Navigation by Role" section above
- **QA** → See "Navigation by Role" section above

---

**Last Updated:** March 10, 2026  
**Total Documents:** 15+  
**Organization Status:** ✅ Complete
