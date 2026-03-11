/// Medical Profile Remote Data Source
/// Handles API communication for medical profile operations

import 'package:dio/dio.dart';
import '../../../domain/entities/medical_profile.dart';

class MedicalProfileRemoteDataSource {
  final Dio _dio;
  static const String _baseUrl = '/api/medical-profiles';

  MedicalProfileRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  /// Get medical profile for a user
  /// API: GET /api/medical-profiles/{userId}
  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    try {
      final response = await _dio.get('$_baseUrl/$userId');

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return MedicalProfile.fromJson(data);
      }

      if (response.statusCode == 404) {
        return null; // Profile doesn't exist yet
      }

      throw Exception('Failed to fetch medical profile: ${response.statusCode}');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Update or create medical profile
  /// API: PUT /api/medical-profiles/{userId}
  Future<MedicalProfile> updateMedicalProfile(
    String userId,
    MedicalProfile profile,
  ) async {
    try {
      final response = await _dio.put(
        '$_baseUrl/$userId',
        data: {
          'bloodGroup': profile.bloodGroup,
          'allergies': profile.allergies ?? [],
          'chronicDiseases': profile.chronicDiseases ?? [],
          'medications': profile.medications ?? [],
          'disabilities': profile.disabilities ?? [],
          'emergencyContactName': profile.emergencyContactName,
          'emergencyContactPhone': profile.emergencyContactPhone,
          'medicalHistory': profile.medicalHistory,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>;
        return MedicalProfile.fromJson(data);
      }

      throw Exception(
        'Failed to update medical profile: ${response.statusCode}',
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Delete medical profile
  /// API: DELETE /api/medical-profiles/{userId}
  Future<void> deleteMedicalProfile(String userId) async {
    try {
      final response = await _dio.delete('$_baseUrl/$userId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete medical profile: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Handle Dio exceptions
  Exception _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return Exception('Connection timeout while accessing medical profile');
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
