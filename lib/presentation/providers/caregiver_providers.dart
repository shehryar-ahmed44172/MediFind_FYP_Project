import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/connection_repository_impl.dart';
import '../../domain/entities/caregiver_connection.dart';
import '../../domain/repositories/connection_repository.dart';
import 'auth_provider.dart';

// Repository Provider
final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ConnectionRepositoryImpl(apiClient: apiClient);
});

// Providers for data fetching
final caregiverLinksProvider = FutureProvider<List<CaregiverConnection>>((ref) async {
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getCaregiverLinks();
});

final pendingInvitationsProvider = FutureProvider<List<CaregiverConnection>>((ref) async {
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getPendingInvitations();
});

// Send invitation action
final sendInvitationProvider = FutureProvider.family<void, Map<String, String>>((ref, data) async {
  final repo = ref.watch(connectionRepositoryProvider);
  await repo.sendInvitation(data['patientEmail']!, data['relationship']!);
  
  ref.invalidate(getLinkedPatientsProvider);
  ref.invalidate(allCaregiverLinksProvider);
});

final allCaregiverLinksProvider = FutureProvider<List<CaregiverConnection>>((ref) async {
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getPatientsForCaregiverExtended();
});

final resendInvitationProvider = FutureProvider.family<void, String>((ref, patientId) async {
  final repo = ref.watch(connectionRepositoryProvider);
  await repo.resendInvitation(patientId);
  ref.invalidate(allCaregiverLinksProvider);
});

// Respond to invitation action
final respondToInvitationProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, data) async {
  final repo = ref.watch(connectionRepositoryProvider);
  await repo.respondToInvitation(data['invitationId'] as String, data['accept'] as bool);
  
  ref.invalidate(getLinkedPatientsProvider);
  ref.invalidate(pendingInvitationsProvider);
});

final getLinkedPatientsProvider = FutureProvider<List<CaregiverConnection>>((ref) async {
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getCaregiverLinks();
});
