import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/config/app_config.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/auth/forgot_password_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/emergency/emergency_screen.dart';
import '../presentation/screens/emergency/emergency_tracking_screen.dart';
import '../presentation/screens/emergency/sos_countdown_screen.dart';
import '../presentation/screens/profile/user_profile_screen.dart';
import '../presentation/screens/medical/medical_profile_screen.dart';
import '../presentation/screens/medical/edit_medical_profile_screen.dart';
import '../presentation/screens/medical/medical_reports_screen.dart';
import '../presentation/screens/caregiver/manage_caregivers_screen.dart';
import '../presentation/screens/caregiver/caregiver_home_screen.dart';
import '../presentation/screens/caregiver/caregiver_tracking_screen.dart';
import '../presentation/screens/responder/responder_home_screen.dart';
import '../presentation/screens/responder/emergency_request_screen.dart';
import '../presentation/screens/responder/active_emergency_screen.dart';
import '../presentation/screens/settings/accessibility_settings_screen.dart';
import '../presentation/screens/debug/developer_menu_screen.dart';
import '../presentation/screens/home/patient_type_info_screen.dart';


class AppRouter {
  static final _navigatorKey = GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  static ProviderContainer? _container;

  static void setContainer(ProviderContainer container) {
    _container = container;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _navigatorKey,
    initialLocation: AppConfig.initialRoute,
    redirect: (context, state) {
      // Auth guard — can be enabled/disabled via AppConfig
      // For development, disabled automatically
      return null;
    },
    routes: [
      GoRoute(
        path: '/dev-menu',
        name: 'dev-menu',
        builder: (context, state) => const DeveloperMenuScreen(),
      ),
      // -----------------------------------------------------------------------
      // Auth Routes
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // -----------------------------------------------------------------------
      // Patient Routes
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'emergency',
            name: 'emergency',
            builder: (context, state) => const EmergencyScreen(),
          ),
          GoRoute(
            path: 'sos-countdown',
            name: 'sos-countdown',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return SosCountdownScreen(
                emergencyType: extra['emergencyType'] ?? 'OTHER',
                latitude: (extra['latitude'] as num?)?.toDouble() ?? 0.0,
                longitude: (extra['longitude'] as num?)?.toDouble() ?? 0.0,
                additionalInfo: extra['additionalInfo'],
              );
            },
          ),
          GoRoute(
            path: 'emergency/:emergencyId/tracking',
            name: 'emergency-tracking',
            builder: (context, state) => EmergencyTrackingScreen(
              emergencyId: state.pathParameters['emergencyId']!,
            ),
          ),
          GoRoute(
            path: 'profile',
            name: 'profile',
            builder: (context, state) => const UserProfileScreen(),
          ),
          GoRoute(
            path: 'medical-profile',
            name: 'medical-profile',
            builder: (context, state) => const MedicalProfileScreen(),
          ),
          GoRoute(
            path: 'medical-profile/edit',
            name: 'edit-medical-profile',
            builder: (context, state) => const EditMedicalProfileScreen(),
          ),
          GoRoute(
            path: 'medical-reports',
            name: 'medical-reports',
            builder: (context, state) => const MedicalReportsScreen(),
          ),
          GoRoute(
            path: 'caregivers',
            name: 'caregivers',
            builder: (context, state) => const ManageCaregiversScreen(),
          ),
          GoRoute(
            path: 'settings/accessibility',
            name: 'accessibility',
            builder: (context, state) => const AccessibilitySettingsScreen(),
          ),
          GoRoute(
            path: 'patient-type-info',
            name: 'patient-type-info',
            builder: (context, state) => const PatientTypeInfoScreen(),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Responder Routes
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/responder',
        name: 'responder-home',
        builder: (context, state) => const ResponderHomeScreen(),
        routes: [
          GoRoute(
            path: 'request/:requestId',
            name: 'emergency-request',
            builder: (context, state) => EmergencyRequestScreen(
              requestId: state.pathParameters['requestId']!,
            ),
          ),
          GoRoute(
            path: 'active',
            name: 'active-emergency',
            builder: (context, state) => const ActiveEmergencyScreen(),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Caregiver Routes
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/caregiver',
        name: 'caregiver-home',
        builder: (context, state) => const CaregiverHomeScreen(),
        routes: [
          GoRoute(
            path: 'tracking/:emergencyId',
            name: 'caregiver-tracking',
            builder: (context, state) => CaregiverTrackingScreen(
              emergencyId: state.pathParameters['emergencyId']!,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Text('Page not found: ${state.uri.toString()}'),
      ),
    ),
  );
}
