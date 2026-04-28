import 'package:dio/dio.dart';
import '../../../domain/entities/medical_profile.dart';
import '../../../core/utils/exceptions.dart';

class MedicalProfileRemoteDataSource {
  final Dio _dio;

  MedicalProfileRemoteDataSource(this._dio);

  Future<MedicalProfile> getMedicalProfile([String? userId]) async {
    try {
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
    String? disabilityType,
    required List<String> chronicDiseases,
    required List<String> allergies,
    required List<Map<String, dynamic>> medications,
    List<Map<String, dynamic>>? emergencyContacts,
    String? additionalNotes,
  }) async {
    try {
      final response = await _dio.put(
        'medical-profile',
        data: {
          'bloodType': bloodType,
          'disabilityType': disabilityType,
          'chronicDiseases': chronicDiseases,
          'allergies': allergies,
          'medications': medications,
          'emergencyContacts': emergencyContacts ?? [],
          'additionalNotes': additionalNotes,
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

  AppException _handleDioException(DioException e) {
    final errorMessage = e.response?.data['error'] ?? 'Error occurred';
    return NetworkException(
      message: errorMessage,
      originalException: e,
    );
  }
}
