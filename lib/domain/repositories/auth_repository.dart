import '../entities/user.dart';

/// Abstract repository for authentication operations
abstract class AuthRepository {
  Future<AuthResponse> login(String email, String password);
  Future<AuthResponse> register(RegisterRequest request);
  Future<AuthResponse> refreshToken(String token);
  Future<void> logout();
  Future<bool> isUserLoggedIn();
  Future<String?> getAuthToken();
  Future<void> saveAuthToken(String token);
  Future<void> clearAuthToken();
}
