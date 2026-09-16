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
  await ref.watch(authRepositoryProvider.future);
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getCaregiverLinks();
});

final pendingInvitationsProvider = FutureProvider<List<CaregiverConnection>>((ref) async {
  await ref.watch(authRepositoryProvider.future);
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getPendingInvitations();
});

// Send invitation action.
// Keys: `caregiverEmail` when a PATIENT invites a caregiver, or `patientEmail`
// when a CAREGIVER invites a patient; plus `relationship`.
final sendInvitationProvider = FutureProvider.family<void, Map<String, String>>((ref, data) async {
  await ref.watch(authRepositoryProvider.future);
  final repo = ref.watch(connectionRepositoryProvider);
  final caregiverEmail = data['caregiverEmail'];
  final relationship = data['relationship']!;

  if (caregiverEmail != null && repo is ConnectionRepositoryImpl) {
    await repo.sendInvitation(caregiverEmail, relationship, invitingCaregiver: true);
  } else {
    // Backend derives the direction from the caller's role, so the generic
    // path is still correct for any other implementation.
    await repo.sendInvitation(
      caregiverEmail ?? data['patientEmail'] ?? data['email']!,
      relationship,
    );
  }

  ref.invalidate(getLinkedPatientsProvider);
  ref.invalidate(allCaregiverLinksProvider);
  ref.invalidate(caregiverLinksProvider);
});

final allCaregiverLinksProvider = FutureProvider<List<CaregiverConnection>>((ref) async {
  await ref.watch(authRepositoryProvider.future);
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getPatientsForCaregiverExtended();
});

final resendInvitationProvider = FutureProvider.family<void, String>((ref, patientId) async {
  await ref.watch(authRepositoryProvider.future);
  final repo = ref.watch(connectionRepositoryProvider);
  await repo.resendInvitation(patientId);
  ref.invalidate(allCaregiverLinksProvider);
});

// Respond to invitation action
final respondToInvitationProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, data) async {
  await ref.watch(authRepositoryProvider.future);
  final repo = ref.watch(connectionRepositoryProvider);
  await repo.respondToInvitation(data['invitationId'] as String, data['accept'] as bool);
  
  ref.invalidate(getLinkedPatientsProvider);
  ref.invalidate(pendingInvitationsProvider);
});

final getLinkedPatientsProvider = FutureProvider<List<CaregiverConnection>>((ref) async {
  await ref.watch(authRepositoryProvider.future);
  final repo = ref.watch(connectionRepositoryProvider);
  return repo.getCaregiverLinks();
});
