import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/exceptions.dart';
import '../../../domain/entities/emergency.dart';
import '../../../domain/entities/medical_profile.dart';
import '../../../domain/entities/user.dart';

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
            debugPrint('🔑 Adding Auth Header: Bearer ${_authToken!.substring(0, 10)}...');
          } else {
            debugPrint('⚠️ No Auth Token available in MediFindApiClient');
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

  Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        'auth/register',
        data: request.toJson(),
      );

      if (response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>;
        return RegisterResponse.fromJson(data);
      }

      throw NetworkException(
        message: response.data['error'] ?? 'Registration failed',
        code: response.data['code'],
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        'auth/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode != 200) {
        throw NetworkException(
          message: response.data['error'] ?? 'Request failed',
          code: response.data['code'],
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> resetPassword(String email, String token, String newPassword) async {
    try {
      final response = await _dio.post(
        'auth/reset-password',
        data: {
          'email': email,
          'token': token,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode != 200) {
        throw NetworkException(
          message: response.data['error'] ?? 'Reset failed',
          code: response.data['code'],
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }
  
  Future<AuthResponse> verifyEmail(String email, String otp) async {
    try {
      final response = await _dio.post(
        'auth/verify-email',
        data: {
          'email': email,
          'otp': otp,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);
        if (authResponse.accessToken.isNotEmpty) {
          _authToken = authResponse.accessToken;
        }
        return authResponse;
      }

      throw NetworkException(
        message: response.data['error'] ?? 'Verification failed',
        code: response.data['code'],
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> resendVerificationCode(String email) async {
    try {
      final response = await _dio.post(
        'auth/resend-verification',
        data: {'email': email},
      );

      if (response.statusCode != 200) {
        throw NetworkException(
          message: response.data['error'] ?? 'Failed to resend code',
          code: response.data['code'],
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        'users/profile',
        data: data,
      );

      if (response.statusCode == 200) {
        return User.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to update profile');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<User> uploadProfileImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        'users/profile/image',
        data: formData,
      );

      if (response.statusCode == 200) {
        return User.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to upload profile image');
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

  Future<User> getMe() async {
    try {
      final response = await _dio.get('auth/me');
      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return _flattenUserJson(data);
      }
      throw NetworkException(message: 'Failed to fetch current user profile');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Helper to flatten nested role profiles from backend into the flat User entity
  User _flattenUserJson(Map<String, dynamic> json) {
    final Map<String, dynamic> flat = Map<String, dynamic>.from(json);
    
    // Extract from responder profile
    if (json['responder'] != null && json['responder'] is Map) {
      final resp = json['responder'] as Map<String, dynamic>;
      flat['cnic'] ??= resp['cnic'];
      flat['licenseNumber'] ??= resp['licenseNumber'];
      flat['organization'] ??= resp['organization'];
      flat['responderType'] ??= resp['responderType'];
      flat['vehicleType'] ??= resp['vehicleType'];
      flat['verificationStatus'] ??= resp['verificationStatus'];
      flat['rating'] ??= resp['rating'];
      flat['totalResponsesHandled'] ??= resp['totalResponsesHandled'];
    }
    
    // Extract from medical profile
    if (json['medicalProfile'] != null && json['medicalProfile'] is Map) {
      final med = json['medicalProfile'] as Map<String, dynamic>;
      flat['cnic'] ??= med['cnic'];
      flat['patientType'] ??= med['patientType'];
    }
    
    // Extract from caregiver profile
    if (json['caregiverProfile'] != null && json['caregiverProfile'] is Map) {
      final cg = json['caregiverProfile'] as Map<String, dynamic>;
      flat['cnic'] ??= cg['cnic'];
    }

    return User.fromJson(flat);
  }

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      final response = await _dio.put(
        'auth/fcm-token',
        data: {'fcmToken': fcmToken},
      );
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to update FCM token');
      }
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

  Future<List<Emergency>> getActiveEmergencies() async {
    try {
      // Guide and Backend controller use GET /api/emergencies for list of active/all
      final response = await _dio.get('emergencies');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data
            .map((json) => Emergency.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw NetworkException(message: 'Failed to fetch active emergencies');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> cancelEmergency(String emergencyId) async {
    try {
      final response = await _dio.post('emergencies/$emergencyId/cancel');
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to cancel emergency');
      }
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

  Future<List<Emergency>> getResponderActiveRequests() async {
    try {
      final response = await _dio.get('responders/emergencies');
      return (response.data['data'] as List)
          .map((e) => Emergency.fromJson(e))
          .toList();
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

  // RESPONDER ENDPOINTS
  Future<void> updateResponderLocation(double latitude, double longitude) async {
    try {
      final response = await _dio.post(
        'responders/location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to update responder location');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> setResponderAvailability(bool isAvailable) async {
    try {
      final response = await _dio.patch(
        'responders/availability',
        data: {'isAvailable': isAvailable},
      );
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to update responder availability');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> resolveEmergency(String emergencyId) async {
    try {
      final response = await _dio.post('responders/emergencies/$emergencyId/resolve');
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to resolve emergency');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<User>> getNearbyResponders(double latitude, double longitude, [double radius = 5.0]) async {
    try {
      final response = await _dio.get(
        'responders/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
      }
      throw NetworkException(message: 'Failed to fetch nearby responders');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getResponderHistory() async {
    try {
      final response = await _dio.get('responders/history');
      if (response.statusCode == 200) {
        return response.data['data'] as List<dynamic>;
      }
      throw NetworkException(message: 'Failed to fetch responder history');
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
  Future<void> cancelResponderAssignment(String emergencyId) async {
    try {
      await _dio.post('responders/emergencies/$emergencyId/cancel');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

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
          'patientEmail': email, // Changed from caregiverEmail based on user requirement
          'relationship': relationship,
        },
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw NetworkException(message: 'Failed to send invitation');
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

  Future<List<dynamic>> getAllCaregiverLinks() async {
    try {
      final response = await _dio.get('caregivers/links/all');

      if (response.statusCode == 200) {
        return response.data['data'] as List;
      }

      throw NetworkException(message: 'Failed to fetch all patient links');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> resendInvitation(String patientId) async {
    try {
      final response = await _dio.post('caregivers/links/$patientId/resend');

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to resend invitation');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> unlinkCaregiver(String connectionId) async {
    try {
      final response = await _dio.delete('caregivers/$connectionId');

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to unlink');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> respondToInvitation(String invitationId, bool accept) async {
    try {
      // Guide: POST /api/caregivers/invitations/:id/respond
      final response = await _dio.post(
        'caregivers/invitations/$invitationId/respond',
        data: {
          'accept': accept,
        },
      );

      if (response.statusCode != 200) {
         throw NetworkException(message: 'Failed to respond to invitation');
      }
    } on DioException catch (e) {
       throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getPendingInvitations() async {
    try {
      // Guide: GET /api/caregivers/invitations
      final response = await _dio.get('caregivers/invitations');

      if (response.statusCode == 200) {
        return response.data['data'] as List;
      }

      throw NetworkException(message: 'Failed to fetch pending invitations');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // MEDICAL REPORT ENDPOINTS
  Future<void> uploadEmergencyReport(String emergencyId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'report': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        'reports/$emergencyId',
        data: formData,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw NetworkException(message: 'Failed to upload report');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getEmergencyReports(String emergencyId) async {
    try {
      final response = await _dio.get('reports/$emergencyId');
      if (response.statusCode == 200) {
        return response.data['data'] as List;
      }
      throw NetworkException(message: 'Failed to fetch reports');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // TRACKING ENDPOINTS
  Future<void> submitLiveLocation(String emergencyId, double lat, double lng) async {
    try {
      final response = await _dio.post(
        'tracking',
        data: {
          'emergencyId': emergencyId,
          'latitude': lat,
          'longitude': lng,
        },
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw NetworkException(message: 'Failed to submit live location');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<dynamic> getLatestTracking(String emergencyId) async {
    try {
      final response = await _dio.get('tracking/$emergencyId/latest');
      if (response.statusCode == 200) {
        return response.data['data'];
      }
      throw NetworkException(message: 'Failed to fetch latest tracking');
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

  // MEDICAL PROFILE ENDPOINTS
  Future<List<dynamic>> getReports() async {
    try {
      final response = await _dio.get('reports/profile');

      if (response.statusCode == 200) {
        return response.data['data'] as List<dynamic>;
      }

      throw NetworkException(message: 'Failed to fetch reports');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<dynamic> uploadReport(File file, String reportType, [String? userId]) async {
    try {
      final formData = FormData.fromMap({
        'report': await MultipartFile.fromFile(file.path),
        'reportType': reportType,
        if (userId != null) 'userId': userId,
      });
      final response = await _dio.post('reports/profile', data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'];
      }

      throw NetworkException(message: 'Failed to upload report');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      final response = await _dio.delete('reports/$id');
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to delete report');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<dynamic> renameReport(String id, String newName) async {
    try {
      final response = await _dio.patch(
        'reports/$id',
        data: {'fileName': newName},
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      }
      throw NetworkException(message: 'Failed to rename report');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // ERROR HANDLING
  Future<List<dynamic>> getNotificationHistory({int limit = 50}) async {
    try {
      final response = await _dio.get('notifications/history', queryParameters: {'limit': limit});
      return response.data['data'] as List;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _dio.patch('notifications/$id/read');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _dio.patch('notifications/read-all');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // CHAT ENDPOINTS
  Future<List<dynamic>> getChatRooms() async {
    try {
      final response = await _dio.get('chat/rooms');
      if (response.statusCode == 200) {
        return response.data as List;
      }
      throw NetworkException(message: 'Failed to fetch chat rooms');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<dynamic>> getChatMessages(String roomId) async {
    try {
      final response = await _dio.get('chat/messages/$roomId');
      if (response.statusCode == 200) {
        return response.data as List;
      }
      throw NetworkException(message: 'Failed to fetch messages');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<dynamic> sendMessage(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('chat/messages', data: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data;
      }
      throw NetworkException(message: 'Failed to send message');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<dynamic> createOrGetChatRoom(String targetUserId) async {
    try {
      final response = await _dio.post('chat/rooms', data: {'targetUserId': targetUserId});
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      throw NetworkException(message: 'Failed to access chat room');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

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
