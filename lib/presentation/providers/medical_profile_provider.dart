import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/medical_profile_local_datasource.dart';
import '../../data/datasources/remote/medical_profile_remote_datasource.dart';
import '../../data/repositories/medical_profile_repository_impl.dart';
import '../../domain/entities/medical_profile.dart';
import '../../domain/repositories/medical_profile_repository.dart';
import 'auth_provider.dart';
// Specialized data source providers
final medicalProfileRemoteDataSourceProvider = Provider<MedicalProfileRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return MedicalProfileRemoteDataSource(dio);
});

final medicalProfileLocalDataSourceProvider = FutureProvider<MedicalProfileLocalDataSource>((ref) async {
  final ds = MedicalProfileLocalDataSource();
  await ds.init();
  return ds;
});

// Medical profile repository provider
final medicalProfileRepositoryProvider =
    FutureProvider<MedicalProfileRepository>((ref) async {
  final remoteDs = ref.watch(medicalProfileRemoteDataSourceProvider);
  final localDs = await ref.watch(medicalProfileLocalDataSourceProvider.future);
  return MedicalProfileRepositoryImpl(
    remoteDataSource: remoteDs,
    localDataSource: localDs,
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
    bloodType: params.bloodType,
    disabilityType: params.disabilityType,
    allergies: params.allergies,
    chronicDiseases: params.chronicDiseases,
    medications: medications,
    additionalNotes: params.additionalNotes,
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
