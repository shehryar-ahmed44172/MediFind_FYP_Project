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
// Importing push notification service
import 'services/notification/push_notification_service.dart';

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
class MediFindApp extends StatefulWidget {
  const MediFindApp({Key? key}) : super(key: key);

  @override
  State<MediFindApp> createState() => _MediFindAppState();
}

class _MediFindAppState extends State<MediFindApp> {
  @override
  void initState() {
    super.initState();
    // Initialize Push Notifications and FCM Handlers after app mounts
    PushNotificationService.initialize(context);
  }

  @override
  Widget build(BuildContext context) {
    // Returning MaterialApp with routing capabilities configured
    return MaterialApp.router(
      title: 'MediFind', // Application title
      debugShowCheckedModeBanner: AppConfig.showDebugBanner, // Controls debug banner visibility
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
    );
  }
}

