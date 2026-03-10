import 'package:freezed_annotation/freezed_annotation.dart';

part 'medical_profile.freezed.dart';
part 'medical_profile.g.dart';

@freezed
class MedicalProfile with _$MedicalProfile {
  const factory MedicalProfile({
    required String id,
    required String userId,
    required String bloodType,
    @Default([]) List<String> chronicDiseases,
    @Default([]) List<String> allergies,
    @Default([]) List<Medication> medications,
    @Default([]) List<EmergencyContact> emergencyContacts,
    String? medicalHistory,
    String? disabilityType,
    String? additionalNotes,
    DateTime? lastUpdated,
  }) = _MedicalProfile;

  factory MedicalProfile.fromJson(Map<String, dynamic> json) =>
      _$MedicalProfileFromJson(json);
}

@freezed
class Medication with _$Medication {
  const factory Medication({
    required String name,
    @Default('') String dosage,
    @Default('') String frequency,
    String? reason,
  }) = _Medication;

  factory Medication.fromJson(Map<String, dynamic> json) =>
      _$MedicationFromJson(json);
}

@freezed
class EmergencyContact with _$EmergencyContact {
  const factory EmergencyContact({
    required String name,
    required String phoneNumber,
    @Default('Family') String relationship,
  }) = _EmergencyContact;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      _$EmergencyContactFromJson(json);
}

@freezed
class UpdateMedicalProfileRequest with _$UpdateMedicalProfileRequest {
  const factory UpdateMedicalProfileRequest({
    required String bloodType,
    required List<String> chronicDiseases,
    required List<String> allergies,
    required List<Map<String, dynamic>> medications,
    required List<Map<String, dynamic>> emergencyContacts,
    String? medicalHistory,
    String? disabilityType,
    String? additionalNotes,
  }) = _UpdateMedicalProfileRequest;

  factory UpdateMedicalProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateMedicalProfileRequestFromJson(json);
}
