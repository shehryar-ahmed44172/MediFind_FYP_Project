import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/datasources/remote/medifind_api_client.dart';
import '../../services/socket/socket_service.dart';
import 'auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Caregiver dashboard data.
//
// Backend contracts (medifind-backend, read-only):
//  * GET /api/emergencies/history?limit=N (PATIENT, CAREGIVER): linked
//    patients' emergencies, newest first: {id, emergencyType, status, latitude,
//    longitude, createdAt, resolvedAt, additionalInfo,
//    patient{id, fullName, phoneNumber},
//    responder{id, fullName, phoneNumber, organization, rating, acceptedAt}|null}.
//  * GET /api/emergencies/:id: 403 unless caller may access it (linked
//    caregiver allowed). Adds `assignedResponderId`, `assignedResponderName`;
//    also `patient` and `emergencyRequests[]`.
//  * GET /api/users/:id -> {userId, fullName, phoneNumber, ...}.
//  * GET /api/tracking/:id/latest -> {latitude, longitude, status, ...}.
//  * Statuses: ACTIVE, ASSIGNED, ARRIVED, RESOLVED, CANCELLED (COMPLETED legacy);
//    socket EMERGENCY_STATUS_CHANGE.newStatus may also be EN_ROUTE, TREATING,
//    TRANSPORTED.
// ─────────────────────────────────────────────────────────────────────────────

/// Terminal = no further updates expected.
bool isTerminalEmergencyStatus(String status) {
  final s = status.toUpperCase();
  return s == 'RESOLVED' || s == 'COMPLETED' || s == 'CANCELLED';
}

/// RESOLVED and COMPLETED are both treated as "resolved".
bool isResolvedEmergencyStatus(String status) {
  final s = status.toUpperCase();
  return s == 'RESOLVED' || s == 'COMPLETED';
}

/// Friendly, caregiver-facing status label.
String caregiverStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
    case 'ACTIVE':
      return 'Searching for responder';
    case 'ACCEPTED':
    case 'ASSIGNED':
    case 'RESPONDER_ASSIGNED':
      return 'Responder assigned';
    case 'EN_ROUTE':
      return 'On the way';
    case 'ARRIVED':
      return 'Arrived';
    case 'TREATING':
      return 'Being treated';
    case 'TRANSPORTED':
      return 'Transporting to hospital';
    case 'RESOLVED':
    case 'COMPLETED':
      return 'Resolved';
    case 'CANCELLED':
      return 'Cancelled';
    default:
      return status.isEmpty ? 'Unknown' : status.replaceAll('_', ' ');
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.round();
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// Great-circle distance in km.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// ETA estimate at ~40 km/h average urban speed, minimum 1 minute.
int estimateEtaMinutes(double distanceKm) {
  final minutes = (distanceKm / 40.0 * 60.0).ceil();
  return math.max(1, minutes);
}

// ─── Emergency details ───────────────────────────────────────────────────────

class CaregiverEmergencyDetails {
  final String id;
  final String status;
  final String emergencyType;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? patientId;
  final String? patientName;
  final String? responderId;
  final String? responderName;
  final String? responderPhone;
  final double? responderLatitude;
  final double? responderLongitude;
  final int? estimatedArrivalMinutes;

  const CaregiverEmergencyDetails({
    required this.id,
    required this.status,
    required this.emergencyType,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.resolvedAt,
    this.patientId,
    this.patientName,
    this.responderId,
    this.responderName,
    this.responderPhone,
    this.responderLatitude,
    this.responderLongitude,
    this.estimatedArrivalMinutes,
  });

  bool get isTerminal => isTerminalEmergencyStatus(status);
  bool get isResolved => isResolvedEmergencyStatus(status);
  bool get hasLocation =>
      latitude != null && longitude != null && !(latitude == 0 && longitude == 0);

  /// Parses both GET emergencies/:id and GET emergencies/history items.
  factory CaregiverEmergencyDetails.fromJson(Map<String, dynamic> json) {
    final patient = _asMap(json['patient']);
    final requests = (json['emergencyRequests'] as List?) ?? const [];

    Map<String, dynamic>? assigned;
    for (final r in requests) {
      final req = _asMap(r);
      if (req == null) continue;
      final s = (req['status'] ?? '').toString().toUpperCase();
      if (s == 'ACCEPTED' || s == 'COMPLETED') {
        assigned = req;
        if (s == 'ACCEPTED') break;
      }
    }
    final requestResponder = _asMap(assigned?['responder']);
    final requestResponderUser = _asMap(requestResponder?['user']);
    // History items expose a flattened `responder` object instead.
    final historyResponder = requests.isEmpty ? _asMap(json['responder']) : null;

    String? nonEmpty(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return CaregiverEmergencyDetails(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'ACTIVE').toString().toUpperCase(),
      emergencyType: (json['emergencyType'] ?? 'MEDICAL').toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      createdAt: _toDate(json['createdAt']),
      resolvedAt: _toDate(json['resolvedAt']),
      patientId: nonEmpty(json['patientId'] ?? patient?['id']),
      patientName: nonEmpty(patient?['fullName']),
      responderId: nonEmpty(json['assignedResponderId'] ??
          historyResponder?['id'] ??
          assigned?['responderId'] ??
          requestResponder?['userId']),
      responderName: nonEmpty(json['assignedResponderName'] ??
          historyResponder?['fullName'] ??
          requestResponderUser?['fullName']),
      responderPhone: nonEmpty(historyResponder?['phoneNumber'] ?? requestResponderUser?['phoneNumber']),
      responderLatitude: _toDouble(requestResponder?['currentLatitude']),
      responderLongitude: _toDouble(requestResponder?['currentLongitude']),
      estimatedArrivalMinutes: _toInt(assigned?['estimatedArrivalMinutes']),
    );
  }
}

/// Thrown when the backend answers 403 for an emergency.
class CaregiverAccessDeniedException implements Exception {
  const CaregiverAccessDeniedException();
  @override
  String toString() => "You don't have access to this emergency.";
}

/// GET emergencies/:id (raw, so responder info from emergencyRequests is kept).
Future<CaregiverEmergencyDetails> fetchCaregiverEmergencyDetails(
    MediFindApiClient client, String emergencyId) async {
  try {
    final response = await client.dio.get('emergencies/$emergencyId');
    final data = _asMap(response.data is Map ? response.data['data'] : null);
    if (data == null) throw Exception('Emergency not found');
    return CaregiverEmergencyDetails.fromJson(data);
  } on DioException catch (e) {
    if (e.response?.statusCode == 403) throw const CaregiverAccessDeniedException();
    rethrow;
  }
}

/// Responder phone via GET users/:id (`phoneNumber`). Null when unavailable.
Future<String?> fetchCaregiverResponderPhone(MediFindApiClient client, String responderId) async {
  try {
    final response = await client.dio.get('users/$responderId');
    final data = _asMap(response.data is Map ? response.data['data'] : null);
    final phone = data?['phoneNumber']?.toString().trim();
    return (phone == null || phone.isEmpty) ? null : phone;
  } catch (e) {
    debugPrint('Caregiver: could not load responder phone: $e');
    return null;
  }
}

/// Latest responder position via GET tracking/:id/latest ({latitude, longitude, status}).
Future<Map<String, dynamic>?> fetchCaregiverLatestTracking(
    MediFindApiClient client, String emergencyId) async {
  try {
    return _asMap(await client.getLatestTracking(emergencyId));
  } catch (e) {
    debugPrint('Caregiver: no latest tracking for $emergencyId: $e');
    return null;
  }
}

// ─── History / active emergencies ────────────────────────────────────────────

/// Bumped by socket events so emergency lists refetch.
final caregiverEmergencyRevisionProvider = StateProvider<int>((ref) => 0);

/// Notification types that should refresh caregiver lists.
const _refreshNotificationTypes = {
  'PATIENT_EMERGENCY',
  'RESPONDER_ASSIGNED',
  'EMERGENCY_RESOLVED',
  'PATIENT_SAFE',
};

/// Keep alive for the caregiver session: listens to the socket and bumps
/// [caregiverEmergencyRevisionProvider] when an emergency starts or changes.
final caregiverEmergencySocketSyncProvider = Provider<void>((ref) {
  final sub = SocketService.instance.messageStream.listen((message) {
    var shouldRefresh = false;
    if (message.event == SocketEvent.notification) {
      final data = _asMap(message.data);
      shouldRefresh = _refreshNotificationTypes.contains((data?['type'] ?? '').toString());
    } else if (message.event == SocketEvent.emergencyStatusChange ||
        message.event == SocketEvent.responderArrived) {
      shouldRefresh = true;
    }
    if (shouldRefresh) {
      ref.read(caregiverEmergencyRevisionProvider.notifier).state++;
    }
  });
  ref.onDispose(sub.cancel);
});

/// GET emergencies/history - linked patients' emergencies, newest first.
final caregiverEmergencyHistoryProvider =
    FutureProvider.autoDispose<List<CaregiverEmergencyDetails>>((ref) async {
  ref.watch(caregiverEmergencyRevisionProvider);
  final client = ref.read(apiClientProvider);
  final response = await client.dio.get('emergencies/history', queryParameters: {'limit': 50});
  final raw = response.data is Map ? response.data['data'] : null;
  if (raw is! List) return const [];
  final list = raw
      .map(_asMap)
      .whereType<Map<String, dynamic>>()
      .map(CaregiverEmergencyDetails.fromJson)
      .where((e) => e.id.isNotEmpty)
      .toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return list;
});

/// Only non-terminal emergencies. Joins their socket rooms for live updates.
final caregiverActiveEmergenciesProvider =
    FutureProvider.autoDispose<List<CaregiverEmergencyDetails>>((ref) async {
  final all = await ref.watch(caregiverEmergencyHistoryProvider.future);
  final active = all.where((e) => !e.isTerminal).toList();
  for (final e in active) {
    SocketService.instance.joinEmergencyRoom(e.id);
  }
  return active;
});

/// Short relative time, e.g. "5 min ago".
String caregiverRelativeTime(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
}
