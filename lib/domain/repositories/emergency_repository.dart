import '../entities/emergency.dart';
import '../entities/user.dart';
import '../entities/responder_alert.dart';
import '../../data/datasources/remote/medifind_api_client.dart' show CreateEmergencyResult;

/// Abstract repository for emergency operations
abstract class EmergencyRepository {
  Future<CreateEmergencyResult> createEmergency(
    String emergencyType,
    double latitude,
    double longitude,
    String? additionalInfo, {
    bool isMocked = false,
  });
  
  Future<Emergency> getEmergency(String emergencyId);
  
  Future<List<Emergency>> getUserEmergencies(String userId);
  
  Future<void> updateEmergencyStatus(String emergencyId, String status, {double? latitude, double? longitude});
  
  Future<void> assignResponder(String emergencyId, String responderId);

  Future<void> acceptEmergency(String emergencyId, String responderId);

  Future<void> rejectEmergency(String emergencyId, String responderId);
  
  Future<List<Emergency>> getActiveEmergencies();
  
  Future<List<Emergency>> getResponderActiveRequests();

  /// Fetches this responder's live requests from the server and syncs the
  /// local cache (stale/cancelled entries removed). Falls back to cache offline.
  Future<List<ResponderAlert>> syncResponderAlerts(String? responderId);
  
  Future<void> updateEmergencyLocation(
    String emergencyId,
    double latitude,
    double longitude,
  );
  
  Future<void> generateVoiceAlert(String emergencyId);
  
  Stream<Emergency> watchEmergency(String emergencyId);
  
  Stream<List<Emergency>> watchUserEmergencies(String userId);

  Stream<List<Emergency>> watchActiveEmergencies();

  Future<void> cancelEmergency(String emergencyId);

  /// Closes the emergency with an optional [outcome] and [note].
  Future<void> resolveEmergency(String emergencyId, {String? outcome, String? note});
  
  Future<void> cancelAssignment(String emergencyId);

  Future<void> updateResponderLocation(double latitude, double longitude);

  Future<void> updateResponderAvailability(bool isAvailable);
  
  Future<List<dynamic>> getResponderHistory();

  Future<List<User>> getNearbyResponders(double latitude, double longitude);
}
