// Importing core Flutter material design package
import 'package:flutter/material.dart';
// Importing Riverpod for state management across the app
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Importing Hive for efficient local database storage
import 'package:hive_flutter/hive_flutter.dart';

// Importing custom routing, configuration, and theme files for the project
import 'config/router.dart';
import 'core/config/app_config.dart';
import 'presentation/theme/app_theme.dart';

// The main entry point of the MediFind application
void main() async {
  // Ensures that widget binding is initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

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
class MediFindApp extends StatelessWidget {
  const MediFindApp({Key? key}) : super(key: key);

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
