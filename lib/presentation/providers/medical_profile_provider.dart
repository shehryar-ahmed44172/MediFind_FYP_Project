import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/medical_profile_repository_impl.dart';
import '../../domain/entities/medical_profile.dart';
import '../../domain/repositories/medical_profile_repository.dart';
import 'auth_provider.dart';

// Medical profile repository provider
final medicalProfileRepositoryProvider =
    FutureProvider<MedicalProfileRepository>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final localDataSource = await ref.watch(localDataSourceProvider.future);
  return MedicalProfileRepositoryImpl(
    apiClient: apiClient,
    localDataSource: localDataSource,
  );
});

// Get medical profile for a userId
final getMedicalProfileProvider =
    FutureProvider.family<MedicalProfile?, String>((ref, userId) async {
  final repo = await ref.watch(medicalProfileRepositoryProvider.future);
  return await repo.getMedicalProfile(userId);
});

// Update medical profile
final updateMedicalProfileProvider =
    FutureProvider.family<void, UpdateMedicalProfileParams>(
        (ref, params) async {
  final repo = await ref.watch(medicalProfileRepositoryProvider.future);

  // Convert plain string medications to Medication objects
  final medications = params.medications
      .map((m) => Medication(name: m))
      .toList();

  await repo.updateMedicalProfile(
    params.userId,
    params.bloodType,
    params.disabilityType,
    params.allergies,
    params.chronicDiseases,
    medications,
    params.additionalNotes,
  );

  // Invalidate cache so view screen refreshes
  ref.invalidate(getMedicalProfileProvider(params.userId));
});

class UpdateMedicalProfileParams {
  final String userId;
  final String bloodType;
  final String? disabilityType;
  final List<String> allergies;
  final List<String> chronicDiseases;
  final List<String> medications; // plain strings for simplicity in UI
  final String? additionalNotes;

  UpdateMedicalProfileParams({
    required this.userId,
    required this.bloodType,
    this.disabilityType,
    required this.allergies,
    required this.chronicDiseases,
    required this.medications,
    this.additionalNotes,
  });
}
