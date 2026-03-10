# MediFind Project Structure Visualization

**Visual representation of the organized folder hierarchy**

Generated: March 10, 2026

---

## 🎯 Complete Visual Structure

```
medifind_mobile_application/
│
├─ 📄 Project Files
│  ├─ pubspec.yaml
│  ├─ pubspec.lock  
│  ├─ analysis_options.yaml
│  └─ README.md
│
├─ 📚 Documentation Hub
│  ├─ DOCUMENTATION_INDEX.md ⭐ (START HERE)
│  ├─ FOLDER_HIERARCHY.md
│  ├─ PROJECT_REVIEW_REPORT.md
│  ├─ ISSUES_FIXED.md
│  └─ docs/
│     ├─ architecture/
│     │  ├─ TECH_STACK_AND_ALGORITHMS.md
│     │  └─ FLUTTER_MIGRATION.md
│     ├─ requirements/
│     │  └─ SRS_PROJECT_STATUS.md
│     ├─ database/
│     │  ├─ DATABASE_SCHEMA.md
│     │  ├─ SCHEMA_POSTGRES.md
│     │  └─ QUERIES_POSTGRES.md
│     ├─ usecases/
│     │  ├─ USE_CASE_1_AUTHENTICATION.md
│     │  ├─ USE_CASE_2_SOS_EMERGENCY.md
│     │  ├─ USE_CASE_3_RESPONDER_ASSIGNMENT.md
│     │  ├─ USE_CASE_4_EMERGENCY_TRACKING.md
│     │  ├─ USE_CASE_5_MEDICAL_PROFILE.md
│     │  ├─ USE_CASE_6_CAREGIVER_INTEGRATION.md
│     │  ├─ USE_CASE_7_RESPONDER_OPERATIONS.md
│     │  ├─ USE_CASE_8_NOTIFICATIONS.md
│     │  └─ USE_CASE_9_COMPLETE_LIFECYCLE.md
│     ├─ design/
│     │  └─ DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md
│     └─ FIREBASE_REPLACEMENT_ROADMAP.md
│
├─ 📱 lib/ (Main Application Code)
│  │
│  ├─ main.dart ⭐ (Entry Point)
│  │
│  ├─ 🔌 config/
│  │  └─ router.dart
│  │
│  ├─ ❤️ core/
│  │  ├─ config/
│  │  │  └─ app_config.dart (Dev/Prod Configuration)
│  │  ├─ constants/
│  │  │  └─ app_constants.dart
│  │  ├─ exceptions/
│  │  │  └─ (Custom exception classes)
│  │  ├─ extensions/
│  │  │  └─ extensions.dart
│  │  └─ utils/
│  │     ├─ exceptions.dart
│  │     ├─ utils.dart
│  │     ├─ validators/
│  │     │  └─ (Input validation functions)
│  │     └─ formatters/
│  │        └─ (Data formatting functions)
│  │
│  ├─ 🗄️ data/
│  │  ├─ datasources/
│  │  │  ├─ local/
│  │  │  │  └─ local_data_source.dart
│  │  │  └─ remote/
│  │  │     └─ medifind_api_client.dart
│  │  ├─ models/
│  │  │  ├─ requests/
│  │  │  │  └─ (API request models)
│  │  │  └─ responses/
│  │  │     └─ (API response models)
│  │  └─ repositories/
│  │     ├─ auth_repository_impl.dart
│  │     ├─ emergency_repository_impl.dart
│  │     ├─ medical_profile_repository_impl.dart
│  │     └─ user_repository_impl.dart
│  │
│  ├─ 🧠 domain/
│  │  ├─ entities/
│  │  │  ├─ user.dart (+.freezed.dart, +.g.dart)
│  │  │  ├─ emergency.dart (+.freezed.dart, +.g.dart)
│  │  │  └─ medical_profile.dart (+.freezed.dart, +.g.dart)
│  │  ├─ repositories/
│  │  │  ├─ auth_repository.dart
│  │  │  ├─ emergency_repository.dart
│  │  │  ├─ medical_profile_repository.dart
│  │  │  └─ user_repository.dart
│  │  └─ usecases/
│  │     └─ (Business logic implementations)
│  │
│  ├─ 🎨 presentation/
│  │  ├─ providers/
│  │  │  ├─ auth_provider.dart
│  │  │  ├─ emergency_provider.dart
│  │  │  ├─ medical_profile_provider.dart
│  │  │  ├─ user_provider.dart
│  │  │  ├─ connectivity_provider.dart
│  │  │  └─ accessibility_provider.dart
│  │  ├─ screens/
│  │  │  ├─ auth/
│  │  │  │  ├─ login_screen.dart
│  │  │  │  ├─ register_screen.dart
│  │  │  │  └─ forgot_password_screen.dart
│  │  │  ├─ home/
│  │  │  │  ├─ home_screen.dart
│  │  │  │  └─ patient_type_info_screen.dart
│  │  │  ├─ emergency/
│  │  │  │  ├─ emergency_screen.dart
│  │  │  │  ├─ emergency_tracking_screen.dart
│  │  │  │  └─ sos_countdown_screen.dart
│  │  │  ├─ medical/
│  │  │  │  ├─ medical_profile_screen.dart
│  │  │  │  ├─ edit_medical_profile_screen.dart
│  │  │  │  └─ medical_reports_screen.dart
│  │  │  ├─ profile/
│  │  │  │  └─ user_profile_screen.dart
│  │  │  ├─ responder/
│  │  │  │  ├─ responder_home_screen.dart
│  │  │  │  ├─ emergency_request_screen.dart
│  │  │  │  └─ active_emergency_screen.dart
│  │  │  ├─ caregiver/
│  │  │  │  ├─ caregiver_home_screen.dart
│  │  │  │  ├─ manage_caregivers_screen.dart
│  │  │  │  └─ caregiver_tracking_screen.dart
│  │  │  ├─ settings/
│  │  │  │  └─ accessibility_settings_screen.dart
│  │  │  ├─ debug/
│  │  │  │  └─ developer_menu_screen.dart
│  │  │  └─ widgets/
│  │  │     └─ (Screen-specific widgets)
│  │  ├─ theme/
│  │  │  ├─ app_theme.dart
│  │  │  ├─ colors/
│  │  │  │  └─ (Color scheme definitions)
│  │  │  └─ typography/
│  │  │     └─ (Text style definitions)
│  │  └─ widgets/
│  │     └─ common/
│  │        └─ (Reusable widget components)
│  │
│  └─ 🎵 services/
│     ├─ audio/
│     │  ├─ audio_service.dart
│     │  └─ voice_alert_service.dart
│     ├─ location/
│     │  └─ location_service.dart
│     └─ notification/
│        └─ notification_service.dart
│
├─ 🧪 test/
│  ├─ db_test.dart
│  ├─ widget_test.dart
│  └─ (More tests to be added)
│
├─ 📦 assets/
│  ├─ animations/
│  ├─ fonts/
│  ├─ icons/
│  ├─ images/
│  ├─ logos/
│  └─ sounds/
│
├─ 📱 Platform-Specific Code
│  ├─ android/
│  │  ├─ app/
│  │  │  └─ src/
│  │  ├─ gradle/
│  │  ├─ build.gradle.kts
│  │  └─ settings.gradle.kts
│  ├─ ios/
│  │  ├─ Runner/
│  │  ├─ Runner.xcodeproj/
│  │  └─ Runner.xcworkspace/
│  ├─ macos/
│  │  ├─ Runner/
│  │  └─ Runner.xcodeproj/
│  ├─ windows/
│  │  ├─ CMakeLists.txt
│  │  └─ runner/
│  ├─ linux/
│  │  ├─ CMakeLists.txt
│  │  └─ runner/
│  └─ web/
│     ├─ index.html
│     ├─ manifest.json
│     └─ icons/
│
├─ 🏗️ build/
│  └─ (Auto-generated build artifacts)
│
├─ 📡 .github/
│  └─ workflows/
│     └─ (CI/CD workflow configurations)
│
├─ 🚫 Hidden Directories
│  ├─ .git/
│  ├─ .dart_tool/
│  ├─ .idea/
│  ├─ .metadata
│  ├─ .gitignore
│  └─ .flutter-plugins-dependencies
│
└─ Project Files
   └─ medifind_mobile_application.iml
```

---

## 📊 Architecture Layers

```
┌────────────────────────────────────────────────────────────┐
│                  PRESENTATION LAYER                        │
│  Screens • Widgets • Providers (Riverpod) • Theme          │
│  Path: lib/presentation/                                   │
└──────────────────┬─────────────────────────────────────────┘
                   │ Uses
                   ▼
┌────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                            │
│  Entities • Repository Interfaces • Business Logic         │
│  Path: lib/domain/                                         │
└──────────────────┬─────────────────────────────────────────┘
                   │ Implements
                   ▼
┌────────────────────────────────────────────────────────────┐
│                     DATA LAYER                             │
│  Repositories • DataSources • Models • API Client          │
│  Path: lib/data/                                           │
└──────────────────┬─────────────────────────────────────────┘
                   │ Uses
                   ▼
┌────────────────────────────────────────────────────────────┐
│                     CORE LAYER                             │
│  Utils • Constants • Exceptions • Config                   │
│  Path: lib/core/                                           │
└────────────────────────────────────────────────────────────┘

                   Services Layer (Cross-Cutting)
                   Path: lib/services/
                   (Audio, Location, Notifications)
```

---

## 🎯 Feature Module Structure

Each feature module follows this pattern:

```
screens/
└─ {feature}/
   ├─ {feature}_screen.dart          (Main UI)
   ├─ edit_{feature}_screen.dart     (Edit UI, if needed)
   └─ {feature}_[sub]_screen.dart    (Sub-screens)

providers/
└─ {feature}_provider.dart           (State Management)

domain/entities/
└─ {feature}.dart                    (Business Entity)

domain/repositories/
└─ {feature}_repository.dart         (Interface)

data/repositories/
└─ {feature}_repository_impl.dart    (Implementation)

data/models/
└─ requests/{feature}_request.dart   (API Request)
└─ responses/{feature}_response.dart (API Response)
```

**Example: Authentication Module**
```
screens/auth/
├─ login_screen.dart
├─ register_screen.dart
└─ forgot_password_screen.dart

providers/
└─ auth_provider.dart

domain/entities/
├─ user.dart
└─ auth_response.dart

domain/repositories/
└─ auth_repository.dart

data/repositories/
└─ auth_repository_impl.dart

data/models/requests/
└─ login_request.dart
```

---

## 📋 Documentation Categories

```
docs/
│
├─ architecture/              Technical Design
│  ├─ TECH_STACK_AND_ALGORITHMS.md
│  └─ FLUTTER_MIGRATION.md
│
├─ requirements/              Project Requirements
│  └─ SRS_PROJECT_STATUS.md
│
├─ database/                  Database Documentation
│  ├─ DATABASE_SCHEMA.md
│  ├─ SCHEMA_POSTGRES.md
│  └─ QUERIES_POSTGRES.md
│
├─ usecases/                  Feature Specifications (9 use cases)
│  ├─ USE_CASE_1_AUTHENTICATION.md
│  ├─ USE_CASE_2_SOS_EMERGENCY.md
│  ├─ USE_CASE_3_RESPONDER_ASSIGNMENT.md
│  ├─ USE_CASE_4_EMERGENCY_TRACKING.md
│  ├─ USE_CASE_5_MEDICAL_PROFILE.md
│  ├─ USE_CASE_6_CAREGIVER_INTEGRATION.md
│  ├─ USE_CASE_7_RESPONDER_OPERATIONS.md
│  ├─ USE_CASE_8_NOTIFICATIONS.md
│  └─ USE_CASE_9_COMPLETE_LIFECYCLE.md
│
└─ design/                    Design System
   └─ DESIGN_SYSTEM_AND_LAYOUT_GUIDE.md
```

---

## 🔀 Data Flow

```
User Action in Screen
        ↓
    [Screen Widget]
        ↓
Calls Provider Method
        ↓
  [Riverpod Provider]
        ↓
Calls Repository Method
        ↓
 [Data Repository]
        ↓
    Accesses ────────┬─────────
                     ↓         ↓
              [Local Storage] [API Client]
              (Hive Database) (Dio HTTP)
                     ↓         ↓
              [Local DataSource] [Remote DataSource]
                     ↓         ↓
             Returns Data ────┬─
                              ↓
                    [Repository Logic]
                              ↓
                    [Domain Entity]
                              ↓
                    [State Update]
                              ↓
                    [Screen Rebuilds]
```

---

## ✅ Organization Checklist

- ✅ **Core** - App configuration, constants, utilities organized
- ✅ **Data** - DataSources, Models, Repositories properly structured
- ✅ **Domain** - Entities, Repository interfaces organized
- ✅ **Presentation** - Screens by feature, providers, themes organized
- ✅ **Services** - Audio, Location, Notifications in services layer
- ✅ **Documentation** - All docs in organized `docs/` folder
- ✅ **Assets** - Images, icons, fonts, sounds organized
- ✅ **Platform Code** - Android, iOS, Web, Linux, macOS organized
- ✅ **CI/CD** - `.github/workflows/` ready for pipelines
- ✅ **Navigation** - DOCUMENTATION_INDEX.md and FOLDER_HIERARCHY.md created

---

## 🚀 Quick Start Navigation

```
Want to...                          Go to...
─────────────────────────────────────────────────────────────
... build a new screen?            lib/presentation/screens/
... add a provider?                lib/presentation/providers/
... create a service?              lib/services/
... define a business entity?      lib/domain/entities/
... add API integration?           lib/data/datasources/remote/
... use local storage?             lib/data/datasources/local/
... configure colors/theme?        lib/presentation/theme/
... add utility functions?         lib/core/utils/
... check requirements?            docs/requirements/
... understand use cases?          docs/usecases/
... learn database schema?         docs/database/
... review tech decisions?         docs/architecture/
... understand design system?      docs/design/
... find quick project info?       DOCUMENTATION_INDEX.md
... see complete structure?        FOLDER_HIERARCHY.md
```

---

## 📈 Project Metrics

| Metric | Count |
|--------|-------|
| Total Documentation Files | 15+ |
| Feature Modules | 8 |
| Screens | 20+ |
| Providers | 6+ |
| Services | 3 |
| Entities | 3 |
| Repositories | 4 |
| Platform Targets | 6 (Android, iOS, Web, Windows, Linux, macOS) |

---

**Organization Status: ✅ COMPLETE**  
**Last Updated:** March 10, 2026  
**Total Organized Directories:** 25+

