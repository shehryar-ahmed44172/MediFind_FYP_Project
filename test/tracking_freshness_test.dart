// A distance is only true while the responder keeps reporting. During a real
// test the responder walked away with their phone in a pocket, updates stopped,
// and the patient's screen kept showing "0 m" from the last known fix.
//
// These tests pin the rules the tracking card follows now.
import 'package:flutter_test/flutter_test.dart';

/// Same rules as _buildResponderCard in emergency_tracking_screen.dart.
String distanceLabel({
  required double km,
  required DateTime? lastFixAt,
  required DateTime now,
  Duration staleAfter = const Duration(seconds: 75),
}) {
  final stale = lastFixAt == null || now.difference(lastFixAt) > staleAfter;
  if (stale) return 'Updating…';
  if (km < 0.03) return 'Arriving now';
  return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}

void main() {
  final now = DateTime(2026, 9, 29, 12, 0, 0);

  group('fresh fix', () {
    test('shows the real distance', () {
      expect(
        distanceLabel(km: 1.4, lastFixAt: now.subtract(const Duration(seconds: 10)), now: now),
        '1.4 km',
      );
      expect(
        distanceLabel(km: 0.42, lastFixAt: now.subtract(const Duration(seconds: 60)), now: now),
        '420 m',
      );
    });

    test('says arriving instead of a misleading zero', () {
      expect(
        distanceLabel(km: 0.004, lastFixAt: now.subtract(const Duration(seconds: 5)), now: now),
        'Arriving now',
      );
    });
  });

  group('stale fix', () {
    test('never shows a distance once updates stop', () {
      // The exact bug: responder is 2 km away, last update was 4 minutes ago.
      expect(
        distanceLabel(km: 2.0, lastFixAt: now.subtract(const Duration(minutes: 4)), now: now),
        'Updating…',
      );
    });

    test('a stale fix at the patient does not read as zero', () {
      expect(
        distanceLabel(km: 0.001, lastFixAt: now.subtract(const Duration(minutes: 6)), now: now),
        'Updating…',
      );
    });

    test('no fix at all is never a distance', () {
      expect(distanceLabel(km: 0.0, lastFixAt: null, now: now), 'Updating…');
    });

    test('the boundary belongs to the fresh side', () {
      expect(
        distanceLabel(km: 3.0, lastFixAt: now.subtract(const Duration(seconds: 75)), now: now),
        '3.0 km',
      );
      expect(
        distanceLabel(km: 3.0, lastFixAt: now.subtract(const Duration(seconds: 76)), now: now),
        'Updating…',
      );
    });
  });
}
