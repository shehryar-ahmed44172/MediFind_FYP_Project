import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/medifind_api_client.dart';
import '../../services/socket/socket_service.dart';

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
      debugPrint('🔑 AuthRepository: Found token in storage, setting in API client');
      apiClient.setAuthToken(token);
      SocketService.instance.setAuthToken(token);
    } else {
      debugPrint('⚠️ AuthRepository: No token found in storage during initialization');
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
    SocketService.instance.setAuthToken(response.accessToken);
    return response;
  }

  @override
  Future<RegisterResponse> register(Map<String, dynamic> request) async {
    return await apiClient.register(request);
  }

  @override
  Future<AuthResponse> refreshToken(String token) async {
    final response = await apiClient.refreshToken(token);
    await localDataSource.saveAuthToken(response.accessToken);
    await localDataSource.saveRefreshToken(response.refreshToken);
    apiClient.setAuthToken(response.accessToken);
    SocketService.instance.setAuthToken(response.accessToken);
    return response;
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        debugPrint('🚪 AuthRepository: Calling backend logout API');
        await apiClient.logout(refreshToken);
      }
    } catch (e) {
      debugPrint('⚠️ AuthRepository: Backend logout failed (ignoring to ensure local cleanup): $e');
    } finally {
      debugPrint('🚪 AuthRepository: Clearing local auth data');
      await localDataSource.clearAuthToken();
      apiClient.clearAuthToken();
      SocketService.instance.disconnect();
    }
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
    if (profile == null) return null;

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
      isEmailVerified: profile.isEmailVerified ?? false,
      verificationStatus: profile.verificationStatus,
      rating: profile.rating,
      totalResponsesHandled: profile.totalResponsesHandled,
      profileImageUrl: profile.profileImageUrl,
      subscriptionPlan: profile.subscriptionPlan ?? 'FREE',
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
  Future<AuthResponse> verifyEmail(String email, String otp) async {
    final response = await apiClient.verifyEmail(email, otp);
    if (response.accessToken.isNotEmpty) {
      await localDataSource.saveAuthToken(response.accessToken);
      await localDataSource.saveRefreshToken(response.refreshToken);
      await localDataSource.saveCurrentUserId(response.userId);
      await localDataSource.saveCurrentUserRole(response.role);
    }
    return response;
  }

  @override
  Future<void> resendVerificationCode(String email) async {
    await apiClient.resendVerificationCode(email);
  }

  @override
  Future<User> updateProfile(Map<String, dynamic> data) async {
    return await apiClient.updateProfile(data);
  }

  @override
  Future<User> uploadProfileImage(File imageFile) async {
    return await apiClient.uploadProfileImage(imageFile);
  }

  @override
  Future<String> uploadDocument(File file) async {
    final response = await apiClient.uploadRegistrationDocument(file);
    return response['url'] as String;
  }
  @override
  Future<User> upgradeSubscription(String plan) async {
    return await apiClient.upgradeSubscription(plan);
  }

  @override
  Future<bool> processPayment(double amount, String method) async {
    // Simulate network delay for payment processing
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('💰 [MockPayment] Processed $amount via $method successfully.');
    return true;
  }
}
