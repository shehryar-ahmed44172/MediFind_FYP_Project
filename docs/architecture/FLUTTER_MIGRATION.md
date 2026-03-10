# MediFind - Flutter Migration

This document outlines the conversion of the MediFind Android Kotlin project to a Flutter mobile application.

## Project Overview

**MediFind** is an emergency response and healthcare management mobile app that provides:
- User authentication (login/register)
- Emergency SOS features with real-time location tracking
- Medical profile management
- Responder assignment and tracking
- Push notifications
- Caregiver integration

## Kotlin → Flutter Conversion

### Architecture Mapping

```
Kotlin Android                           →    Flutter
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
├─ Activity                            ├─ Screen (Stateless/Stateful Widget)
├─ ViewModel + LiveData               ├─ Riverpod Providers
├─ Repository Pattern                 ├─ Repository Implementation
├─ Hilt Dependency Injection          ├─ Riverpod Providers
├─ Retrofit + Okhttp                  ├─ Dio + Interceptors
├─ Room Database                      ├─ Hive
├─ Jetpack Compose                    ├─ Flutter Material
├─ NavController                      ├─ GoRouter
└─ Permission Handling                └─ permission_handler
```

## Directory Structure

```
lib/
├── config/
│   └── router.dart                  # Route configuration (GoRouter)
├── core/
│   ├── constants/
│   │   └── app_constants.dart        # App-wide constants
│   ├── extensions/
│   │   └── extensions.dart           # Dart extension methods
│   └── utils/
│       ├── exceptions.dart           # Custom exception classes
│       └── utils.dart                # Utility functions
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   └── local_data_source.dart    # Hive database operations
│   │   └── remote/
│   │       └── medifind_api_client.dart  # Dio API client
│   ├── models/                      # Data models from API
│   └── repositories/
│       ├── auth_repository_impl.dart
│       ├── emergency_repository_impl.dart
│       ├── medical_profile_repository_impl.dart
│       └── user_repository_impl.dart
├── domain/
│   ├── entities/                     # Business models (Freezed)
│   │   ├── user.dart
│   │   ├── emergency.dart
│   │   └── medical_profile.dart
│   ├── repositories/                 # Abstract repository interfaces
│   │   ├── auth_repository.dart
│   │   ├── emergency_repository.dart
│   │   ├── medical_profile_repository.dart
│   │   └── user_repository.dart
│   └── usecases/                     # Business logic (optional)
├── presentation/
│   ├── providers/                    # Riverpod state management
│   │   ├── auth_provider.dart
│   │   ├── emergency_provider.dart
│   │   ├── medical_profile_provider.dart
│   │   └── user_provider.dart
│   ├── screens/                      # UI Screens
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── emergency/
│   │   │   ├── emergency_screen.dart
│   │   │   └── emergency_tracking_screen.dart
│   │   ├── profile/
│   │   │   └── user_profile_screen.dart
│   │   ├── medical/
│   │   │   ├── medical_profile_screen.dart
│   │   │   └── edit_medical_profile_screen.dart
│   │   └── widgets/
│   ├── theme/
│   │   └── app_theme.dart           # Material 3 theme
│   └── state/
├── services/
│   ├── location/
│   │   └── location_service.dart    # Location service (Geolocator)
│   ├── notification/
│   │   └── notification_service.dart # Firebase messaging
│   └── audio/
│       └── audio_service.dart       # Audio playback for SOS
└── main.dart
```

## Key Libraries

### State Management
- **riverpod** (2.4.0): Modern, reactive state management
- **flutter_riverpod** (2.4.0): Flutter integration for Riverpod

### Networking
- **dio** (5.3.0): HTTP client with interceptors (replaces Retrofit)
- **web_socket_channel** (2.4.0): WebSocket support for real-time updates

### Local Storage
- **hive** (2.2.0): Fast local NoSQL database (replaces Room)
- **hive_flutter** (1.1.0): Hive integration with Flutter
- **shared_preferences** (2.2.0): Simple key-value storage
- **flutter_secure_storage** (9.0.0): Encrypted secure storage for tokens

### Location & Sensors
- **geolocator** (9.0.0): Location services (replaces Android Location API)
- **location** (5.1.0): Alternative location service
- **permission_handler** (11.4.0): Permission management (replaces Android PermissionX)

### Push Notifications
- **firebase_messaging** (14.6.0): Push notifications (replaces FCM)
- **firebase_core** (2.19.0): Firebase initialization

### UI & Navigation
- **go_router** (12.0.0): Modern declarative routing (replaces NavController)
- **flutter_svg** (2.0.0): SVG asset support
- **cached_network_image** (3.3.0): Image caching

### Serialization & Validation
- **json_annotation** (4.8.0): JSON serialization annotations
- **freezed_annotation** (2.4.0): Data class generation
- **form_builder_validators** (9.1.0): Form validation

### Utilities
- **intl** (0.19.0): Internationalization and date formatting
- **logger** (2.0.0): Logging utility
- **encrypt** (5.0.0): Encryption utilities
- **just_audio** (0.9.0): Audio playback

## Migration Tasks - What's Done

✅ **Completed:**
- Project structure setup
- Domain layer (entities with Freezed)
- Data layer (repositories, data sources)
- API client (Dio-based)
- Local database (Hive)
- Theme system (Material 3)
- State management (Riverpod providers)
- Navigation setup (GoRouter)
- Authentication screens
- Emergency screens
- Medical profile screens
- User profile screens
- Location service
- Notification service
- Audio service
- Core utilities and extensions

## Migration Tasks - What Remains

⚠️ **To Complete:**
1. **Generate Freezed classes:**
   ```bash
   flutter pub run build_runner build
   ```

2. **Setup Firebase:**
   - Add `google-services.json` (Android)
   - Add `GoogleService-Info.plist` (iOS)
   - Configure Firebase in your project

3. **Android Configuration:**
   - Update `AndroidManifest.xml` with required permissions:
     - `INTERNET`
     - `ACCESS_FINE_LOCATION`
     - `ACCESS_COARSE_LOCATION`
     - `POST_NOTIFICATIONS`
     - `FOREGROUND_SERVICE`
     - `FOREGROUND_SERVICE_LOCATION`

4. **iOS Configuration:**
   - Update `Info.plist` with location permissions
   - Configure push notification capabilities

5. **Asset Setup:**
   - Add app logo and icons to `assets/images/`
   - Add SOS and notification sounds to `assets/sounds/`
   - Add fonts to `assets/fonts/`

6. **Screen Enhancement:**
   - Integrate maps (google_maps_flutter or map vector tiles)
   - Add real-time location tracking UI
   - Implement emergency contact management UI
   - Add medication/allergy management UI

7. **Advanced Features:**
   - WebSocket integration for real-time emergency updates
   - Voice call integration (agora_rtc_engine)
   - Video call capabilities
   - PDF export for medical records
   - Push notification handling

8. **Testing:**
   - Unit tests for repositories
   - Widget tests for UI screens
   - Integration tests
   - Mock data setup for testing

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / Xcode
- Firebase project setup

### Installation Steps

```bash
# 1. Get dependencies
flutter pub get

# 2. Generate code (Freezed, JsonSerializable, etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run the app
flutter run

# 4. Run tests (when ready)
flutter test
```

## Key Differences: Kotlin → Dart

| Concept | Kotlin | Dart/Flutter |
|---------|--------|-------------|
| Data Classes | `data class User` | `@freezed class User with _$User` |
| Null Safety | `?` type modifier | `?` type modifier (similar) |
| Sealed Classes | `sealed class` | `@freezed` or `union` packages |
| Extension Functions | `fun String.validate()` | `extension StringExt on String` |
| Coroutines/Async | `suspend fun` | `async/await` & Futures |
| Repository Pattern | Interface + Impl | Class implementing abstract class |
| DI Container | Hilt `@Inject` | Riverpod `Provider` |
| State Management | ViewModel + LiveData | StateNotifier + Riverpod |
| Navigation | NavController + Routes | GoRouter |
| Local Storage | Room Database | Hive |
| HTTP Client | Retrofit | Dio |

## API Integration

The app connects to: `https://api.medifind.com/`

Endpoints implemented:
- `POST /auth/login` - User login
- `POST /auth/register` - User registration
- `POST /auth/refresh` - Token refresh
- `POST /emergencies` - Create emergency
- `GET /emergencies/:id` - Get emergency details
- `GET /users/:id/emergencies` - Get user emergencies
- `PATCH /emergencies/:id/status` - Update emergency status
- `GET /users/:id/medical-profile` - Get medical profile
- `PUT /users/:id/medical-profile` - Update medical profile
- `GET /users/:id` - Get user profile
- `PUT /users/:id` - Update user profile
- `GET /users/search?q=:query` - Search users

## Security Considerations

1. **Token Management:**
   - JWT tokens stored in encrypted shared preferences
   - Auto-refresh on expiration
   - Clear on logout

2. **Data Encryption:**
   - Medical data encrypted locally (Hive with encryption)
   - HTTPS for all API calls
   - TLS 1.2+ required

3. **Permissions:**
   - Location permission checked before use
   - Notification permission requested at startup
   - Proper permission handling with graceful fallbacks

## Testing

Sample test structure:
```dart
// test/data/repositories/auth_repository_test.dart
void main() {
  late MockMediFindApiClient mockApiClient;
  late MockLocalDataSource mockLocalDataSource;
  late AuthRepositoryImpl authRepository;

  setUp(() {
    mockApiClient = MockMediFindApiClient();
    mockLocalDataSource = MockLocalDataSource();
    authRepository = AuthRepositoryImpl(
      apiClient: mockApiClient,
      localDataSource: mockLocalDataSource,
    );
  });

  // Test cases...
}
```

## Future Enhancements

1. **Real-time Features:**
   - WebSocket for live location updates
   - Real-time emergency notifications
   - Live chat with responders

2. **Advanced UI:**
   - Google Maps integration
   - Emergency history charts
   - Medical record PDFs

3. **Accessibility:**
   - Semantic Markdown labels
   - Voice commands
   - High contrast mode

4. **Analytics:**
   - Firebase Analytics integration
   - Crash reporting
   - Performance monitoring

## Troubleshooting

### Build Issues
```bash
# Clean build
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### State Management Issues
- Ensure Riverpod Scope is at top level of app
- Use `.select()` for partial updates
- Invalidate providers appropriately with `.refresh()`

### Database Issues
- Clear Hive boxes: `flutter run --dart-define=HIVE_CLEAR=true`
- Check adapter registration
- Verify type imports

## Performance Tips

1. Use `.select()` on providers to rebuild only affected widgets
2. Implement caching in repositories
3. Use `const` constructors where possible
4. Implement pagination for large lists
5. Use `shouldRebuild()` in StateNotifier

## References

- [Flutter Docs](https://flutter.dev)
- [Riverpod Docs](https://riverpod.dev)
- [Dio Package](https://pub.dev/packages/dio)
- [GoRouter Docs](https://pub.dev/packages/go_router)
- [Hive Docs](https://docs.hivedb.dev)
- [Firebase Flutter](https://firebase.flutter.dev)

---

**Project Status:** Core structure complete, ready for integration and testing

**Last Updated:** February 2026
