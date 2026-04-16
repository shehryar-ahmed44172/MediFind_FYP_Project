import 'dart:async';
import '../../domain/entities/emergency.dart';
import '../../domain/entities/user.dart';

import '../../domain/repositories/emergency_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/medifind_api_client.dart';

class EmergencyRepositoryImpl implements EmergencyRepository {
  final MediFindApiClient apiClient;
  final LocalDataSource localDataSource;

  EmergencyRepositoryImpl({
    required this.apiClient,
    required this.localDataSource,
  });

  @override
  Future<void> cancelEmergency(String emergencyId) async {
    await apiClient.cancelEmergency(emergencyId);
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['status'] = 'CANCELLED';
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<void> resolveEmergency(String emergencyId) async {
    await apiClient.resolveEmergency(emergencyId);
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['status'] = 'COMPLETED';
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<void> updateResponderLocation(double latitude, double longitude) async {
    await apiClient.updateResponderLocation(latitude, longitude);
  }

  @override
  Future<List<User>> getNearbyResponders(double latitude, double longitude) async {
    return await apiClient.getNearbyResponders(latitude, longitude);
  }
  @override
  Future<void> updateResponderAvailability(bool isAvailable) async {
    await apiClient.setResponderAvailability(isAvailable);
  }

  @override
  Future<List<Emergency>> getActiveEmergencies() async {
    final emergencies = await apiClient.getActiveEmergencies();
    for (var e in emergencies) {
      await localDataSource.saveEmergency(_emergencyToMap(e));
    }
    return emergencies;
  }

  @override
  Stream<List<Emergency>> watchActiveEmergencies() async* {
    // Return all emergencies from local storage that are not COMPLETED or CANCELLED
    await for (final _ in localDataSource.watchEmergencies()) {
      final all = await localDataSource.getAllEmergencies();
      yield all
          .map((e) => _mapToEmergency(e))
          .where((e) => e.status != 'COMPLETED' && e.status != 'CANCELLED')
          .toList();
    }
  }


  // ---------------------------------------------------------------------------
  // Helper: convert Emergency → Map (for local storage)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _emergencyToMap(Emergency e) => {
        'id': e.id,
        'userId': e.userId,
        'responderId': e.responderId,
        'status': e.status,
        'emergencyType': e.emergencyType,
        'latitude': e.latitude,
        'longitude': e.longitude,
        'additionalInfo': e.additionalInfo,
        'voiceAlertGenerated': e.voiceAlertGenerated,
        'createdAt': e.createdAt.toIso8601String(),
        'updatedAt': e.updatedAt.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // Helper: convert Map → Emergency (from local storage)
  // ---------------------------------------------------------------------------
  Emergency _mapToEmergency(Map<String, dynamic> map) {
    return Emergency(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      responderId: map['responderId'] as String?,
      status: map['status'] as String? ?? 'PENDING',
      emergencyType: map['emergencyType'] as String? ?? 'OTHER',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      additionalInfo: map['additionalInfo'] as String?,
      voiceAlertGenerated: map['voiceAlertGenerated'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<Emergency> createEmergency(
    String emergencyType,
    double latitude,
    double longitude,
    String? additionalInfo,
  ) async {
    final emergency = await apiClient.createEmergency(
      emergencyType,
      latitude,
      longitude,
      additionalInfo,
    );
    await localDataSource.saveEmergency(_emergencyToMap(emergency));
    return emergency;
  }

  @override
  Future<Emergency> getEmergency(String emergencyId) async {
    try {
      final fresh = await apiClient.getEmergency(emergencyId);
      await localDataSource.saveEmergency(_emergencyToMap(fresh));
      return fresh;
    } catch (_) {
      final cached = await localDataSource.getEmergency(emergencyId);
      if (cached != null) return _mapToEmergency(cached);
      rethrow;
    }
  }


  @override
  Future<List<Emergency>> getUserEmergencies(String userId) async {
    try {
      final cached = await localDataSource.getUserEmergencies(userId);
      if (cached.isNotEmpty) {
        try {
          final fresh = await apiClient.getUserEmergencies(userId);
          for (var e in fresh) {
            await localDataSource.saveEmergency(_emergencyToMap(e));
          }
          return fresh;
        } catch (_) {
          return cached.map((e) => _mapToEmergency(e)).toList();
        }
      }
    } catch (_) {}

    final emergencies = await apiClient.getUserEmergencies(userId);
    for (var e in emergencies) {
      await localDataSource.saveEmergency(_emergencyToMap(e));
    }
    return emergencies;
  }

  @override
  Future<void> updateEmergencyStatus(String emergencyId, String status) async {
    await apiClient.updateEmergencyStatus(emergencyId, status);
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['status'] = status;
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<void> assignResponder(String emergencyId, String responderId) async {
    // Legacy method
  }

  @override
  Future<void> acceptEmergency(String emergencyId, String responderId) async {
    await apiClient.acceptEmergency(emergencyId, responderId);
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['responderId'] = responderId;
      cached['status'] = 'RESPONDER_ASSIGNED';
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<void> rejectEmergency(String emergencyId, String responderId) async {
    await apiClient.rejectEmergency(emergencyId, responderId);
    // You could also remove it from local cache, so it doesn't show up
  }

  @override
  Future<void> updateEmergencyLocation(
    String emergencyId,
    double latitude,
    double longitude,
  ) async {
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['latitude'] = latitude;
      cached['longitude'] = longitude;
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<void> generateVoiceAlert(String emergencyId) async {
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['voiceAlertGenerated'] = true;
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Stream<Emergency> watchEmergency(String emergencyId) async* {
    await for (final _ in localDataSource.watchEmergencies()) {
      final cached = await localDataSource.getEmergency(emergencyId);
      if (cached != null) yield _mapToEmergency(cached);
    }
  }

  @override
  Stream<List<Emergency>> watchUserEmergencies(String userId) async* {
    await for (final _ in localDataSource.watchEmergencies()) {
      final cached = await localDataSource.getUserEmergencies(userId);
      yield cached.map((e) => _mapToEmergency(e)).toList();
    }
  }
}
