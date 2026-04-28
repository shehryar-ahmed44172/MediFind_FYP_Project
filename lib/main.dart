// Importing core Flutter material design package
import 'package:flutter/material.dart';
// Importing Riverpod for state management across the app
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Importing Hive for efficient local database storage
import 'package:hive_flutter/hive_flutter.dart';
// Importing Firebase core and options
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Importing custom routing, configuration, and theme files for the project
import 'config/router.dart';
import 'core/config/app_config.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/providers/accessibility_provider.dart';
// Importing push notification service
import 'services/notification/push_notification_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/emergency_provider.dart';
import 'services/socket/socket_service.dart';
import 'core/utils/responsive.dart';
// Added for AppRouter.navigatorKey


// The main entry point of the MediFind application
void main() async {
  // Ensures that widget binding is initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase First
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive for local storage (Database setup)
  await Hive.initFlutter();

  // Running the app wrapped in ProviderScope for Riverpod state management
  runApp(
    const ProviderScope(
      child: MediFindApp(),
    ),
  );
}

// Root widget of the MediFind application
class MediFindApp extends ConsumerStatefulWidget {
  const MediFindApp({super.key});

  @override
  ConsumerState<MediFindApp> createState() => _MediFindAppState();
}

class _MediFindAppState extends ConsumerState<MediFindApp> {
  @override
  void initState() {
    super.initState();
    // Initialize Push Notifications and FCM Handlers after app mounts
    _setupPushNotifications();
  }

  void _setupPushNotifications() async {
    await Future.microtask(() async {
      // 2. Initialize Push Notification Service (Plan v5: Passed localDataSource)
      final localDataSource = await ref.read(localDataSourceProvider.future);
      if (context.mounted) {
        await PushNotificationService.initialize(AppRouter.navigatorKey, localDataSource);
      }

      // 3. Activate Socket Notification Persistence Handler (Plan v5)
      ref.read(socketNotificationHandlerProvider);
      
      // Fetch the FCM token
      final token = await PushNotificationService.getToken();
      if (token != null) {
        print('\n\n======================================================');
        print('🚀 YOUR FCM DEVICE TOKEN FOR BACKEND TESTING 🚀');
        print(token);
        print('======================================================\n\n');
      }
    });

    // Listen for auth state changes to sync token and connect socket (Plan v4.1)
    ref.listenManual(authStateProvider, (previous, next) async {
      final isLoggedIn = next.value ?? false;
      if (isLoggedIn) {
        // 1. Sync FCM Token
        final token = await PushNotificationService.getToken();
        if (token != null) {
          try {
            await ref.read(updateFcmTokenProvider(token).future);
            debugPrint('✅ FCM Token synced successfully after login');
          } catch (e) {
            debugPrint('❌ Failed to sync FCM Token: $e');
          }
        }

        // 2. Connect Socket.io for In-App Notifications
        final user = await ref.read(currentUserProvider.future);
        final authRepo = await ref.read(authRepositoryProvider.future);
        final jwtToken = await authRepo.getAuthToken();
        
        if (user != null && jwtToken != null) {
          final socketService = SocketService.instance;
          socketService.setAuthToken(jwtToken);
          socketService.connect(user.id);
          debugPrint('🔌 Global Socket.io connection initiated for ${user.fullName}');
        }
      } else {
        // Disconnect if logged out
        SocketService.instance.disconnect();
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    // Initialize responsiveness engine
    SizeConfig().init(context);
    
    final accessibilitySettings = ref.watch(accessibilityProvider);

    // Returning MaterialApp with routing capabilities configured
    return MaterialApp.router(
      title: 'MediFind', // Application title
      debugShowCheckedModeBanner: AppConfig.showDebugBanner, // Controls debug banner visibility
      theme: AppTheme.buildTheme(accessibilitySettings),
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
    );
  }
}

