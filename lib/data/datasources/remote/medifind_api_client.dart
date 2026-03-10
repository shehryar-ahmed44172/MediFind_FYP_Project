import 'package:dio/dio.dart';
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
        _authToken = data['token'] as String;
        return AuthResponse.fromJson(data);
      }

      throw NetworkException(
        message: response.data['error'] ?? 'Login failed',
        code: response.data['code'],
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<AuthResponse> register(
    String fullName,
    String email,
    String phoneNumber,
    String password,
    String role,
  ) async {
    try {
      final response = await _dio.post(
        'auth/register',
        data: {
          'fullName': fullName,
          'email': email,
          'phoneNumber': phoneNumber,
          'password': password,
          'role': role,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>;
        _authToken = data['token'] as String;
        return AuthResponse.fromJson(data);
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
        'auth/refresh',
        data: {'token': token},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        _authToken = data['token'] as String;
        return AuthResponse.fromJson(data);
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
      final response = await _dio.get('users/$userId/emergencies');

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

  // MEDICAL PROFILE ENDPOINTS
  Future<MedicalProfile> getMedicalProfile(String userId) async {
    try {
      final response = await _dio.get('users/$userId/medical-profile');

      if (response.statusCode == 200) {
        return MedicalProfile.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to fetch medical profile');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<MedicalProfile> updateMedicalProfile(
    String userId,
    String bloodType,
    List<String> chronicDiseases,
    List<String> allergies,
    List<Map<String, dynamic>> medications,
    List<Map<String, dynamic>> emergencyContacts,
    String? medicalHistory,
  ) async {
    try {
      final response = await _dio.put(
        'users/$userId/medical-profile',
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
        queryParameters: {'q': query},
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
