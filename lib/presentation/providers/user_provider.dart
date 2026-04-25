import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import 'auth_provider.dart';

// User Repository Provider
final userRepositoryProvider = FutureProvider<UserRepository>((ref) async {
  // Ensure auth is initialized
  await ref.watch(authRepositoryProvider.future);
  
  final apiClient = ref.watch(apiClientProvider);
  final localDataSource = await ref.watch(localDataSourceProvider.future);
  return UserRepositoryImpl(
    apiClient: apiClient,
    localDataSource: localDataSource,
  );
});

// Get user profile provider
final getUserProfileProvider = FutureProvider.family<UserProfile, String>((ref, userId) async {
  final userRepo = await ref.watch(userRepositoryProvider.future);
  return await userRepo.getUserProfile(userId);
});

// Update user profile provider
final updateUserProfileProvider = FutureProvider.family<UserProfile, UserProfile>((ref, profile) async {
  final userRepo = await ref.watch(userRepositoryProvider.future);
  return await userRepo.updateUserProfile(profile);
});

// Search users provider
final searchUsersProvider = FutureProvider.family<List<User>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final userRepo = await ref.watch(userRepositoryProvider.future);
  return await userRepo.searchUsers(query);
});

// Watch user profile provider
final watchUserProfileProvider = StreamProvider.family<UserProfile, String>((ref, userId) async* {
  final userRepo = await ref.watch(userRepositoryProvider.future);
  yield* userRepo.watchUserProfile(userId);
});
