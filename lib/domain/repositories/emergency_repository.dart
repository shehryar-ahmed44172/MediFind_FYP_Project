import '../entities/emergency.dart';

/// Abstract repository for emergency operations
abstract class EmergencyRepository {
  Future<Emergency> createEmergency(
    String emergencyType,
    double latitude,
    double longitude,
    String? additionalInfo,
  );
  
  Future<Emergency> getEmergency(String emergencyId);
  
  Future<List<Emergency>> getUserEmergencies(String userId);
  
  Future<void> updateEmergencyStatus(String emergencyId, String status);
  
  Future<void> assignResponder(String emergencyId, String responderId);
  
  Future<void> updateEmergencyLocation(
    String emergencyId,
    double latitude,
    double longitude,
  );
  
  Future<void> generateVoiceAlert(String emergencyId);
  
  Stream<Emergency> watchEmergency(String emergencyId);
  
  Stream<List<Emergency>> watchUserEmergencies(String userId);
}
