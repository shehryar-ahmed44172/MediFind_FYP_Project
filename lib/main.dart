// Importing core Flutter material design package
import 'services/call/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Importing Riverpod for state management across the app
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Importing Hive for efficient local database storage
import 'package:hive_flutter/hive_flutter.dart';

// Importing custom routing, configuration, and theme files for the project
import 'config/router.dart';
import 'core/config/app_config.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/providers/accessibility_provider.dart';
// Self-hosted push notifications
import 'services/notification/medifind_push_service.dart';
import 'core/dev/demo_session_loader.dart';
import 'services/notification/battery_optimization_prompt.dart';
import 'services/payments/stripe_init.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/emergency_provider.dart';
import 'services/socket/socket_service.dart';
import 'core/utils/responsive.dart';
import 'presentation/widgets/connectivity_overlay.dart';
import 'presentation/widgets/emergency/deaf_visual_alert_layer.dart';
import 'presentation/screens/guide/guide_gate.dart';
import 'core/utils/app_messenger.dart';
// Added for AppRouter.navigatorKey


// The main entry point of the MediFind application
void main() async {
  // Ensures that widget binding is initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

  // MediFind is a portrait app: rotating the phone must not squeeze the
  // screens into a landscape strip (the Android manifest and iOS plist match).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Hive for local storage (Database setup)
  await Hive.initFlutter();

  // Debug/profile builds only: optional pre-seeded session for emulator walkthroughs
  await DemoSessionLoader.loadIfPresent();

  // Stripe is only needed at checkout: set it up after the first frame
  WidgetsBinding.instance.addPostFrameCallback((_) => StripeInit.ensure().ignore());

  // Running the app wrapped in ProviderScope for Riverpod state management
  runApp(
    const ProviderScope(
      child: MediFindApp(),
    ),
  );
}

/// Widest the app column gets on tablets, web and desktop.
const double _maxAppWidth = 600;

// Root widget of the MediFind application
class MediFindApp extends ConsumerStatefulWidget {
  const MediFindApp({super.key});

  @override
  ConsumerState<MediFindApp> createState() => _MediFindAppState();
}

class _MediFindAppState extends ConsumerState<MediFindApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize AppRouter with provider container for redirects
    AppRouter.setContainer(ProviderScope.containerOf(context, listen: false));
    // Initialize self-hosted push notifications after app mounts
    _setupPushNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foreground: the app handles pushes and fetches missed ones on resume.
    // Background: the Android alert service shows them instead.
    MedifindPushService.onAppLifecycleChanged(state);
  }

  void _setupPushNotifications() async {
    final container = ProviderScope.containerOf(context, listen: false);
    await Future.microtask(() async {
      final localDataSource = await ref.read(localDataSourceProvider.future);

      // Push client: socket `push` events, local notifications, tap routing
      // (including launch from a terminated state).
      await MedifindPushService.initialize(AppRouter.navigatorKey, localDataSource, container);

      // In-app voice/video calls (signalling over the same socket)
      CallService.instance.init(dio: container.read(dioProvider), navigatorKey: AppRouter.navigatorKey);

      // Activate Socket Notification Persistence Handler (Plan v5)
      ref.read(socketNotificationHandlerProvider);
    });

    if (!mounted) return;

    // Listen for auth state changes to connect socket + push delivery (Plan v4.1)
    ref.listenManual(authStateProvider, (previous, next) async {
      final isLoggedIn = next.value ?? false;
      if (isLoggedIn) {
        // 1. Connect Socket.io for In-App Notifications
        final user = await ref.read(currentUserProvider.future);
        final authRepo = await ref.read(authRepositoryProvider.future);
        final jwtToken = await authRepo.getAuthToken();

        if (user != null && jwtToken != null) {
          final socketService = SocketService.instance;
          // updateAuthToken reconnects an existing socket if the token changed
          // (e.g. a new login), so the server always sees the current JWT.
          socketService.updateAuthToken(jwtToken);
          socketService.connect(user.id);
          ref.read(accessibilityProvider.notifier).loadForUser(user.id, user.patientType);

          // 2. Push delivery: fetch missed pushes, start the Android
          //    background alert service, then ask once to allow background use.
          await MedifindPushService.onLoggedIn(user);
          await BatteryOptimizationPrompt.maybeShow(AppRouter.navigatorKey);
        }
      } else {
        // Disconnect if logged out
        SocketService.instance.disconnect();
        ref.read(accessibilityProvider.notifier).loadForUser(null, null);
        // Only a settled "logged out" state stops background alerts (not the
        // initial loading state on app start).
        if (!next.isLoading && !next.hasError) {
          await MedifindPushService.onLoggedOut();
        }
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final accessibilitySettings = ref.watch(accessibilityProvider);

    // Returning MaterialApp with routing capabilities configured
    return MaterialApp.router(
      title: 'MediFind',
      debugShowCheckedModeBanner: AppConfig.showDebugBanner,
      theme: AppTheme.buildTheme(accessibilitySettings),
      darkTheme: AppTheme.buildDarkTheme(accessibilitySettings),
      themeMode: accessibilitySettings.themeMode,
      routerConfig: AppRouter.router,
      scaffoldMessengerKey: AppMessenger.key,
      builder: (context, child) {
        // App-wide font scaling from Accessibility settings (100–150%),
        // applied on top of the OS text scale.
        final mediaQuery = MediaQuery.of(context);
        final systemScale = mediaQuery.textScaler.scale(1.0);
        final scale = (systemScale * accessibilitySettings.fontSizeMultiplier).clamp(1.0, 2.0);

        // Wide screens (tablet, web, desktop): the app is a centred column of
        // phone-like width instead of stretching edge to edge or sitting on one side.
        final width = mediaQuery.size.width;
        final appWidth = width > _maxAppWidth ? _maxAppWidth : width;
        final data = mediaQuery.copyWith(
          textScaler: TextScaler.linear(scale),
          size: Size(appWidth, mediaQuery.size.height),
        );
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: SizedBox(
              width: appWidth,
              child: MediaQuery(
                data: data,
                child: Builder(builder: (context) {
                  // Responsive helpers (wp/hp/sp) measure the app column
                  SizeConfig().init(context);
                  // Non-blocking offline banner + global deaf visual alerts (rendered
                  // above the navigator so they show on full-screen emergency routes).
                  return ConnectivityOverlay(
                    child: DeafVisualAlertLayer(
                      // Opens the welcome tour once per account, from the home
                      // screen only, so it never covers an emergency.
                      child: GuideGate(child: child ?? const SizedBox.shrink()),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

