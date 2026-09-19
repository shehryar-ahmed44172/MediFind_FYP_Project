import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/exceptions.dart';
import '../../../domain/entities/emergency.dart';
import '../../../domain/entities/medical_profile.dart';
import '../../../domain/entities/user.dart';

typedef TokenRefreshCallback = Future<String?> Function();
/// [reason] is a user-facing message (e.g. account deactivated), or null.
typedef LogoutCallback = void Function(String? reason);

/// Result of `POST auth/refresh-token`.
class TokenRefreshResult {
  final String accessToken;
  final String? refreshToken;
  const TokenRefreshResult({required this.accessToken, this.refreshToken});
}

/// Result of `POST emergencies`. When the patient already has an open SOS the
/// server returns that emergency with `alreadyActive: true` (HTTP 200).
class CreateEmergencyResult {
  final Emergency emergency;
  final bool alreadyActive;
  const CreateEmergencyResult({required this.emergency, this.alreadyActive = false});
}

/// Result of `POST payments/create-intent`.
class PaymentIntentInfo {
  final String clientSecret;
  final String paymentIntentId;
  const PaymentIntentInfo({required this.clientSecret, required this.paymentIntentId});
}

class MediFindApiClient {
  final Dio _dio;
  Dio get dio => _dio;

  /// Plain Dio (no auth/refresh interceptors) used ONLY for the refresh-token
  /// call. Using the main Dio for refresh could deadlock: a 401 from the
  /// refresh endpoint would re-enter the refresh interceptor and wait on itself.
  late final Dio _refreshDio;

  // SHARED STATIC AUTH STATE
  static String? _authToken;

  /// Non-null while a token refresh is in flight. Every request that hits a
  /// 401 during that window awaits the same future (true = refreshed).
  static Completer<bool>? _refreshCompleter;
  static String? _pendingLogoutReason;

  /// Endpoints whose 401 means "bad credentials", not "expired token".
  static const List<String> _noRefreshPaths = [
    'auth/login',
    'auth/register',
    'auth/refresh-token',
    'auth/logout',
    'auth/verify-email',
    'auth/forgot-password',
    'auth/reset-password',
  ];

  TokenRefreshCallback? onTokenExpired;
  LogoutCallback? onSessionExpired;

  MediFindApiClient(this._dio) {
    // Synchronize this instance with existing static token
    if (_authToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_authToken';
    }
    _configureDio();
  }

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
        headers: {
          'Content-Type': 'application/json',
          // Bypass ngrok interstitial warning page (ignored by real servers)
          if (AppConstants.baseUrl.contains('ngrok'))
            'ngrok-skip-browser-warning': 'true',
        },
      );

  void _configureDio() {
    // Prevent adding multiple copies of the same interceptors if Dio is shared
    _dio.interceptors.removeWhere((i) => i is LogInterceptor || i is InterceptorsWrapper);

    _dio.options = _baseOptions();
    _refreshDio = Dio(_baseOptions());

    // Request/response logging: debug builds only, and never headers (they
    // carry the bearer token). Release builds log nothing.
    if (kDebugMode) {
      debugPrint('MediFind API Client initialized with Base URL: ${_dio.options.baseUrl}');
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }

    // Add interceptor for auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final requestOptions = error.requestOptions;
          final path = requestOptions.path;
          final isAuthPath = _noRefreshPaths.any((p) => path.contains(p));
          final alreadyRetried = requestOptions.extra['__retriedAfterRefresh'] == true;

          // Login/register 401s are bad credentials — surface them as-is.
          if (error.response?.statusCode != 401 || isAuthPath || alreadyRetried) {
            return handler.next(error);
          }

          final serverMessage = _serverMessage(error.response?.data);
          if (serverMessage != null && serverMessage.toLowerCase().contains('deactivated')) {
            onSessionExpired?.call(serverMessage);
            return handler.reject(
              DioException(
                requestOptions: requestOptions,
                error: AuthenticationException(message: serverMessage, code: 'ACCOUNT_DEACTIVATED'),
                type: DioExceptionType.badResponse,
                response: error.response,
              ),
            );
          }

          debugPrint('401 Unauthorized for: $path');

          final refreshed = await _refreshTokenOnce();
          if (refreshed) {
            try {
              return handler.resolve(await _retry(requestOptions));
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }

          // Refresh failed or was not possible
          debugPrint('Session expired, triggering logout...');
          final reason = _pendingLogoutReason;
          _pendingLogoutReason = null;
          onSessionExpired?.call(reason);

          return handler.reject(
            DioException(
              requestOptions: requestOptions,
              error: AuthenticationException(
                message: 'Session expired. Please login again.',
                code: 'TOKEN_EXPIRED',
              ),
              type: DioExceptionType.badResponse,
              response: error.response,
            ),
          );
        },
      ),
    );
  }

  static String? _serverMessage(dynamic data) {
    if (data is Map) {
      final m = data['error'] ?? data['message'];
      if (m is String && m.isNotEmpty) return m;
    }
    return null;
  }

  /// Runs at most one refresh at a time. Concurrent callers share the result,
  /// and the shared future ALWAYS completes (true/false) so queued requests
  /// are never left hanging when a refresh fails.
  Future<bool> _refreshTokenOnce() async {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    var success = false;
    try {
      if (onTokenExpired != null) {
        final newToken = await onTokenExpired!();
        if (newToken != null && newToken.isNotEmpty) {
          _authToken = newToken;
          _dio.options.headers['Authorization'] = 'Bearer $newToken';
          success = true;
        }
      }
    } catch (e) {
      debugPrint('Token refresh failed with error: $e');
      if (e is AppException && e.message.toLowerCase().contains('deactivated')) {
        _pendingLogoutReason = e.message;
      }
    } finally {
      _refreshCompleter = null;
      completer.complete(success);
    }
    return success;
  }

  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
  }

  Future<void> logout(String refreshToken) async {
    try {
      final response = await _dio.post(
        'auth/logout',
        data: {
          'refreshToken': refreshToken,
        },
      );

      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to logout from server');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    final options = Options(
      method: requestOptions.method,
      headers: headers,
      contentType: requestOptions.contentType,
      responseType: requestOptions.responseType,
      extra: {...requestOptions.extra, '__retriedAfterRefresh': true},
    );

    // A FormData body can only be sent once — clone it for the retry.
    final data = requestOptions.data is FormData
        ? (requestOptions.data as FormData).clone()
        : requestOptions.data;

    return _dio.request<dynamic>(
      requestOptions.path,
      data: data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
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

  Future<RegisterResponse> register(Map<String, dynamic> request) async {
    try {
      final response = await _dio.post(
        'auth/register',
        data: request,
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

  /// Creates a Stripe PaymentIntent for [plan]. The server only returns the
  /// client secret; the PaymentIntent id is its prefix before `_secret_`.
  Future<PaymentIntentInfo> createPaymentIntent(String plan) async {
    try {
      final response = await _dio.post(
        'payments/create-intent',
        data: {'plan': plan},
      );
      final data = response.data is Map ? response.data['data'] : null;
      final clientSecret = (data is Map ? data['clientSecret'] : null)?.toString() ?? '';
      if (clientSecret.isEmpty) {
        throw NetworkException(message: 'Failed to create payment intent');
      }
      final explicitId = (data is Map ? (data['paymentIntentId'] ?? data['id']) : null)?.toString();
      final idx = clientSecret.indexOf('_secret_');
      final derivedId = idx > 0 ? clientSecret.substring(0, idx) : '';
      final paymentIntentId =
          (explicitId != null && explicitId.isNotEmpty) ? explicitId : derivedId;
      if (paymentIntentId.isEmpty) {
        throw NetworkException(message: 'Invalid payment intent returned by server');
      }
      return PaymentIntentInfo(clientSecret: clientSecret, paymentIntentId: paymentIntentId);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Upgrades the plan. The server verifies with Stripe that [paymentIntentId]
  /// succeeded for this user + plan before applying it.
  Future<User> upgradeSubscription(String plan, {required String paymentIntentId}) async {
    try {
      final response = await _dio.patch(
        'users/upgrade',
        data: {'plan': plan, 'paymentIntentId': paymentIntentId},
      );

      if (response.statusCode == 200) {
        return User.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      throw NetworkException(message: 'Failed to upgrade subscription');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      final response = await _dio.delete('users/me');
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to delete account');
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

  /// Uses the interceptor-free [_refreshDio] so a 401 here can never recurse
  /// into the refresh logic. The server returns `token` and `accessToken`
  /// (same value) and `refreshToken` (may be rotated).
  Future<TokenRefreshResult> refreshToken(String token) async {
    try {
      final response = await _refreshDio.post(
        'auth/refresh-token',
        data: {'refreshToken': token},
      );

      final body = response.data;
      final data = (body is Map && body['data'] is Map) ? body['data'] as Map : body;
      if (response.statusCode == 200 && data is Map) {
        final access = (data['accessToken'] ?? data['token'])?.toString();
        if (access == null || access.isEmpty) {
          throw NetworkException(message: 'Token refresh failed: no token in response');
        }
        final rotated = data['refreshToken']?.toString();
        _authToken = access;
        return TokenRefreshResult(
          accessToken: access,
          refreshToken: (rotated != null && rotated.isNotEmpty) ? rotated : null,
        );
      }

      throw NetworkException(message: 'Token refresh failed');
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

  // EMERGENCY ENDPOINTS
  Future<CreateEmergencyResult> createEmergency(
    String emergencyType,
    double latitude,
    double longitude,
    String? additionalInfo, {
    bool isMocked = false,
  }) async {
    try {
      final response = await _dio.post(
        'emergencies',
        data: {
          'emergencyType': emergencyType,
          'latitude': latitude,
          'longitude': longitude,
          'additionalInfo': additionalInfo,
          'isMocked': isMocked,
          'priority': 'NORMAL', // Default, backend can override
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = response.data as Map;
        final data = Map<String, dynamic>.from(body['data'] as Map);
        final alreadyActive = body['alreadyActive'] == true || data['alreadyActive'] == true;
        return CreateEmergencyResult(
          emergency: Emergency.fromJson(data),
          alreadyActive: alreadyActive,
        );
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

  /// Assigned responder progress update: EN_ROUTE, ARRIVED, TREATING,
  /// TRANSPORTED or RESOLVED. The current position is recorded as tracking.
  Future<void> updateEmergencyStatus(
    String emergencyId,
    String status, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.patch(
        'emergencies/$emergencyId/status',
        data: {
          'status': status,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
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

  /// Raw `GET responders/emergencies` items (PENDING + ACCEPTED requests for
  /// this responder), including `requests[]` with `distanceKm`,
  /// `estimatedArrivalMinutes` and the nested `patient`.
  Future<List<Map<String, dynamic>>> getResponderActiveRequestsRaw() async {
    try {
      final response = await _dio.get('responders/emergencies');
      final list = response.data['data'];
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Raw `GET emergencies/:id`, including `emergencyRequests[]` (with the
  /// responder) and `patient`, which the [Emergency] entity doesn't model.
  Future<Map<String, dynamic>> getEmergencyRaw(String emergencyId) async {
    try {
      final response = await _dio.get('emergencies/$emergencyId');
      final data = response.data['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      throw NetworkException(message: 'Failed to fetch emergency');
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

  /// [outcome]: TREATED | TRANSPORTED | FALSE_ALARM | PATIENT_NOT_FOUND.
  /// Both fields are optional (older backends default the outcome to TREATED).
  Future<void> resolveEmergency(String emergencyId, {String? outcome, String? note}) async {
    try {
      final body = <String, dynamic>{
        if (outcome != null) 'outcome': outcome,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };
      final response = await _dio.post(
        'responders/emergencies/$emergencyId/resolve',
        data: body.isEmpty ? null : body,
      );
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

  Future<MedicalProfile> updateMedicalProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        'medical-profile',
        data: data,
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

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('users/$userId');

      if (response.statusCode == 200) {
        return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
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
  /// POST /api/caregivers/link. The backend reads `email || caregiverEmail ||
  /// patientEmail` and derives the link direction from the caller's JWT role.
  /// [invitingCaregiver] = true for a PATIENT inviting a caregiver (sends
  /// `caregiverEmail`); false for a CAREGIVER inviting a patient (`patientEmail`).
  Future<void> linkCaregiver(
    String email,
    String relationship, {
    bool invitingCaregiver = false,
  }) async {
    try {
      final response = await _dio.post(
        'caregivers/link',
        data: {
          'email': email,
          if (invitingCaregiver) 'caregiverEmail': email else 'patientEmail': email,
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
      final data = response.data['data'];
      if (data == null) return [];
      return data as List;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw NetworkException(message: 'Failed to parse notifications: $e');
    }
  }

  /// Self-hosted push: messages not yet acknowledged by this device
  /// (fallback for pushes missed while the socket was down).
  Future<List<dynamic>> getPendingPush() async {
    try {
      final response = await _dio.get('notifications/pending');
      final data = response.data is Map ? response.data['data'] : null;
      return data is List ? data : const [];
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Self-hosted push: acknowledge delivered messages over HTTP.
  Future<void> ackPush(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _dio.post('notifications/ack', data: {'ids': ids});
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

  Future<dynamic> createOrGetChatRoom(String targetUserId, {String? emergencyId}) async {
    try {
      final data = <String, dynamic>{'targetUserId': targetUserId};
      if (emergencyId != null) data['emergencyId'] = emergencyId;
      final response = await _dio.post('chat/rooms', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      throw NetworkException(message: 'Failed to access chat room');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// AI-powered emergency type classification from symptom text.
  Future<Map<String, dynamic>> classifyEmergencySymptoms(String symptoms) async {
    try {
      final response = await _dio.post(
        'emergencies/classify',
        data: {'symptoms': symptoms},
      );
      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw NetworkException(message: 'Failed to classify symptoms');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// AI-personalized AAC quick-reply cards for deaf patients.
  Future<List<Map<String, dynamic>>> getDeafQuickReplies(String emergencyId) async {
    try {
      final response = await _dio.post('emergencies/$emergencyId/quick-replies');
      if (response.statusCode == 200) {
        final raw = response.data['data'];
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      throw NetworkException(message: 'Failed to fetch quick replies');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Create or get an emergency chat room — patient side, no responderId needed.
  /// Backend auto-resolves the assigned responder from the emergency record.
  Future<dynamic> createOrGetEmergencyChatRoom(String emergencyId) async {
    try {
      final response = await _dio.post('chat/rooms', data: {'emergencyId': emergencyId});
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      throw NetworkException(message: 'Failed to access emergency chat room');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> uploadChatFile(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(RegExp(r'[/\\]')).last,
        ),
      });
      final response = await _dio.post('chat/upload', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Accept both {data: {url}} and a bare {url} (the server used to send the latter)
        final body = response.data;
        final data = body is Map && body['data'] is Map ? body['data'] : body;
        if (data is Map && data['url'] is String) return Map<String, dynamic>.from(data);
      }
      throw NetworkException(message: 'Failed to upload chat file');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> uploadRegistrationDocument(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(RegExp(r'[/\\]')).last,
        ),
      });
      // NO AUTH REQUIRED for this specific endpoint
      final response = await _dio.post('auth/upload-document', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw NetworkException(message: 'Failed to upload registration document');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// POST /api/responders/:responderId/rate
  /// Patient submits 1–5 star rating for a responder after emergency resolution.
  Future<Map<String, dynamic>> rateResponder(
      String responderId, String emergencyId, int stars) async {
    try {
      final response = await _dio.post(
        'responders/$responderId/rate',
        data: {'emergencyId': emergencyId, 'stars': stars},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (response.data['data'] as Map<String, dynamic>?) ?? {};
      }
      throw NetworkException(message: 'Failed to submit rating');
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
        final responseData = e.response?.data;
        final errorMessage = (responseData is Map ? responseData['error'] : null) ?? 'Error occurred (status $statusCode)';
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
        final innerError = e.error?.toString() ?? e.message ?? 'Unknown error';
        return NetworkException(
          message: 'Network connection issue: $innerError',
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
