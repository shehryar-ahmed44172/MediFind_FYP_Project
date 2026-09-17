import 'package:flutter/material.dart';
import '../services/call/call_service.dart';
import '../presentation/screens/call/call_screen.dart';
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
import '../presentation/screens/medical/medical_id_screen.dart';
import '../presentation/screens/patient/deaf_communication_card_screen.dart';

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
import '../presentation/screens/auth/reset_password_otp_screen.dart';
import '../presentation/screens/auth/reset_new_password_screen.dart';
import '../presentation/screens/settings/accessibility_settings_screen.dart';
import '../presentation/widgets/design_system/design_system.dart';

// AppRouter class manages all the navigation paths within the app
class AppRouter {
  // Global key to access navigator state from anywhere
  static final _navigatorKey = GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  static ProviderContainer? _container;

  /// Notifies GoRouter whenever the auth state changes. Subscribes to the
  /// PROVIDER (not a notifier instance), so it keeps working after
  /// `ref.invalidate(authStateProvider)` recreates the notifier.
  static final _AuthRefreshNotifier _authRefresh = _AuthRefreshNotifier();
  static ProviderSubscription<AsyncValue<bool>>? _authSubscription;

  // Method to set the ProviderContainer for dependency injection
  static void setContainer(ProviderContainer container) {
    if (identical(_container, container) && _authSubscription != null) return;
    _authSubscription?.close();
    _container = container;
    _authSubscription = container.listen<AsyncValue<bool>>(
      authStateProvider,
      (_, __) => _authRefresh.notify(),
    );
  }

  /// When set, the NEXT redirect evaluation returns null (no redirect) and
  /// clears itself. Call this immediately before any programmatic navigation
  /// that must bypass the auth redirect — e.g. after account deletion where
  /// authStateProvider still holds stale data(true) and would otherwise
  /// intercept context.go('/login') and send the user to /splash instead.
  static bool _skipNextRedirect = false;
  static void skipNextRedirect() => _skipNextRedirect = true;

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
    refreshListenable: _authRefresh,
    redirect: (context, state) {
      // One-shot bypass for programmatic navigations (e.g. account deletion)
      if (_skipNextRedirect) {
        _skipNextRedirect = false;
        return null;
      }

      if (_container == null) return null;
      
      final authState = _container!.read(authStateProvider);
      
      // If auth state is still loading or has an error, don't redirect yet
      if (authState.isLoading || authState.hasError) return null;
      
      final isLoggedIn = authState.value ?? false;
      final isGoingToLogin = state.uri.path == '/login' ||
                             state.uri.path == '/register' ||
                             state.uri.path == '/select-role' ||
                             state.uri.path == '/forgot-password' ||
                             state.uri.path == '/reset-password-otp' ||
                             state.uri.path == '/reset-new-password' ||
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
        path: '/reset-password-otp',
        name: 'reset-password-otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ResetPasswordOtpScreen(email: extra['email'] ?? '');
        },
      ),
      GoRoute(
        path: '/reset-new-password',
        name: 'reset-new-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ResetNewPasswordScreen(
            email: extra['email'] ?? '',
            otp: extra['otp'] ?? '',
          );
        },
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
      // PATIENT DASHBOARD — 4 tabs: SOS (Home) · Messages · Medical ID · Profile
      // Sub-pages are nested under their tab with parentNavigatorKey so they
      // render ABOVE the shell AND keep a back stack when reached via go().
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
                routes: [
                  GoRoute(
                    path: 'medical-profile',
                    name: 'medical-profile',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const MedicalProfileScreen(),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'edit-medical-profile',
                        parentNavigatorKey: _navigatorKey,
                        builder: (context, state) => const EditMedicalProfileScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'medical-reports',
                    name: 'medical-reports',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const MedicalReportsScreen(),
                  ),
                  GoRoute(
                    path: 'caregivers',
                    name: 'caregivers',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const ManageCaregiversScreen(),
                  ),
                  GoRoute(
                    path: 'patient-type-info',
                    name: 'patient-type-info',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const PatientTypeInfoScreen(),
                  ),
                  GoRoute(
                    path: 'emergency-contacts',
                    name: 'emergency-contacts',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const EmergencyContactsScreen(),
                  ),
                  // Deaf communication card ("Show to people nearby").
                  GoRoute(
                    path: 'show-card',
                    name: 'show-card',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => DeafCommunicationCardScreen(
                      message: state.extra is String ? state.extra as String : null,
                    ),
                  ),
                  // Legacy patient path — kept so existing links keep working.
                  GoRoute(
                    path: 'accessibility-settings',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const AccessibilitySettingsScreen(),
                  ),
                  GoRoute(
                    path: 'emergency',
                    name: 'emergency',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const EmergencyScreen(),
                  ),
                  GoRoute(
                    path: 'sos-countdown',
                    name: 'sos-countdown',
                    parentNavigatorKey: _navigatorKey,
                    pageBuilder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      return CustomTransitionPage(
                        key: state.pageKey,
                        transitionDuration: const Duration(milliseconds: 200),
                        child: SosCountdownScreen(
                          emergencyType: extra['emergencyType'] ?? 'OTHER',
                          latitude: (extra['latitude'] as num?)?.toDouble() ?? 0.0,
                          longitude: (extra['longitude'] as num?)?.toDouble() ?? 0.0,
                          additionalInfo: extra['additionalInfo'],
                          isMocked: extra['isMocked'] == true,
                          refineLocation: extra['refineLocation'] == true,
                        ),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                      );
                    },
                  ),
                ],
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/medical-id',
                name: 'medical-id',
                builder: (context, state) => const MedicalIdScreen(),
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
        ],
      ),
      // -----------------------------------------------------------------------
      // CAREGIVER DASHBOARD — 4 tabs: Patients (Home) · Live Map · Messages · Profile
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
                routes: [
                  GoRoute(
                    path: 'history',
                    name: 'caregiver-history',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const CaregiverHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'my-patients',
                    name: 'caregiver-my-patients',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => const MyPatientsScreen(),
                    routes: [
                      GoRoute(
                        path: 'patient-profile/:userId',
                        name: 'patient-profile',
                        parentNavigatorKey: _navigatorKey,
                        builder: (context, state) => UserProfileScreen(
                          userId: state.pathParameters['userId'],
                        ),
                      ),
                      GoRoute(
                        path: 'link-patient',
                        name: 'caregiver-link-patient',
                        parentNavigatorKey: _navigatorKey,
                        builder: (context, state) => const LinkPatientScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'tracking/:emergencyId',
                    name: 'caregiver-tracking',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => CaregiverTrackingScreen(emergencyId: state.pathParameters['emergencyId']!),
                  ),
                ],
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
                path: '/caregiver/chats',
                name: 'caregiver-chats',
                builder: (context, state) => const ChatListScreen(),
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
        ],
      ),

      // -----------------------------------------------------------------------
      // RESPONDER DASHBOARD — 3 tabs: Requests (Home) · History · Profile
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
                routes: [
                  GoRoute(
                    path: 'request/:requestId',
                    name: 'emergency-request',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => EmergencyRequestScreen(requestId: state.pathParameters['requestId']!),
                  ),
                  GoRoute(
                    path: 'active/:emergencyId',
                    name: 'active-emergency',
                    parentNavigatorKey: _navigatorKey,
                    builder: (context, state) => ActiveEmergencyScreen(emergencyId: state.pathParameters['emergencyId']!),
                  ),
                ],
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
        ],
      ),

      // -----------------------------------------------------------------------
      // Shared full-screen routes (all roles)
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/accessibility-settings',
        name: 'accessibility-settings',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const AccessibilitySettingsScreen(),
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
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map) {
            return PaymentSuccessScreen(
              planName: extra['planName']?.toString() ?? 'Premium',
              transactionId: extra['transactionId']?.toString(),
            );
          }
          return PaymentSuccessScreen(planName: extra as String? ?? 'Premium');
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _navigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      // In-app voice / video call (opened by CallService)
      GoRoute(
        path: CallService.callRoute,
        name: 'call',
        parentNavigatorKey: _navigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const CallScreen(),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
        ),
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
    errorBuilder: (context, state) => MfScaffold(
      title: 'Page not found',
      fallbackRoute: '/splash',
      body: MfEmptyState(
        icon: Icons.link_off_rounded,
        title: 'This page does not exist',
        message: state.uri.toString(),
        actionLabel: 'Go home',
        onAction: () => context.go('/splash'),
      ),
    ),
  );
}

/// Listenable used as GoRouter's `refreshListenable`.
class _AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
