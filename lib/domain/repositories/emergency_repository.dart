import '../entities/emergency.dart';
import '../entities/user.dart';

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

  Future<void> acceptEmergency(String emergencyId, String responderId);

  Future<void> rejectEmergency(String emergencyId, String responderId);
  
  Future<List<Emergency>> getActiveEmergencies();
  
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

  Future<void> resolveEmergency(String emergencyId);
  
  Future<void> cancelAssignment(String emergencyId);

  Future<void> updateResponderLocation(double latitude, double longitude);

  Future<void> updateResponderAvailability(bool isAvailable);
  
  Future<List<dynamic>> getResponderHistory();

  Future<List<User>> getNearbyResponders(double latitude, double longitude);
}
