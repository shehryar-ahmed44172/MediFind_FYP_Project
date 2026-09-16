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
      // The backend PUT (medicalProfileService.updateMedicalProfile) replaces
      // any ABSENT array key with [] - so omitting `emergencyContacts`
      // (or `disabilities` / `predefinedMessages`) would still wipe them.
      // Contacts are managed through the dedicated add/remove endpoints, so a
      // profile edit re-sends the server's current values for these lists
      // untouched. If they can't be read, the update is aborted rather than
      // risking data loss.
      final current = await _fetchCurrentRawProfile();

      final response = await _dio.put(
        'medical-profile',
        data: {
          'bloodType': bloodType,
          'disabilityType': disabilityType,
          'chronicDiseases': chronicDiseases,
          'allergies': allergies,
          'medications': medications,
          'emergencyContacts':
              emergencyContacts ?? _listOrEmpty(current['emergencyContacts']),
          'disabilities': _listOrEmpty(current['disabilities']),
          'predefinedMessages': _listOrEmpty(current['predefinedMessages']),
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

  /// POST /api/medical-profile/emergency-contacts
  Future<List<Map<String, dynamic>>> addEmergencyContact({
    required String name,
    required String phoneNumber,
    required String relationship,
  }) async {
    try {
      final response = await _dio.post(
        'medical-profile/emergency-contacts',
        data: {
          'name': name,
          'phoneNumber': phoneNumber,
          'relationship': relationship,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final contacts = response.data['data']['emergencyContacts'] as List<dynamic>;
        return contacts.map((c) => Map<String, dynamic>.from(c as Map)).toList();
      }
      throw NetworkException(message: 'Failed to add emergency contact');
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// DELETE /api/medical-profile/emergency-contacts/:phone
  Future<void> removeEmergencyContact(String phoneNumber) async {
    try {
      final encoded = Uri.encodeComponent(phoneNumber);
      final response = await _dio.delete(
        'medical-profile/emergency-contacts/$encoded',
      );
      if (response.statusCode != 200) {
        throw NetworkException(message: 'Failed to remove emergency contact');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Reads the raw profile JSON currently stored on the server (throws on
  /// failure so callers never overwrite lists they could not read).
  Future<Map<String, dynamic>> _fetchCurrentRawProfile() async {
    final response = await _dio.get('medical-profile');
    final data = response.data;
    if (response.statusCode == 200 && data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw NetworkException(
      message: 'Could not load your current profile. Please try again.',
    );
  }

  List<dynamic> _listOrEmpty(dynamic value) => value is List ? value : const [];

  AppException _handleDioException(DioException e) {
    final data = e.response?.data;
    final errorMessage =
        (data is Map ? data['error']?.toString() : null) ?? 'Error occurred';
    return NetworkException(
      message: errorMessage,
      originalException: e,
    );
  }
}
