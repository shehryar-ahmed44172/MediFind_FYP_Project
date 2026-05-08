import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Importing GoRouter for handling app navigation and routing
import 'package:go_router/go_router.dart';
import '../core/config/app_config.dart';

// Importing all the necessary screens for different app modules
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/auth/role_selection_screen.dart';
import '../presentation/screens/auth/forgot_password_screen.dart';
import '../presentation/screens/auth/email_verification_screen.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/emergency/emergency_screen.dart';
import '../presentation/screens/emergency/emergency_tracking_screen.dart';
import '../presentation/screens/emergency/sos_countdown_screen.dart';
import '../presentation/screens/profile/user_profile_screen.dart';
import '../presentation/screens/profile/edit_profile_screen.dart';
import '../presentation/screens/medical/medical_profile_screen.dart';
import '../presentation/screens/medical/edit_medical_profile_screen.dart';
import '../presentation/screens/medical/medical_reports_screen.dart';
import '../presentation/screens/caregiver/manage_caregivers_screen.dart';
import '../presentation/screens/caregiver/caregiver_home_screen.dart';
import '../presentation/screens/caregiver/caregiver_tracking_screen.dart';
import '../presentation/screens/caregiver/link_patient_screen.dart';
import '../presentation/screens/caregiver/caregiver_map_screen.dart';
import '../presentation/screens/caregiver/my_patients_screen.dart';
import '../presentation/screens/caregiver/caregiver_history_screen.dart';
import '../presentation/screens/responder/responder_home_screen.dart';
import '../presentation/screens/responder/emergency_request_screen.dart';
import '../presentation/screens/responder/active_emergency_screen.dart';
import '../presentation/screens/settings/diagnostics_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/home/patient_shell.dart';
import '../presentation/screens/home/patient_type_info_screen.dart';
import '../presentation/screens/medical/emergency_contacts_screen.dart';

import '../presentation/screens/home/caregiver_shell.dart';
import '../presentation/screens/home/responder_shell.dart';
import '../presentation/screens/chat/chat_list_screen.dart';
import '../presentation/screens/chat/chat_detail_screen.dart';
import '../presentation/screens/responder/responder_history_screen.dart';
import '../presentation/screens/settings/subscription_plans_screen.dart';
import '../presentation/screens/settings/checkout_screen.dart';
import '../presentation/screens/settings/payment_success_screen.dart';
import '../presentation/screens/patient/predefined_messages_screen.dart';
import '../presentation/screens/auth/pending_approval_screen.dart';

// AppRouter class manages all the navigation paths within the app
class AppRouter {
  // Global key to access navigator state from anywhere
  static final _navigatorKey = GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  static ProviderContainer? _container;

  // Method to set the ProviderContainer for dependency injection
  static void setContainer(ProviderContainer container) {
    _container = container;
  }

  // Helper for modern transitions
  static Page<dynamic> _modernPageTransition({
    required LocalKey key,
    required Widget child,
    bool slideUp = false,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        if (slideUp) {
          return SlideTransition(
            position: curve.drive(Tween(begin: const Offset(0, 0.1), end: Offset.zero)),
            child: FadeTransition(opacity: curve, child: child),
          );
        }
        return FadeTransition(opacity: curve, child: child);
      },
    );
  }

  // Main GoRouter configuration
  static final GoRouter router = GoRouter(
    navigatorKey: _navigatorKey,
    initialLocation: AppConfig.initialRoute,
    refreshListenable: _container != null 
        ? GoRouterRefreshStream(_container!.read(authStateProvider.notifier).stream)
        : null,
    redirect: (context, state) {
      if (_container == null) return null;
      
      final authState = _container!.read(authStateProvider);
      
      // If auth state is still loading or has an error, don't redirect yet
      if (authState.isLoading || authState.hasError) return null;
      
      final isLoggedIn = authState.value ?? false;
      final isGoingToLogin = state.uri.path == '/login' ||
                             state.uri.path == '/register' ||
                             state.uri.path == '/select-role' ||
                             state.uri.path == '/forgot-password' ||
                             state.uri.path == '/verify-email' ||
                             state.uri.path == '/pending-approval';
      final isGoingToSplash = state.uri.path == '/splash';

      if (isGoingToSplash) return null;

      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }

      if (isLoggedIn && isGoingToLogin) {
        return '/splash'; // Let splash handle the correct home path
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _modernPageTransition(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _modernPageTransition(key: state.pageKey, child: const LoginScreen(), slideUp: true),
      ),
      GoRoute(
        path: '/select-role',
        name: 'select-role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return RegisterScreen(
            role: extra['role'] ?? 'PATIENT',
            patientType: extra['patientType'],
          );
        },
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmailVerificationScreen(email: extra['email'] ?? '');
        },
      ),
      GoRoute(
        path: '/pending-approval',
        name: 'pending-approval',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return PendingApprovalScreen(email: extra['email'] ?? '');
        },
      ),

      // -----------------------------------------------------------------------
      // PATIENT DASHBOARD (Stateful)
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => PatientShell(navigationShell: navigationShell, state: state),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
                // Sub-pages are top-level routes with parentNavigatorKey so they
                // render ABOVE the shell and get automatic back-button behaviour.
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/medical-reports',
                name: 'medical-reports',
                builder: (context, state) => const MedicalReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home/caregivers',
                name: 'caregivers',
                builder: (context, state) => const ManageCaregiversScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const UserProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                name: 'chats',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
        ],
      ),
      // -----------------------------------------------------------------------
      // CAREGIVER DASHBOARD (Stateful)
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => CaregiverShell(navigationShell: navigationShell, state: state),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caregiver',
                name: 'caregiver-home',
                builder: (context, state) => const CaregiverHomeScreen(),
                // caregiver/history is a top-level overlay route (see below)
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caregiver/my-patients',
                name: 'caregiver-my-patients',
                builder: (context, state) => const MyPatientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caregiver/maps',
                name: 'caregiver-maps',
                builder: (context, state) => const CaregiverMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caregiver/profile',
                name: 'caregiver-profile',
                builder: (context, state) => const UserProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caregiver/chats',
                name: 'caregiver-chats',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // RESPONDER DASHBOARD (Stateful)
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ResponderShell(navigationShell: navigationShell, state: state),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/responder',
                name: 'responder-home',
                builder: (context, state) => const ResponderHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/responder/history',
                name: 'responder-history',
                builder: (context, state) => const ResponderHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/responder/profile',
                name: 'responder-profile',
                builder: (context, state) => const UserProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/responder/chats',
                name: 'responder-chats',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Patient Sub-Pages (Full Screen overlays above shell)
      // Lifted out of StatefulShellBranch so they render above the shell and
      // get automatic back-navigation (AppBar leading arrow / system back).
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/home/medical-profile',
        name: 'medical-profile',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const MedicalProfileScreen(),
      ),
      GoRoute(
        path: '/home/medical-profile/edit',
        name: 'edit-medical-profile',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const EditMedicalProfileScreen(),
      ),
      GoRoute(
        path: '/home/patient-type-info',
        name: 'patient-type-info',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const PatientTypeInfoScreen(),
      ),
      GoRoute(
        path: '/home/emergency-contacts',
        name: 'emergency-contacts',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const EmergencyContactsScreen(),
      ),

      // -----------------------------------------------------------------------
      // Caregiver Sub-Pages (Full Screen overlays above shell)
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/caregiver/history',
        name: 'caregiver-history',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const CaregiverHistoryScreen(),
      ),

      // -----------------------------------------------------------------------
      // Overlay & Emergency Routes (Full Screen)
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/home/emergency',
        name: 'emergency',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const EmergencyScreen(),
      ),
      GoRoute(
        path: '/home/sos-countdown',
        name: 'sos-countdown',
        parentNavigatorKey: _navigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CustomTransitionPage(
            key: state.pageKey,
            child: SosCountdownScreen(
              emergencyType: extra['emergencyType'] ?? 'OTHER',
              latitude: (extra['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (extra['longitude'] as num?)?.toDouble() ?? 0.0,
              additionalInfo: extra['additionalInfo'],
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => ScaleTransition(scale: animation, child: child),
          );
        },
      ),
      GoRoute(
        path: '/responder/request/:requestId',
        name: 'emergency-request',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => EmergencyRequestScreen(requestId: state.pathParameters['requestId']!),
      ),
      GoRoute(
        path: '/responder/active/:emergencyId',
        name: 'active-emergency',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => ActiveEmergencyScreen(emergencyId: state.pathParameters['emergencyId']!),
      ),
      GoRoute(
        path: '/caregiver/tracking/:emergencyId',
        name: 'caregiver-tracking',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => CaregiverTrackingScreen(emergencyId: state.pathParameters['emergencyId']!),
      ),
      GoRoute(
        path: '/emergency/:emergencyId/tracking',
        name: 'emergency-tracking',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => EmergencyTrackingScreen(emergencyId: state.pathParameters['emergencyId']!),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/caregiver/my-patients/patient-profile/:userId',
        name: 'patient-profile',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => UserProfileScreen(
          userId: state.pathParameters['userId'],
        ),
      ),
      GoRoute(
        path: '/caregiver/my-patients/link-patient',
        name: 'caregiver-link-patient',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const LinkPatientScreen(),
      ),
      GoRoute(
        path: '/subscription-plans',
        name: 'subscription-plans',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const SubscriptionPlansScreen(),
      ),
      GoRoute(
        path: '/checkout/:planId',
        name: 'checkout',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => CheckoutScreen(planId: state.pathParameters['planId']!),
      ),
      GoRoute(
        path: '/payment-success',
        name: 'payment-success',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => PaymentSuccessScreen(planName: state.extra as String? ?? 'Premium'),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        name: 'chat-detail',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final otherUserName = state.extra as String?;
          return ChatDetailScreen(roomId: roomId, otherUserName: otherUserName);
        },
      ),
      GoRoute(
        path: '/diagnostics',
        name: 'diagnostics',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: '/predefined-messages',
        name: 'predefined-messages',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const PredefinedMessagesScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
}

/// A Listenable that notifies its listeners when a [Stream] emits a value.
/// Used to refresh the [GoRouter] when the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Temporary placeholder since history is currently part of the dashboard view
class _ResponderHistoryPlaceholder extends ConsumerWidget {
  const _ResponderHistoryPlaceholder();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In the future, we could extract the history tab logic to a separate screen
    // For now, we'll just show the home screen but set the tab to history
    // But since we are using GoRouter, we should probably just use the home screen
    return const ResponderHomeScreen(); 
  }
}
