import 'dart:async';
import '../../domain/entities/emergency.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/responder_alert.dart';
import '../../core/utils/emergency_status.dart';
import '../../core/utils/parsers.dart';

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
  Future<void> cancelAssignment(String emergencyId) async {
    await apiClient.cancelResponderAssignment(emergencyId);
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['responderId'] = null;
      cached['status'] = 'ACTIVE';
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<void> resolveEmergency(String emergencyId) async {
    await apiClient.resolveEmergency(emergencyId);
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['status'] = 'RESOLVED';
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
    // Determine if we should fetch all or just responder-specific
    // This is handled by the provider calling the right method, 
    // but for backward compatibility we keep this as "All" for now or update it.
    final emergencies = await apiClient.getActiveEmergencies();
    for (var e in emergencies) {
      await localDataSource.saveEmergency(_emergencyToMap(e));
    }
    return emergencies;
  }

  @override
  Future<List<Emergency>> getResponderActiveRequests() async {
    final emergencies = await apiClient.getResponderActiveRequests();
    // Save to local DB to ensure they are available for watchActiveEmergencies
    for (var e in emergencies) {
      await localDataSource.saveEmergency(_emergencyToMap(e));
    }
    return emergencies;
  }

  @override
  Stream<List<Emergency>> watchActiveEmergencies() async* {
    bool isOpenRequest(Emergency e) =>
        !EmergencyStatus.isTerminal(e.status) &&
        e.status != 'REJECTED' &&
        !EmergencyStatus.isAssigned(e.status);

    // 1. Yield initial state immediately from cache
    final initial = await localDataSource.getAllEmergencies();
    yield initial.map(_mapToEmergency).where(isOpenRequest).toList();

    // 2. Then listen for updates
    await for (final _ in localDataSource.watchEmergencies()) {
      final all = await localDataSource.getAllEmergencies();
      yield all.map(_mapToEmergency).where(isOpenRequest).toList();
    }
  }

  @override
  Future<List<ResponderAlert>> syncResponderAlerts(String? responderId) async {
    try {
      final raw = await apiClient.getResponderActiveRequestsRaw();
      final alerts = raw
          .map((json) => ResponderAlert.fromServerJson(json, responderId: responderId))
          .where((a) => a.id.isNotEmpty && !EmergencyStatus.isTerminal(a.emergency.status))
          .toList();

      final liveIds = alerts.map((a) => a.id).toSet();

      // Remove cached requests the server no longer considers live
      // (cancelled, taken by another responder, expired).
      for (final cached in await localDataSource.getAllEmergencies()) {
        final id = cached['id']?.toString();
        if (id == null || liveIds.contains(id)) continue;
        if (cached['isResponderAlert'] == true || !EmergencyStatus.isTerminal(cached['status']?.toString())) {
          await localDataSource.deleteEmergency(id);
        }
      }

      for (final alert in alerts) {
        await localDataSource.saveEmergency({
          ..._emergencyToMap(alert.emergency),
          ...alert.toCacheExtras(),
          'isResponderAlert': true,
        });
      }
      return alerts;
    } catch (e) {
      // Offline / server error → show what we have cached, clearly partial.
      final cached = await localDataSource.getAllEmergencies();
      final fallback = cached
          .where((m) => m['isResponderAlert'] == true && !EmergencyStatus.isTerminal(m['status']?.toString()))
          .map((m) => ResponderAlert(
                emergency: _mapToEmergency(m),
                distanceKm: (m['distanceKm'] as num?)?.toDouble(),
                estimatedArrivalMinutes: (m['estimatedArrivalMinutes'] as num?)?.toInt(),
                patientName: m['patientName']?.toString(),
                requestStatus: m['requestStatus']?.toString() ?? 'PENDING',
              ))
          .toList();
      if (fallback.isEmpty) rethrow;
      return fallback;
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
        'priority': e.priority,
        'patientType': e.patientType,
        'voiceSummary': e.voiceSummary,
        'createdAt': e.createdAt?.toIso8601String(),
        'updatedAt': e.updatedAt?.toIso8601String(),
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
      latitude: doubleFromJson(map['latitude']),
      longitude: doubleFromJson(map['longitude']),
      additionalInfo: map['additionalInfo'] as String?,
      priority: map['priority'] as String? ?? 'NORMAL',
      patientType: map['patientType'] as String? ?? 'NORMAL',
      voiceSummary: map['voiceSummary'] as String?,
      voiceAlertGenerated: map['voiceAlertGenerated'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<CreateEmergencyResult> createEmergency(
    String emergencyType,
    double latitude,
    double longitude,
    String? additionalInfo,
  ) async {
    final result = await apiClient.createEmergency(
      emergencyType,
      latitude,
      longitude,
      additionalInfo,
    );
    await localDataSource.saveEmergency(_emergencyToMap(result.emergency));
    return result;
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
  Future<void> updateEmergencyStatus(String emergencyId, String status, {double? latitude, double? longitude}) async {
    await apiClient.updateEmergencyStatus(emergencyId, status, latitude: latitude, longitude: longitude);
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
      cached['status'] = 'ASSIGNED';
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<void> rejectEmergency(String emergencyId, String responderId) async {
    await apiClient.rejectEmergency(emergencyId, responderId);
    final cached = await localDataSource.getEmergency(emergencyId);
    if (cached != null) {
      cached['status'] = 'REJECTED';
      await localDataSource.saveEmergency(cached);
    }
  }

  @override
  Future<List<dynamic>> getResponderHistory() async {
    return await apiClient.getResponderHistory();
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
    // Yield initial state
    final cachedInitial = await localDataSource.getEmergency(emergencyId);
    if (cachedInitial != null) yield _mapToEmergency(cachedInitial);

    await for (final _ in localDataSource.watchEmergencies()) {
      final cached = await localDataSource.getEmergency(emergencyId);
      if (cached != null) yield _mapToEmergency(cached);
    }
  }

  @override
  Stream<List<Emergency>> watchUserEmergencies(String userId) async* {
    // Yield initial state
    final cachedInitial = await localDataSource.getUserEmergencies(userId);
    yield cachedInitial.map((e) => _mapToEmergency(e)).toList();

    await for (final _ in localDataSource.watchEmergencies()) {
      final cached = await localDataSource.getUserEmergencies(userId);
      yield cached.map((e) => _mapToEmergency(e)).toList();
    }
  }
}
