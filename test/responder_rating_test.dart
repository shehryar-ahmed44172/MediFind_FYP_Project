// A responder starts at 5.0 in the database, so an approved-but-never-rated
// responder must not be shown as a perfect five stars.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medifind_mobile_application/presentation/widgets/responder/responder_rating.dart';

void main() {
  group('label', () {
    test('says New while nobody has rated', () {
      expect(ResponderRating.label(5.0, 0), 'New');
      expect(ResponderRating.label(5.0, null), 'New');
      expect(ResponderRating.label(null, 0), 'New');
    });

    test('shows the number once there are ratings', () {
      expect(ResponderRating.label(4.75, 23), '4.8');
      expect(ResponderRating.label(2.0, 1), '2.0');
      expect(ResponderRating.label(5.0, 4), '5.0');
    });
  });

  group('description and caption', () {
    test('spell out the count for screen readers', () {
      expect(ResponderRating.description(4.8, 23), '4.8 out of 5, from 23 ratings');
      expect(ResponderRating.description(3.0, 1), '3.0 out of 5, from 1 rating');
      expect(ResponderRating.description(5.0, 0), 'Not rated yet');
    });

    test('caption reads naturally', () {
      expect(ResponderRating.caption(0), 'No ratings yet');
      expect(ResponderRating.caption(1), 'from 1 rating');
      expect(ResponderRating.caption(12), 'from 12 ratings');
    });
  });

  testWidgets('chip shows New with no ratings and the score with ratings', (tester) async {
    Future<void> show(double? rating, int? total) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponderRatingChip(rating: rating, totalRatings: total),
            ),
          ),
        );

    await show(5.0, 0);
    expect(find.text('New'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);

    await show(4.8, 23);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.text('New'), findsNothing);
  });
}
