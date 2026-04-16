import '../entities/caregiver_connection.dart';

abstract class ConnectionRepository {
  Future<void> sendInvitation(String patientEmail, String relationship);
  Future<List<CaregiverConnection>> getCaregiverLinks();
  Future<void> unlinkCaregiver(String caregiverId);
  Future<void> respondToInvitation(String invitationId, bool accept);
  Future<List<CaregiverConnection>> getPendingInvitations();
}
