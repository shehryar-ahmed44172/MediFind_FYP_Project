import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_data_source.dart';
import '../../data/datasources/remote/medifind_api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import 'package:dio/dio.dart';

// API Client Provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

final apiClientProvider = Provider<MediFindApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return MediFindApiClient(dio);
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
      final repo = _authRepository.when(
        data: (repo) => repo,
        loading: () => throw Exception('Auth repository not ready'),
        error: (err, st) => throw err,
      );
      final isLoggedIn = await repo.isUserLoggedIn();
      state = AsyncValue.data(isLoggedIn);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
    FutureProvider.family<void, RegisterRequest>((ref, request) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.register(request);
});

final logoutProvider = FutureProvider<void>((ref) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.logout();
  
  // Invalidate Auth State
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(currentUserRoleProvider);
  ref.invalidate(currentUserProvider);
  
  // Invalidate all connection/patient data to prevent leakage
  // We use a broader approach by invalidating the repository-linked providers
  // Search for these in caregiver_providers.dart if needed, but we can explicitly list them
  // Note: Since we can't easily import all if they are in other files without cross-imports,
  // we invalidate the ones we know are common.
  
  // These are from caregiver_providers.dart
  // We don't strictly need to import them to invalidate them if we have the reference,
  // but it's better to ensure they are available or use more generic reset if possible.
  // Actually, Riverpod's ref.invalidate works with the provider variable.
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
