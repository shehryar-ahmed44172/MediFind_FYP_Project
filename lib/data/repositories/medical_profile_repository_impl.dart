import '../../../domain/entities/medical_profile.dart';
import '../../../domain/repositories/medical_profile_repository.dart';
import '../datasources/local/medical_profile_local_datasource.dart';
import '../datasources/remote/medical_profile_remote_datasource.dart';
import 'package:dio/dio.dart';
import '../../../core/utils/exceptions.dart';

class MedicalProfileRepositoryImpl implements MedicalProfileRepository {
  final MedicalProfileRemoteDataSource remoteDataSource;
  final MedicalProfileLocalDataSource localDataSource;

  MedicalProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<MedicalProfile?> getMedicalProfile([String? userId]) async {
    try {
      // 1. Try to fetch from remote
      final profile = await remoteDataSource.getMedicalProfile(userId);
      
      // 2. Cache locally on success
      await localDataSource.saveMedicalProfile(profile.toJson());
      
      return profile;
    } catch (e) {
      // Handle "Not Found" case gracefully - user just hasn't created a profile yet
      if (e is NetworkException && e.originalException is DioException) {
        final dioError = e.originalException as DioException;
        if (dioError.response?.statusCode == 404) {
          return null; // Valid state: no profile yet
        }
      }

      // 3. Fallback to local data if remote fails for other reasons
      if (userId != null) {
        final localData = await localDataSource.getMedicalProfile(userId);
        if (localData != null) {
          return MedicalProfile.fromJson(localData);
        }
      }
      
      // 4. If we have no remote data and no local data, assume the profile doesn't exist yet
      // This prevents the user from seeing a generic 'Error occurred' screen and being unable to create one.
      return null;
    }
  }

  @override
  Future<MedicalProfile> updateMedicalProfile({
    required String bloodType,
    String? disabilityType,
    required List<String> allergies,
    required List<String> chronicDiseases,
    required List<Medication> medications,
    String? additionalNotes,
  }) async {
    // 1. Always attempt remote update first
    final updatedProfile = await remoteDataSource.updateMedicalProfile(
      bloodType: bloodType,
      disabilityType: disabilityType,
      chronicDiseases: chronicDiseases,
      allergies: allergies,
      medications: medications.map((m) => m.toJson()).toList(),
      additionalNotes: additionalNotes,
    );

    // 2. Sync local cache
    await localDataSource.saveMedicalProfile(updatedProfile.toJson());
    
    return updatedProfile;
  }

  @override
  Future<void> addMedication(String userId, Medication medication) async {
    final profile = await getMedicalProfile(userId);
    if (profile != null) {
      final updatedMedications = [...profile.medications, medication];
      await updateMedicalProfile(
        bloodType: profile.bloodType,
        disabilityType: profile.disabilityType,
        allergies: profile.allergies,
        chronicDiseases: profile.chronicDiseases,
        medications: updatedMedications,
        additionalNotes: profile.additionalNotes,
      );
    }
  }

  @override
  Future<void> removeMedication(String userId, String medicationName) async {
    final profile = await getMedicalProfile(userId);
    if (profile != null) {
      final updatedMedications = profile.medications
          .where((m) => m.name != medicationName)
          .toList();
      await updateMedicalProfile(
        bloodType: profile.bloodType,
        disabilityType: profile.disabilityType,
        allergies: profile.allergies,
        chronicDiseases: profile.chronicDiseases,
        medications: updatedMedications,
        additionalNotes: profile.additionalNotes,
      );
    }
  }

  @override
  Future<void> addEmergencyContact(String userId, EmergencyContact contact) async {
    final profile = await getMedicalProfile(userId);
    if (profile == null) return;
    final updatedContacts = [...profile.emergencyContacts, contact];
    final updated = await remoteDataSource.updateMedicalProfile(
      bloodType: profile.bloodType,
      disabilityType: profile.disabilityType,
      allergies: profile.allergies,
      chronicDiseases: profile.chronicDiseases,
      medications: profile.medications.map((m) => m.toJson()).toList(),
      emergencyContacts: updatedContacts.map((c) => c.toJson()).toList(),
      additionalNotes: profile.additionalNotes,
    );
    await localDataSource.saveMedicalProfile(updated.toJson());
  }

  @override
  Future<void> removeEmergencyContact(String userId, String contactName) async {
    final profile = await getMedicalProfile(userId);
    if (profile == null) return;
    final updatedContacts = profile.emergencyContacts
        .where((c) => c.name != contactName)
        .toList();
    final updated = await remoteDataSource.updateMedicalProfile(
      bloodType: profile.bloodType,
      disabilityType: profile.disabilityType,
      allergies: profile.allergies,
      chronicDiseases: profile.chronicDiseases,
      medications: profile.medications.map((m) => m.toJson()).toList(),
      emergencyContacts: updatedContacts.map((c) => c.toJson()).toList(),
      additionalNotes: profile.additionalNotes,
    );
    await localDataSource.saveMedicalProfile(updated.toJson());
  }

  @override
  Stream<MedicalProfile> watchMedicalProfile(String userId) {
    // Basic implementation watching the local box
    // Note: This requires the local data source to expose a stream
    return const Stream.empty(); // Stub for build
  }

  @override
  Future<void> deleteMedicalProfile(String userId) async {
    // Logic for deletion (standard requirement)
    await localDataSource.deleteMedicalProfile(userId);
    // Note: Remote deletion would go here if endpoint exists
  }
}
