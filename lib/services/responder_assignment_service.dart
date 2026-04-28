/// Responder Assignment Service
/// Handles responder discovery, notification, and escalation logic
library;

import 'dart:math' as math show sin, cos, sqrt, atan2, pi, max;

/// Responder matching result
class ResponderMatchResult {
  final String responderId;
  final String responderName;
  final double distanceKm;
  final int estimatedArrivalMinutes;
  final double latitude;
  final double longitude;

  ResponderMatchResult({
    required this.responderId,
    required this.responderName,
    required this.distanceKm,
    required this.estimatedArrivalMinutes,
    required this.latitude,
    required this.longitude,
  });

  factory ResponderMatchResult.fromJson(Map<String, dynamic> json) {
    return ResponderMatchResult(
      responderId: json['responderId'] ?? '',
      responderName: json['responderName'] ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedArrivalMinutes: json['estimatedArrivalMinutes'] ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Escalation level in responder assignment
enum EscalationLevel {
  primary,   // First 5 responders
  secondary, // Next 10 responders
  tertiary,  // Next 20 responders
}

class ResponderAssignmentService {
  /// Calculate distance between two geo coordinates
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371;

    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadiusKm * c;

    return distance;
  }

  /// Estimate arrival time based on distance
  /// Assumes average responder speed: 40 km/h in urban, 60 km/h in highway
  static int estimateArrivalMinutes(double distanceKm) {
    // Average speed: 50 km/h = 0.833 km/minute
    final estimatedMinutes = (distanceKm / 0.833).ceil();
    return math.max(1, estimatedMinutes); // Minimum 1 minute
  }

  /// Get escalation batch size by level
  /// PRIMARY: First 5 responders
  /// SECONDARY: Next 10 responders
  /// TERTIARY: Next 20 responders
  static int getBatchSize(EscalationLevel level) {
    switch (level) {
      case EscalationLevel.primary:
        return 6;
      case EscalationLevel.secondary:
        return 10;
      case EscalationLevel.tertiary:
        return 20;
    }
  }

  /// Get timeout duration before escalation
  /// PRIMARY: 5 minutes to accept
  /// SECONDARY: 5 minutes to accept
  /// TERTIARY: 2 minutes to accept
  static Duration getEscalationTimeout(EscalationLevel level) {
    switch (level) {
      case EscalationLevel.primary:
        return const Duration(minutes: 5);
      case EscalationLevel.secondary:
        return const Duration(minutes: 5);
      case EscalationLevel.tertiary:
        return const Duration(minutes: 2);
    }
  }

  /// Calculate max escalation attempts
  /// After 3 escalations (60+ responders notified), emergency expires
  static int getMaxEscalationAttempts() {
    return 3; // PRIMARY + SECONDARY + TERTIARY
  }

  /// Check if responder is within service radius
  /// Standard service radius: 10 km
  static bool isWithinServiceRadius(double distanceKm) {
    const maxServiceRadius = 10.0;
    return distanceKm <= maxServiceRadius;
  }

  /// Sort responders by distance and rating
  /// Algorithm: Sort by distance (primary), then by rating (secondary)
  static List<ResponderMatchResult> sortRespondersByPriority(
    List<ResponderMatchResult> responders,
  ) {
    final sorted = List<ResponderMatchResult>.from(responders);
    sorted.sort((a, b) {
      // First priority: nearest responder
      final distanceCompare = a.distanceKm.compareTo(b.distanceKm);
      if (distanceCompare != 0) return distanceCompare;

      // If same distance, higher rated responder
      // (This would need additional data from backend)
      return 0;
    });

    return sorted;
  }

  /// Calculate ETA range for batch
  /// Returns estimated arrival time for first responder in batch
  static int calculateBatchETAMinutes(List<ResponderMatchResult> batch) {
    if (batch.isEmpty) return 0;

    // Get fastest responder's ETA
    final minEta = batch
        .map((r) => r.estimatedArrivalMinutes)
        .reduce((a, b) => a < b ? a : b);

    return minEta;
  }

  /// Convert radians helper
  static double _toRad(double degree) {
    return degree * (math.pi / 180);
  }
}

