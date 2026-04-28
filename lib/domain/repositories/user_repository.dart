import '../entities/user.dart';

/// Abstract repository for user profile operations
abstract class UserRepository {
  Future<UserProfile> getUserProfile(String userId);
  
  Future<UserProfile> updateUserProfile(UserProfile profile);
  
  Future<User> getUser(String userId);
  
  Future<List<User>> searchUsers(String query);
  
  Stream<UserProfile> watchUserProfile(String userId);
}
