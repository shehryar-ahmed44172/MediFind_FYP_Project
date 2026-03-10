import 'dart:async';
import '../../domain/entities/emergency.dart';
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
      final cached = await localDataSource.getEmergency(emergencyId);
      if (cached != null) {
        try {
          final fresh = await apiClient.getEmergency(emergencyId);
          await localDataSource.saveEmergency(_emergencyToMap(fresh));
          return fresh;
        } catch (_) {
          return _mapToEmergency(cached);
        }
      }
    } catch (_) {}

    final emergency = await apiClient.getEmergency(emergencyId);
    await localDataSource.saveEmergency(_emergencyToMap(emergency));
    return emergency;
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
    // API logic would go here
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
