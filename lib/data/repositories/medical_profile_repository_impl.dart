import '../../../domain/entities/medical_profile.dart';
import '../../../domain/repositories/medical_profile_repository.dart';
import '../datasources/local/medical_profile_local_datasource.dart';
import '../datasources/remote/medical_profile_remote_datasource.dart';

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
      
      // 2. Cache locally on success (use profile.userId as key)
      await localDataSource.saveMedicalProfile(profile.toJson());
      
      return profile;
    } catch (e) {
      // 3. Fallback to local data if remote fails
      // Note: If userId is null, we need the current user's ID to check local storage
      // For now, if remote fails and no userId is provided, we can't easily find it in local box 
      // unless we assume the only profile in the box is the current user's.
      // But let's check with a known ID if possible.
      if (userId != null) {
        final localData = await localDataSource.getMedicalProfile(userId);
        if (localData != null) {
          return MedicalProfile.fromJson(localData);
        }
      }
      rethrow;
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
    // Current implementation doesn't support structured emergency contacts update
    // This will be implemented when backend supports it
    throw UnimplementedError('addEmergencyContact not yet implemented');
  }

  @override
  Future<void> removeEmergencyContact(String userId, String contactName) async {
    throw UnimplementedError('removeEmergencyContact not yet implemented');
  }

  @override
  Stream<MedicalProfile> watchMedicalProfile(String userId) {
    // Basic implementation watching the local box
    // Note: This requires the local data source to expose a stream
    return Stream.empty(); // Stub for build
  }

  @override
  Future<void> deleteMedicalProfile(String userId) async {
    // Logic for deletion (standard requirement)
    await localDataSource.deleteMedicalProfile(userId);
    // Note: Remote deletion would go here if endpoint exists
  }
}
