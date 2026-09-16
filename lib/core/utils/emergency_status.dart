import 'dart:math' as math;

/// Shared helpers for emergency status strings and emergency types.
///
/// The backend uses `RESOLVED` when a responder resolves an emergency while
/// some app paths historically cached `COMPLETED`; both mean "resolved".
class EmergencyStatus {
  EmergencyStatus._();

  static String normalize(String? status) => (status ?? '').trim().toUpperCase();

  static bool isResolved(String? status) {
    final s = normalize(status);
    return s == 'RESOLVED' || s == 'COMPLETED';
  }

  static bool isCancelled(String? status) => normalize(status) == 'CANCELLED';

  /// Resolved or cancelled — nothing more will happen.
  static bool isTerminal(String? status) => isResolved(status) || isCancelled(status);

  /// A responder has accepted (possibly further along the way).
  static bool isAssigned(String? status) {
    const assigned = {
      'ASSIGNED',
      'ACCEPTED',
      'RESPONDER_ASSIGNED',
      'EN_ROUTE',
      'ARRIVED',
    };
    return assigned.contains(normalize(status));
  }

  /// Friendly label for patients/caregivers.
  static String label(String? status) {
    switch (normalize(status)) {
      case 'ACTIVE':
      case 'PENDING':
      case 'INITIATED':
        return 'Searching for responder';
      case 'ASSIGNED':
      case 'ACCEPTED':
      case 'RESPONDER_ASSIGNED':
        return 'Responder assigned';
      case 'EN_ROUTE':
        return 'On the way';
      case 'ARRIVED':
        return 'Responder arrived';
      case 'RESOLVED':
      case 'COMPLETED':
        return 'Resolved';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return normalize(status).replaceAll('_', ' ');
    }
  }
}

/// Emergency types understood by the backend's specialist routing
/// (`SPECIALIST_MAP`) plus FALL and OTHER.
class EmergencyTypes {
  EmergencyTypes._();

  static const String cardiac = 'CARDIAC';
  static const String stroke = 'STROKE';
  static const String breathing = 'SHORTNESS_OF_BREATH';
  static const String trauma = 'TRAUMA';
  static const String fall = 'FALL';
  static const String seizure = 'SEIZURE';
  static const String diabetic = 'DIABETIC';
  static const String other = 'OTHER';

  static const List<String> all = [
    cardiac,
    stroke,
    breathing,
    trauma,
    fall,
    seizure,
    diabetic,
    other,
  ];

  /// Maps legacy/alias values to the canonical type.
  static String normalize(String? type) {
    final t = (type ?? '').trim().toUpperCase();
    switch (t) {
      case 'BREATHING':
      case 'RESPIRATORY':
        return breathing;
      case 'CHEST_PAIN':
        return cardiac;
      case '':
        return other;
      default:
        return t;
    }
  }

  static String label(String? type) {
    switch (normalize(type)) {
      case cardiac:
        return 'Cardiac';
      case stroke:
        return 'Stroke';
      case breathing:
        return 'Breathing';
      case trauma:
        return 'Injury / Trauma';
      case fall:
        return 'Fall';
      case seizure:
        return 'Seizure';
      case diabetic:
        return 'Diabetic';
      case other:
        return 'Other';
      default:
        return normalize(type).replaceAll('_', ' ');
    }
  }
}

/// Distance/ETA helpers used when the server doesn't send an ETA.
class GeoUtils {
  GeoUtils._();

  /// Great-circle distance in kilometres.
  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// ETA in whole minutes at an average urban speed (default 40 km/h).
  static int etaMinutes(double distanceKm, {double speedKmh = 40}) {
    if (distanceKm <= 0.05) return 0;
    return math.max(1, (distanceKm / speedKmh * 60).round());
  }

  static String formatDistance(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}
