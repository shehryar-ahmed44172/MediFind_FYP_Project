import '../entities/medical_profile.dart';

/// Abstract repository for medical profile operations
abstract class MedicalProfileRepository {
  Future<MedicalProfile?> getMedicalProfile([String? userId]);

  Future<MedicalProfile> updateMedicalProfile({
    required String bloodType,
    String? disabilityType,
    required List<String> allergies,
    required List<String> chronicDiseases,
    required List<Medication> medications,
    String? additionalNotes,
  });

  Future<void> addMedication(String userId, Medication medication);

  Future<void> removeMedication(String userId, String medicationName);

  Future<void> addEmergencyContact(String userId, EmergencyContact contact);

  Future<void> removeEmergencyContact(String userId, String contactName);

  Stream<MedicalProfile> watchMedicalProfile(String userId);

  Future<void> deleteMedicalProfile(String userId);
}
