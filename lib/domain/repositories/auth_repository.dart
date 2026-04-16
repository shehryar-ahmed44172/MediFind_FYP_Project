import 'dart:io';
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
  Future<User> getMe();
  Future<void> updateFcmToken(String token);
  Future<User?> getUser(String userId);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String email, String token, String newPassword);
  Future<User> updateProfile(Map<String, dynamic> data);
  Future<User> uploadProfileImage(File imageFile);
}
