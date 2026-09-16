import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_data_source.dart';
import '../../data/datasources/remote/medifind_api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../services/location/responder_location_tracker.dart';
import '../../services/socket/socket_service.dart';
import '../../core/utils/app_messenger.dart';
import '../../core/utils/exceptions.dart';

// API Client Provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

final Provider<MediFindApiClient> apiClientProvider = Provider<MediFindApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  final client = MediFindApiClient(dio);

  // Set up token refresh callback
  client.onTokenExpired = () async {
    try {
      debugPrint('⏳ [AuthService] Interceptor triggering token refresh...');
      // We use ref.read here because this is an asynchronous callback triggered later
      final localDataSource = await ref.read(localDataSourceProvider.future);
      final refreshToken = await localDataSource.getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('⚠️ [AuthService] No refresh token available');
        return null;
      }
      
      // Call the refresh endpoint (uses a separate, interceptor-free Dio)
      final response = await client.refreshToken(refreshToken);

      // Save the new tokens (refresh token may be rotated by the server)
      await localDataSource.saveAuthToken(response.accessToken);
      if (response.refreshToken != null) {
        await localDataSource.saveRefreshToken(response.refreshToken!);
      }

      // Reconnect the socket with the fresh JWT so personal rooms keep working
      SocketService.instance.updateAuthToken(response.accessToken);

      debugPrint('✅ [AuthService] Token refreshed and saved successfully');
      return response.accessToken;
    } catch (e) {
      debugPrint('[AuthService] Token refresh failed: $e');
      // Let the client show the server's reason (e.g. account deactivated).
      if (e is AppException && e.message.toLowerCase().contains('deactivated')) rethrow;
      return null;
    }
  };

  // Set up session expiration callback
  client.onSessionExpired = (String? reason) {
    debugPrint('[AuthService] Session expired. Forcing logout...');
    // To break circularity, we don't reference logoutProvider directly.
    // Instead, we clear the token and invalidate the auth state outside the
    // current build/init cycle.
    Future.delayed(Duration.zero, () async {
      final ds = await ref.read(localDataSourceProvider.future);
      await ds.clearAuthToken();
      ref.read(apiClientProvider).clearAuthToken();
      SocketService.instance.disconnect();
      ref.read(authStateProvider.notifier).forceLoggedOut();
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(currentUserRoleProvider);
      ref.invalidate(currentUserProvider);
      AppMessenger.showError(reason ?? 'Your session has expired. Please log in again.');
    });
  };

  return client;
});

// Local Data Source Provider
final localDataSourceProvider = FutureProvider<LocalDataSource>((ref) async {
  final localDataSource = LocalDataSource();
  await localDataSource.initializeHive();
  return localDataSource;
});

// Auth Repository Provider
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final localDataSource = await ref.watch(localDataSourceProvider.future);
  final repo = AuthRepositoryImpl(
    apiClient: apiClient,
    localDataSource: localDataSource,
  );
  await repo.initialize();
  return repo;
});

// Auth state provider
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<bool>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthStateNotifier(authRepository);
});

class AuthStateNotifier extends StateNotifier<AsyncValue<bool>> {
  final AsyncValue<AuthRepository> _authRepository;

  AuthStateNotifier(this._authRepository) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

  void _initializeAuth() async {
    state = const AsyncValue.loading();
    try {
      final repo = await _authRepository.when(
        data: (repo) async => repo,
        loading: () async => null,
        error: (err, st) => throw err,
      );

      if (repo == null) return;

      final isLoggedIn = await repo.isUserLoggedIn();
      state = AsyncValue.data(isLoggedIn);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Immediately marks the session as logged out (synchronous).
  ///
  /// Call this right after clearing the token storage so that:
  /// - The GoRouter redirect sees data(false) immediately — no waiting for
  ///   the async Riverpod rebuild cycle.
  /// - GoRouterRefreshStream fires notifyListeners() → GoRouter re-evaluates
  ///   the redirect and returns null (not logged in, not going to login) or
  ///   routes directly to /login.
  /// - Any subsequent redirect evaluation cannot send the user back to /splash.
  void forceLoggedOut() {
    state = const AsyncValue.data(false);
  }
}

// Auth action providers
final loginProvider =
    FutureProvider.family<void, LoginParams>((ref, params) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.login(params.email, params.password);
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(currentUserRoleProvider);
});

final registerProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, request) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.register(request);
});

// autoDispose: CRITICAL — prevents Riverpod from caching the completed void result.
// Without autoDispose, a second call to ref.read(logoutProvider.future) returns the
// cached completed future immediately, silently skipping the actual logout logic.
final logoutProvider = FutureProvider.autoDispose<void>((ref) async {
  final authRepo = await ref.read(authRepositoryProvider.future);
  await authRepo.logout();

  // Invalidate auth state so any listeners see "logged out" immediately.
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(currentUserRoleProvider);
  ref.invalidate(currentUserProvider);

  // Stop background tracking for Responders
  ref.invalidate(responderLocationTrackerProvider);
});

// Update FCM Token provider
final updateFcmTokenProvider = FutureProvider.family<void, String>((ref, token) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.updateFcmToken(token);
});

// Current user ID provider (for convenience across screens)
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  final localDs = await ref.watch(localDataSourceProvider.future);
  return localDs.getCurrentUserId();
});

// Current user full profile provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return null;
  
  final authRepo = await ref.watch(authRepositoryProvider.future);
  return await authRepo.getUser(userId);
});

// Fetch user profile by ID provider
final userProfileProvider = FutureProvider.family<User?, String>((ref, userId) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  return await authRepo.getUser(userId);
});

// Current user role provider
final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final localDs = await ref.watch(localDataSourceProvider.future);
  return localDs.getCurrentUserRole();
});

// Parameters
class LoginParams {
  final String email;
  final String password;
  LoginParams({required this.email, required this.password});
}

// autoDispose: CRITICAL — prevents caching. Without it, calling the provider
// a second time with the same email returns the old cached result and skips the API call.
final forgotPasswordProvider =
    FutureProvider.autoDispose.family<void, String>((ref, email) async {
  final authRepo = await ref.read(authRepositoryProvider.future);
  await authRepo.forgotPassword(email);
});

/// Completes the forgot-password flow: verifies the OTP and sets the new password in one request.
// autoDispose: same reason — each submit must hit the API fresh.
final resetPasswordProvider =
    FutureProvider.autoDispose.family<void, ResetPasswordParams>((ref, params) async {
  final authRepo = await ref.read(authRepositoryProvider.future);
  await authRepo.resetPassword(params.email, params.otp, params.newPassword);
});

class ResetPasswordParams {
  final String email;
  final String otp;
  final String newPassword;

  const ResetPasswordParams({
    required this.email,
    required this.otp,
    required this.newPassword,
  });
}

final updateProfileProvider = FutureProvider.family<User, Map<String, dynamic>>((ref, data) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  final updatedUser = await authRepo.updateProfile(data);
  ref.invalidate(currentUserProvider);
  return updatedUser;
});

final uploadProfileImageProvider = FutureProvider.family<User, File>((ref, file) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  final updatedUser = await authRepo.uploadProfileImage(file);
  ref.invalidate(currentUserProvider);
  return updatedUser;
});

final verifyEmailProvider = FutureProvider.family<void, VerifyEmailParams>((ref, params) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.verifyEmail(params.email, params.otp);
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(currentUserRoleProvider);
  ref.invalidate(currentUserProvider);
});

final resendOTPProvider = FutureProvider.family<void, String>((ref, email) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.resendVerificationCode(email);
});

class VerifyEmailParams {
  final String email;
  final String otp;
  VerifyEmailParams({required this.email, required this.otp});
}

/// Upgrades the plan after a successful Stripe payment. autoDispose so every
/// attempt hits the API (the server verifies the PaymentIntent).
final upgradeSubscriptionProvider =
    FutureProvider.autoDispose.family<User, UpgradeSubscriptionParams>((ref, params) async {
  final authRepo = await ref.read(authRepositoryProvider.future);
  final updatedUser = await authRepo.upgradeSubscription(
    params.plan,
    paymentIntentId: params.paymentIntentId,
  );
  ref.invalidate(currentUserProvider);
  return updatedUser;
});

class UpgradeSubscriptionParams {
  final String plan;
  final String paymentIntentId;
  const UpgradeSubscriptionParams({required this.plan, required this.paymentIntentId});

  @override
  bool operator ==(Object other) =>
      other is UpgradeSubscriptionParams &&
      other.plan == plan &&
      other.paymentIntentId == paymentIntentId;

  @override
  int get hashCode => Object.hash(plan, paymentIntentId);
}

final deleteAccountProvider = FutureProvider<void>((ref) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.deleteAccount();
  // Invalidate all auth state so the app redirects to login
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(currentUserRoleProvider);
  ref.invalidate(currentUserProvider);
  ref.invalidate(responderLocationTrackerProvider);
});
