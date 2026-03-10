import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/medifind_api_client.dart';

class UserRepositoryImpl implements UserRepository {
  final MediFindApiClient apiClient;
  final LocalDataSource localDataSource;

  UserRepositoryImpl({
    required this.apiClient,
    required this.localDataSource,
  });

  // ---------------------------------------------------------------------------
  // Helper: convert User → Map (for local storage)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _userToMap(User u) => {
        'id': u.id,
        'fullName': u.fullName,
        'email': u.email,
        'phoneNumber': u.phoneNumber,
        'role': u.role,
        'profileImageUrl': u.profileImageUrl,
        'createdAt': u.createdAt.toIso8601String(),
        'updatedAt': u.updatedAt.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Helper: convert Map → User (from local storage)
  // ---------------------------------------------------------------------------
  User _mapToUser(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      role: map['role'] as String? ?? 'USER',
      profileImageUrl: map['profileImageUrl'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<UserProfile> getUserProfile(String userId) async {
    try {
      final profile = await apiClient.getUserProfile(userId);
      return profile;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    final data = {
      'fullName': profile.fullName,
      'email': profile.email,
      'phoneNumber': profile.phoneNumber,
      'profileImageUrl': profile.profileImageUrl,
      'bio': profile.bio,
      'address': profile.address,
      'city': profile.city,
      'state': profile.state,
      'country': profile.country,
      'zipCode': profile.zipCode,
    };

    return await apiClient.updateUserProfile(profile.userId, data);
  }

  @override
  Future<User> getUser(String userId) async {
    try {
      final cached = await localDataSource.getUser(userId);
      if (cached != null) {
        return _mapToUser(cached);
      }
    } catch (_) {}

    // Fallback or API logic
    throw UnimplementedError('getUser API logic not implemented');
  }

  @override
  Future<List<User>> searchUsers(String query) async {
    return await apiClient.searchUsers(query);
  }

  @override
  Stream<UserProfile> watchUserProfile(String userId) async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      try {
        final profile = await getUserProfile(userId);
        yield profile;
      } catch (_) {}
    }
  }
}
