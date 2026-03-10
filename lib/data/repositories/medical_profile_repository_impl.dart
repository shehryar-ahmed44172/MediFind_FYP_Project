import 'dart:convert';
import '../../domain/entities/medical_profile.dart';
import '../../domain/repositories/medical_profile_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/medifind_api_client.dart';

class MedicalProfileRepositoryImpl implements MedicalProfileRepository {
  final MediFindApiClient apiClient;
  final LocalDataSource localDataSource;

  MedicalProfileRepositoryImpl({
    required this.apiClient,
    required this.localDataSource,
  });

  // ---------------------------------------------------------------------------
  // Helper: convert MedicalProfile → Map (for local storage)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _profileToMap(MedicalProfile p) => {
        'id': p.id,
        'userId': p.userId,
        'bloodType': p.bloodType,
        'chronicDiseases': p.chronicDiseases,
        'allergies': p.allergies,
        'medications': p.medications.map((m) => m.toJson()).toList(),
        'emergencyContacts':
            p.emergencyContacts.map((c) => c.toJson()).toList(),
        'medicalHistory': p.medicalHistory,
        'disabilityType': p.disabilityType,
        'additionalNotes': p.additionalNotes,
        'lastUpdated': p.lastUpdated?.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Helper: convert Map → MedicalProfile (from local storage)
  // ---------------------------------------------------------------------------
  MedicalProfile _mapToProfile(Map<String, dynamic> map) {
    return MedicalProfile(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      bloodType: map['bloodType'] as String? ?? '',
      chronicDiseases: List<String>.from(map['chronicDiseases'] ?? []),
      allergies: List<String>.from(map['allergies'] ?? []),
      medications: (map['medications'] as List<dynamic>?)
              ?.map((m) => Medication.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      emergencyContacts: (map['emergencyContacts'] as List<dynamic>?)
              ?.map(
                  (c) => EmergencyContact.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      medicalHistory: map['medicalHistory'] as String?,
      disabilityType: map['disabilityType'] as String?,
      additionalNotes: map['additionalNotes'] as String?,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'] as String)
          : null,
    );
  }

  @override
  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    try {
      // Try cache first
      final cached = await localDataSource.getMedicalProfile(userId);
      if (cached != null) {
        // Fetch fresh in background
        try {
          final fresh = await apiClient.getMedicalProfile(userId);
          await localDataSource.saveMedicalProfile(_profileToMap(fresh));
          return fresh;
        } catch (_) {
          return _mapToProfile(cached);
        }
      }
    } catch (_) {
      // Fall through to API call
    }

    try {
      final profile = await apiClient.getMedicalProfile(userId);
      await localDataSource.saveMedicalProfile(_profileToMap(profile));
      return profile;
    } catch (_) {
      return null; // no profile yet
    }
  }

  @override
  Future<MedicalProfile> updateMedicalProfile(
    String userId,
    String bloodType,
    String? disabilityType,
    List<String> allergies,
    List<String> chronicDiseases,
    List<Medication> medications,
    String? additionalNotes,
  ) async {
    final medicationsJson = medications.map((m) => m.toJson()).toList();

    final profile = await apiClient.updateMedicalProfile(
      userId,
      bloodType,
      chronicDiseases,
      allergies,
      medicationsJson,
      [], // emergency contacts — managed separately
      additionalNotes,
    );
    await localDataSource.saveMedicalProfile(_profileToMap(profile));
    return profile;
  }

  @override
  Future<void> addMedication(String userId, Medication medication) async {
    final profile = await getMedicalProfile(userId);
    if (profile == null) return;
    final updated = profile.copyWith(
      medications: [...profile.medications, medication],
    );
    await updateMedicalProfile(
      userId,
      updated.bloodType,
      updated.disabilityType,
      updated.allergies,
      updated.chronicDiseases,
      updated.medications,
      updated.additionalNotes,
    );
  }

  @override
  Future<void> removeMedication(String userId, String medicationName) async {
    final profile = await getMedicalProfile(userId);
    if (profile == null) return;
    final updated = profile.copyWith(
      medications:
          profile.medications.where((m) => m.name != medicationName).toList(),
    );
    await updateMedicalProfile(
      userId,
      updated.bloodType,
      updated.disabilityType,
      updated.allergies,
      updated.chronicDiseases,
      updated.medications,
      updated.additionalNotes,
    );
  }

  @override
  Future<void> addEmergencyContact(
      String userId, EmergencyContact contact) async {
    final profile = await getMedicalProfile(userId);
    if (profile == null) return;
    final updated = profile.copyWith(
      emergencyContacts: [...profile.emergencyContacts, contact],
    );
    await localDataSource.saveMedicalProfile(_profileToMap(updated));
  }

  @override
  Future<void> removeEmergencyContact(
      String userId, String contactName) async {
    final profile = await getMedicalProfile(userId);
    if (profile == null) return;
    final updated = profile.copyWith(
      emergencyContacts: profile.emergencyContacts
          .where((c) => c.name != contactName)
          .toList(),
    );
    await localDataSource.saveMedicalProfile(_profileToMap(updated));
  }

  @override
  Stream<MedicalProfile> watchMedicalProfile(String userId) async* {
    // Watch Hive box events and emit on changes
    await for (final _ in localDataSource.watchEmergencies()) {
      final cached = await localDataSource.getMedicalProfile(userId);
      if (cached != null) yield _mapToProfile(cached);
    }
  }
}
