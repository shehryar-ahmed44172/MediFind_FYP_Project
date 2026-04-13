import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '/core/constants/app_constants.dart';
import '/core/utils/exceptions.dart';
import '/domain/entities/emergency.dart';
import '/domain/entities/medical_profile.dart';
import '/domain/entities/user.dart';

class MediFindApiClient {
  final Dio _dio;
  String? _authToken;

  MediFindApiClient(this._dio) {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: Duration(milliseconds: AppConstants.apiTimeout),
      receiveTimeout: Duration(milliseconds: AppConstants.apiTimeout),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    // Add interceptor for logging
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
    );

    // Add interceptor for auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Handle token expiration
            return handler.reject(
              AuthenticationException(
                message: 'Session expired. Please login again.',
                code: 'TOKEN_EXPIRED',
              ) as DioException,
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  // AUTH ENDPOINTS
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _dio.post(
        'auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);
        _authToken = authResponse.accessToken;
        return authResponse;
      }

      throw NetworkException(
        message: response.data['error'] ?? 'Login failed',
        code: response.data['code'],
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        'auth/register',
        data: request.toJson(),
      );

      if (response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>;
        // Backend register returns only user object currently in services/auth.ts line 39
        // But login returns accessToken/refreshToken. 
        // If register returns accessToken/refreshToken, this works.
        // Let's assume it returns the full AuthResponse for consistency, 
        // or we'll need to login after register.
        final authResponse = AuthResponse.fromJson(data);
        _authToken = authResponse.accessToken;
        return authResponse;
      }

      throw NetworkException(
        message: response.data['error'] ?? 'Registration failed',
        code: response.data['code'],
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<AuthResponse> refreshToken(String token) async {
    try {
      final response = await _dio.post(
        'auth/refresh-token',
        data: {'refreshToken': token},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);
        _authToken = authResponse.accessToken;
        return authResponse;
      }

      throw NetworkException(
        message: 'Token refresh failed',
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // EMERGENCY ENDPOINTS
  Future<Emergency> createEmergency(
    String emergencyType,
    double latitude,
    double longitude,
    String? additionalInfo,
  ) async {
    try {
      final response = await _dio.post(
        'emergencies',
        data: {
          'emergencyType': emergencyType,
          'latitude': latitude,
          'longitude': longitude,
          'additionalInfo': additionalInfo,
          'priority': 'NORMAL', // Default, backend can override
        },
      );

      if (response.statusCode == 201) {
        return Emergency.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to create emergency');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Emergency> getEmergency(String emergencyId) async {
    try {
      final response = await _dio.get('emergencies/$emergencyId');

      if (response.statusCode == 200) {
        return Emergency.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to fetch emergency');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<Emergency>> getUserEmergencies(String userId) async {
    try {
      // Backend uses /api/emergencies for active or filtered list
      final response = await _dio.get('emergencies');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data
            .map((json) => Emergency.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw NetworkException(message: 'Failed to fetch emergencies');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> updateEmergencyStatus(String emergencyId, String status) async {
    try {
      // Backend doesn't have a direct 'status' PATCH on emergencies. 
      // Usually status is updated via accept/reject/cancel.
      // If we need a general status update, we'll need a new route.
      final response = await _dio.patch(
        'emergencies/$emergencyId/status',
        data: {'status': status},
      );

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to update emergency status');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> acceptEmergency(String emergencyId, String responderId) async {
    try {
      final response = await _dio.post(
        'responders/emergencies/$emergencyId/accept',
      );

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to accept emergency');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> rejectEmergency(String emergencyId, String responderId) async {
    try {
      final response = await _dio.post(
        'responders/emergencies/$emergencyId/reject',
      );

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to reject emergency');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // MEDICAL PROFILE ENDPOINTS
  Future<MedicalProfile> getMedicalProfile([String? userId]) async {
    try {
      // If userId is provided, get that user's profile (/api/medical-profile/:userId)
      // otherwise get current user's profile (/api/medical-profile)
      final path = userId != null ? 'medical-profile/$userId' : 'medical-profile';
      final response = await _dio.get(path);

      if (response.statusCode == 200) {
        return MedicalProfile.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to fetch medical profile');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<MedicalProfile> updateMedicalProfile({
    required String bloodType,
    required List<String> chronicDiseases,
    required List<String> allergies,
    required List<Map<String, dynamic>> medications,
    required List<Map<String, dynamic>> emergencyContacts,
    String? medicalHistory,
  }) async {
    try {
      final response = await _dio.put(
        'medical-profile',
        data: {
          'bloodType': bloodType,
          'chronicDiseases': chronicDiseases,
          'allergies': allergies,
          'medications': medications,
          'emergencyContacts': emergencyContacts,
          'medicalHistory': medicalHistory,
        },
      );

      if (response.statusCode == 200) {
        return MedicalProfile.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to update medical profile');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // USER ENDPOINTS
  Future<UserProfile> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('users/$userId');

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to fetch user profile');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<UserProfile> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('users/$userId', data: data);

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to update user profile');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        'users/search',
        queryParameters: {'query': query},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
      }

      throw NetworkException(message: 'Failed to search users');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // CAREGIVER ENDPOINTS
  Future<void> linkCaregiver(String email, String relationship) async {
    try {
      final response = await _dio.post(
        'caregivers/link',
        data: {
          'caregiverEmail': email,
          'relationship': relationship,
        },
      );

      if (response.statusCode != 201) {
        throw NetworkException(message: 'Failed to link caregiver');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getCaregiverLinks() async {
    try {
      final response = await _dio.get('caregivers');

      if (response.statusCode == 200) {
        return response.data['data'] as List;
      }

      throw NetworkException(message: 'Failed to fetch caregiver links');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> unlinkCaregiver(String caregiverId) async {
    try {
      final response = await _dio.delete('caregivers/$caregiverId');

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to unlink caregiver');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // PASSWORD ENDPOINTS
  Future<void> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        'password/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to request password reset');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      final response = await _dio.post(
        'password/reset',
        data: {
          'token': token,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to reset password');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await _dio.post(
        'password/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to change password');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ERROR HANDLING
  AppException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkException(
          message: 'Connection timeout. Please check your internet connection.',
          originalException: e,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final errorMessage = e.response?.data['error'] ?? 'Error occurred';
        if (statusCode == 401) {
          return AuthenticationException(
            message: errorMessage,
            originalException: e,
          );
        }
        return NetworkException(
          message: errorMessage,
          originalException: e,
        );
      case DioExceptionType.unknown:
        return NetworkException(
          message: 'An unexpected error occurred',
          originalException: e,
        );
      default:
        return NetworkException(
          message: 'Network error occurred',
          originalException: e,
        );
    }
  }
}
