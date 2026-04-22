import 'dart:io';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/medifind_api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final MediFindApiClient apiClient;
  final LocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.apiClient,
    required this.localDataSource,
  });

  /// Initialize the repository by loading stored token into the API client
  Future<void> initialize() async {
    final token = await localDataSource.getAuthToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setAuthToken(token);
    }
  }

  @override
  Future<AuthResponse> login(String email, String password) async {
    final response = await apiClient.login(email, password);
    await localDataSource.saveAuthToken(response.accessToken);
    await localDataSource.saveRefreshToken(response.refreshToken);
    await localDataSource.saveCurrentUserId(response.userId);
    await localDataSource.saveCurrentUserRole(response.role);
    apiClient.setAuthToken(response.accessToken);
    return response;
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await apiClient.register(request);
    await localDataSource.saveAuthToken(response.accessToken);
    await localDataSource.saveRefreshToken(response.refreshToken);
    await localDataSource.saveCurrentUserId(response.userId);
    await localDataSource.saveCurrentUserRole(response.role);
    apiClient.setAuthToken(response.accessToken);
    return response;
  }

  @override
  Future<AuthResponse> refreshToken(String token) async {
    final response = await apiClient.refreshToken(token);
    await localDataSource.saveAuthToken(response.accessToken);
    await localDataSource.saveRefreshToken(response.refreshToken);
    apiClient.setAuthToken(response.accessToken);
    return response;
  }

  @override
  Future<void> logout() async {
    await localDataSource.clearAuthToken();
    apiClient.clearAuthToken();
  }

  @override
  Future<bool> isUserLoggedIn() async {
    final token = await localDataSource.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> getAuthToken() async {
    return await localDataSource.getAuthToken();
  }

  @override
  Future<void> saveAuthToken(String token) async {
    await localDataSource.saveAuthToken(token);
    apiClient.setAuthToken(token);
  }

  @override
  Future<void> clearAuthToken() async {
    await localDataSource.clearAuthToken();
    apiClient.clearAuthToken();
  }

  @override
  Future<User> getMe() async {
    return await apiClient.getMe();
  }

  @override
  Future<void> updateFcmToken(String token) async {
    await apiClient.updateFcmToken(token);
  }

  @override
  Future<User?> getUser(String userId) async {
    final profile = await apiClient.getUserProfile(userId);
    // Map UserProfile to User
    return User(
      id: profile.userId,
      fullName: profile.fullName,
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      role: profile.role,
      patientType: profile.patientType,
      organization: profile.organization,
      licenseNumber: profile.licenseNumber,
      responderType: profile.responderType,
      vehicleType: profile.vehicleType,
      profileImageUrl: profile.profileImageUrl,
      isActive: profile.isActive ?? true,
      createdAt: profile.lastUpdated ?? DateTime.now(),
      updatedAt: profile.lastUpdated ?? DateTime.now(),
    );
  }
  @override
  Future<void> forgotPassword(String email) async {
    await apiClient.forgotPassword(email);
  }

  @override
  Future<void> resetPassword(String email, String token, String newPassword) async {
    await apiClient.resetPassword(email, token, newPassword);
  }

  @override
  Future<User> updateProfile(Map<String, dynamic> data) async {
    return await apiClient.updateProfile(data);
  }

  @override
  Future<User> uploadProfileImage(File imageFile) async {
    return await apiClient.uploadProfileImage(imageFile);
  }
}
