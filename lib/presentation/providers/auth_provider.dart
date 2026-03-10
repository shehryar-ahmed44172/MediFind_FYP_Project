import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_data_source.dart';
import '../../data/datasources/remote/medifind_api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
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
  return AuthRepositoryImpl(
    apiClient: apiClient,
    localDataSource: localDataSource,
  );
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
    FutureProvider.family<void, RegisterParams>((ref, params) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.register(
    params.fullName,
    params.email,
    params.phoneNumber,
    params.password,
    params.role,
  );
});

final logoutProvider = FutureProvider<void>((ref) async {
  final authRepo = await ref.watch(authRepositoryProvider.future);
  await authRepo.logout();
  ref.invalidate(authStateProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(currentUserRoleProvider);
});

// Current user ID provider (for convenience across screens)
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  final localDs = await ref.watch(localDataSourceProvider.future);
  return localDs.getCurrentUserId();
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

class RegisterParams {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String role;

  RegisterParams({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.role,
  });
}
