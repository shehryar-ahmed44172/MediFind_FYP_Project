import '../../domain/entities/caregiver_connection.dart';
import '../../domain/repositories/connection_repository.dart';
import '../datasources/remote/medifind_api_client.dart';

class ConnectionRepositoryImpl implements ConnectionRepository {
  final MediFindApiClient apiClient;

  ConnectionRepositoryImpl({required this.apiClient});

  @override
  Future<void> sendInvitation(String patientEmail, String relationship) async {
    await apiClient.linkCaregiver(patientEmail, relationship);
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
}
