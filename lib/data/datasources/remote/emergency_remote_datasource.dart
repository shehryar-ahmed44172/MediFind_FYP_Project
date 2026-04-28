/// Emergency Remote Data Source
/// Handles API communication for emergency operations
library;

import 'package:dio/dio.dart';
import '../../../domain/entities/emergency.dart';
import '../../../domain/entities/medical_profile.dart';

class EmergencyRemoteDataSource {
  final Dio _dio;
  static const String _baseUrl = '/api/emergencies';

  EmergencyRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  /// Create a new emergency
  /// API: POST /api/emergencies
  /// Automatically attaches medical profile if provided
  Future<Emergency> createEmergency({
    required String userId,
    required String emergencyType,
    required double latitude,
    required double longitude,
    required MedicalProfile? medicalProfile,
    String? additionalInfo,
  }) async {
    try {
      final requestBody = {
        'userId': userId,
        'emergencyType': emergencyType,
        'latitude': latitude,
        'longitude': longitude,
        'additionalInfo': additionalInfo ?? '',
        if (medicalProfile != null) ...{
          'medicalProfile': {
            'bloodType': medicalProfile.bloodType,
            'allergies': medicalProfile.allergies,
            'chronicDiseases': medicalProfile.chronicDiseases,
            'medications': medicalProfile.medications.map((m) => m.toJson()).toList(),
            'disabilityType': medicalProfile.disabilityType,
          }
        }
      };

      final response = await _dio.post(_baseUrl, data: requestBody);

      if (response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>;
        return Emergency.fromJson(data);
      }

      throw Exception('Failed to create emergency: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Cancel an emergency (within 10 second window)
  /// API: POST /api/emergencies/{emergencyId}/cancel
  Future<void> cancelEmergency({
    required String emergencyId,
    required String cancellationReason,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/$emergencyId/cancel',
        data: {'cancellationReason': cancellationReason},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to cancel emergency: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get emergency details
  /// API: GET /api/emergencies/{emergencyId}
  Future<Emergency?> getEmergency(String emergencyId) async {
    try {
      final response = await _dio.get('$_baseUrl/$emergencyId');

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return Emergency.fromJson(data);
      }

      if (response.statusCode == 404) return null;

      throw Exception('Failed to fetch emergency: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get all emergencies for a user
  /// API: GET /api/emergencies?userId={userId}&limit=50&skip=0
  Future<List<Emergency>> getUserEmergencies(String userId) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'userId': userId,
          'limit': 50,
          'skip': 0,
        },
      );

      if (response.statusCode == 200) {
        final items = response.data['data'] as List;
        return items
            .map((e) => Emergency.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to fetch emergencies: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Update emergency status
  /// API: PUT /api/emergency-tracking/{emergencyId}
  Future<void> updateEmergencyStatus({
    required String emergencyId,
    required String newStatus,
  }) async {
    try {
      final response = await _dio.put(
        '$_baseUrl/$emergencyId/status',
        data: {'status': newStatus},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get nearby emergencies for responders
  /// API: GET /api/emergencies/nearby?latitude=&longitude=&radius=5
  Future<List<Emergency>> getNearbyEmergencies({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radiusKm,
        },
      );

      if (response.statusCode == 200) {
        final items = response.data['data'] as List;
        return items
            .map((e) => Emergency.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to fetch nearby emergencies: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Escalate emergency to next batch of responders
  /// API: POST /api/emergencies/{emergencyId}/escalate
  Future<void> escalateEmergency(String emergencyId) async {
    try {
      final response = await _dio.post('$_baseUrl/$emergencyId/escalate');

      if (response.statusCode != 200) {
        throw Exception('Failed to escalate emergency: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Handle Dio exceptions
  Exception _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return Exception('Connection timeout during emergency operation');
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return Exception('Server took too long to respond');
    }
    if (e.type == DioExceptionType.unknown) {
      return Exception('Network error: ${e.message}');
    }
    return Exception('API Error: ${e.message}');
  }
}
