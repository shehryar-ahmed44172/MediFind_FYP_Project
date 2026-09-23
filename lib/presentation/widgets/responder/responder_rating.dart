import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

/// How a responder's rating is written everywhere in the app.
///
/// The database starts every responder at 5.0, so a freshly approved
/// responder would otherwise appear as a perfect five stars before anyone has
/// rated them. When no patient has rated yet, the app says "New" instead.
class ResponderRating {
  ResponderRating._();

  static bool hasRatings(int? totalRatings) => (totalRatings ?? 0) > 0;

  /// '4.8' when rated, 'New' when not.
  static String label(double? rating, int? totalRatings) =>
      hasRatings(totalRatings) ? (rating ?? 5.0).toStringAsFixed(1) : 'New';

  /// '4.8 (12 ratings)' / 'Not rated yet' — for screen readers and captions.
  static String description(double? rating, int? totalRatings) {
    final total = totalRatings ?? 0;
    if (total == 0) return 'Not rated yet';
    return '${(rating ?? 5.0).toStringAsFixed(1)} out of 5, from $total '
        '${total == 1 ? 'rating' : 'ratings'}';
  }

  /// 'from 12 ratings' / 'No ratings yet' — small caption under a number.
  static String caption(int? totalRatings) {
    final total = totalRatings ?? 0;
    if (total == 0) return 'No ratings yet';
    return 'from $total ${total == 1 ? 'rating' : 'ratings'}';
  }
}

/// Star + value chip used on responder cards and the tracking screen.
class ResponderRatingChip extends StatelessWidget {
  final double? rating;
  final int? totalRatings;
  final TextStyle? style;

  const ResponderRatingChip({
    super.key,
    required this.rating,
    required this.totalRatings,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final rated = ResponderRating.hasRatings(totalRatings);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: ResponderRating.description(rating, totalRatings),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rated ? Icons.star_rounded : Icons.fiber_new_rounded,
            size: 16,
            color: rated
                ? MfColors.tone(context, MfTone.warning).foreground
                : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text(
            ResponderRating.label(rating, totalRatings),
            style: style ?? text.labelLarge,
          ),
        ],
      ),
    );
  }
}
