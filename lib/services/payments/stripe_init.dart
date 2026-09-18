import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/constants/app_constants.dart';

/// Stripe's native SDK is only needed at checkout, so it is set up after the
/// first frame instead of delaying app start. [ensure] is safe to call many times.
class StripeInit {
  StripeInit._();

  static Future<void>? _ready;

  static Future<void> ensure() => _ready ??= () async {
        Stripe.publishableKey = AppConstants.stripePublishableKey;
        await Stripe.instance.applySettings();
      }()
          // A failed setup is retried on the next call
          .catchError((Object e) {
        _ready = null;
        throw e;
      });
}
