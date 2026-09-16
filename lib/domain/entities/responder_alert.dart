import '../../core/utils/parsers.dart';
import 'emergency.dart';

/// An emergency request as seen by a responder in their active alerts list.
///
/// Built from `GET responders/emergencies`, which returns the emergency plus
/// this responder's `requests[]` entry (distance, ETA) and the patient.
class ResponderAlert {
  final Emergency emergency;

  /// Server-computed distance from the responder when the request was sent.
  final double? distanceKm;
  final int? estimatedArrivalMinutes;
  final String? patientName;

  /// Status of this responder's request: PENDING, ACCEPTED, ...
  final String requestStatus;

  const ResponderAlert({
    required this.emergency,
    this.distanceKm,
    this.estimatedArrivalMinutes,
    this.patientName,
    this.requestStatus = 'PENDING',
  });

  String get id => emergency.id;

  /// This responder already accepted it — resume instead of accept.
  bool get isAcceptedByMe =>
      requestStatus.toUpperCase() == 'ACCEPTED' ||
      emergency.status.toUpperCase() == 'ASSIGNED';

  factory ResponderAlert.fromServerJson(Map<String, dynamic> json, {String? responderId}) {
    final requests = (json['requests'] ?? json['emergencyRequests']);
    Map<String, dynamic>? myRequest;
    if (requests is List) {
      for (final r in requests.whereType<Map>()) {
        final map = Map<String, dynamic>.from(r);
        if (responderId == null || map['responderId']?.toString() == responderId) {
          myRequest = map;
          break;
        }
      }
    }
    final patient = json['patient'] is Map ? Map<String, dynamic>.from(json['patient'] as Map) : null;

    return ResponderAlert(
      emergency: Emergency.fromJson(json),
      distanceKm: _toDouble(myRequest?['distanceKm'] ?? json['distanceKm']),
      estimatedArrivalMinutes: _toInt(myRequest?['estimatedArrivalMinutes'] ?? json['estimatedArrivalMinutes']),
      patientName: patient?['fullName']?.toString() ?? json['patientName']?.toString(),
      requestStatus: (myRequest?['status'] ?? 'PENDING').toString(),
    );
  }

  /// Fields cached locally alongside the emergency map so the list still
  /// shows distance/patient while offline.
  Map<String, dynamic> toCacheExtras() => {
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (estimatedArrivalMinutes != null) 'estimatedArrivalMinutes': estimatedArrivalMinutes,
        if (patientName != null) 'patientName': patientName,
        'requestStatus': requestStatus,
      };

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    final d = doubleFromJson(v);
    return d.isNaN ? null : d;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return num.tryParse(v.toString())?.round();
  }
}
