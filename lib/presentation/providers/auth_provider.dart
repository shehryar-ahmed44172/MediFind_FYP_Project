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
      
      // Call the refresh endpoint
      final response = await client.refreshToken(refreshToken);
      
      // Save the new tokens
      await localDataSource.saveAuthToken(response.accessToken);
      if (response.refreshToken.isNotEmpty) {
        await localDataSource.saveRefreshToken(response.refreshToken);
      }
      
      debugPrint('✅ [AuthService] Token refreshed and saved successfully');
      return response.accessToken;
    } catch (e) {
      debugPrint('❌ [AuthService] Token refresh failed: $e');
      return null;
    }
  };

  // Set up session expiration callback
  client.onSessionExpired = () {
    debugPrint('🚪 [AuthService] Session expired. Forcing logout...');
    // To break circularity, we don't reference logoutProvider directly.
    // Instead, we clear the token and invalidate the auth state.
    // We use Future.delayed to ensure invalidation happens outside the current build/init cycle
    Future.delayed(Duration.zero, () {
      ref.read(localDataSourceProvider.future).then((ds) {
        ds.clearAuthToken();
        ref.read(apiClientProvider).clearAuthToken();
        ref.invalidate(authStateProvider);
      });
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

final forgotPasswordProvider = FutureProvider.family<void, String>((ref, email) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.forgotPassword(email);
});

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

final upgradeSubscriptionProvider = FutureProvider.family<User, String>((ref, plan) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  final updatedUser = await authRepo.upgradeSubscription(plan);
  ref.invalidate(currentUserProvider);
  return updatedUser;
});

final processPaymentProvider = FutureProvider.family<bool, PaymentParams>((ref, params) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  return await authRepo.processPayment(params.amount, params.method);
});

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

class PaymentParams {
  final double amount;
  final String method;
  PaymentParams({required this.amount, required this.method});
}

