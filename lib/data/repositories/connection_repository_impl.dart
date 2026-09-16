import '../../domain/entities/caregiver_connection.dart';
import '../../domain/repositories/connection_repository.dart';
import '../datasources/remote/medifind_api_client.dart';

class ConnectionRepositoryImpl implements ConnectionRepository {
  final MediFindApiClient apiClient;

  ConnectionRepositoryImpl({required this.apiClient});

  /// [email] is the invited user's email. Set [invitingCaregiver] when a
  /// PATIENT invites a caregiver; default (false) is a CAREGIVER inviting a
  /// patient, which keeps the existing interface call compatible.
  @override
  Future<void> sendInvitation(
    String email,
    String relationship, {
    bool invitingCaregiver = false,
  }) async {
    await apiClient.linkCaregiver(
      email,
      relationship,
      invitingCaregiver: invitingCaregiver,
    );
  }

  @override
  Future<List<CaregiverConnection>> getCaregiverLinks() async {
    final linksJson = await apiClient.getCaregiverLinks();
    return linksJson
        .map((json) => CaregiverConnection.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> unlinkCaregiver(String connectionId) async {
    await apiClient.unlinkCaregiver(connectionId);
  }

  @override
  Future<void> respondToInvitation(String invitationId, bool accept) async {
    await apiClient.respondToInvitation(invitationId, accept);
  }

  @override
  Future<List<CaregiverConnection>> getPendingInvitations() async {
    final linksJson = await apiClient.getPendingInvitations();
    return linksJson
        .map((json) => CaregiverConnection.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CaregiverConnection>> getPatientsForCaregiverExtended() async {
    final linksJson = await apiClient.getAllCaregiverLinks();
    return linksJson
        .map((json) => CaregiverConnection.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> resendInvitation(String patientId) async {
    await apiClient.resendInvitation(patientId);
  }
}
