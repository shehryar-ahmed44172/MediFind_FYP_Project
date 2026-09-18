import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import '../../../data/datasources/remote/medifind_api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String planId;
  const CheckoutScreen({super.key, required this.planId});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedMethod = 'CARD';
  bool _isProcessing = false;

  /// The payment is prepared (PaymentIntent + payment sheet) as soon as the
  /// screen opens, so tapping Pay shows Stripe's sheet without waiting.
  Future<PaymentIntentInfo>? _prepared;

  @override
  void initState() {
    super.initState();
    if (widget.planId == 'PROFESSIONAL' || widget.planId == 'EXECUTIVE') _startPreparing();
  }

  void _startPreparing() {
    _prepared = _preparePayment();
    // An early failure is retried when Pay is tapped
    _prepared!.ignore();
  }

  Future<PaymentIntentInfo> _preparePayment() async {
    final intent = await ref.read(apiClientProvider).createPaymentIntent(widget.planId);
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: intent.clientSecret,
        merchantDisplayName: 'MediFind',
        style: ThemeMode.light,
        // FlowController mode: Stripe loads the sheet's data here, while the user is
        // still reading the checkout screen, instead of after Pay is tapped.
        customFlow: true,
      ),
    );
    return intent;
  }

  Map<String, dynamic> _getPlanDetails() {
    switch (widget.planId) {
      case 'PROFESSIONAL':
        return {'name': 'Professional', 'price': 499.0};
      case 'EXECUTIVE':
        return {'name': 'Executive', 'price': 2499.0};
      default:
        return {'name': 'Free', 'price': 0.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _getPlanDetails();
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final priceLabel = 'PKR ${plan['price'].toStringAsFixed(0)}';

    return MfScaffold(
      title: 'Checkout',
      // Sticky Pay button
      bottomBar: MfPrimaryButton(
        label: _isProcessing ? 'Processing payment' : 'Pay $priceLabel',
        icon: Icons.lock_outline_rounded,
        loading: _isProcessing,
        onPressed: _isProcessing ? null : _handlePayment,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
        children: [
          // Order Summary Card
          const MfSectionTitle('Order summary'),
          MfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Selected plan', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                    MfStatusChip(label: plan['name'], tone: MfTone.primary),
                  ],
                ),
                const SizedBox(height: MfSpace.sm),
                Row(
                  children: [
                    Expanded(child: Text('Monthly fee', style: text.bodyLarge)),
                    Text(priceLabel, style: text.titleSmall),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: MfSpace.sm),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Total', style: text.titleMedium)),
                    Text(priceLabel, style: text.titleLarge?.copyWith(color: MfColors.tone(context, MfTone.primary).foreground)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: MfSpace.lg),
          const MfSectionTitle('Payment method'),

          MfListGroup(
            children: [
              _buildPaymentTile('CARD', 'Credit / debit card (Stripe)', Icons.credit_card_rounded),
              // Wallet gateways are not integrated yet — shown but disabled so
              // no plan can be upgraded without a verified payment.
              _buildPaymentTile('JAZZCASH', 'JazzCash wallet', Icons.account_balance_wallet_outlined, enabled: false),
              _buildPaymentTile('EASYPAISA', 'EasyPaisa wallet', Icons.payments_outlined, enabled: false),
            ],
          ),

          const SizedBox(height: MfSpace.lg),

          // Stripe sandbox notice for CARD
          if (_selectedMethod == 'CARD') ...[
            const MfInfoBanner(
              icon: Icons.info_outline_rounded,
              title: 'Sandbox mode',
              message: 'Use test card 4242 4242 4242 4242, any future date, any CVC.',
            ),
            const SizedBox(height: MfSpace.sm),
          ],

          // Security note
          MfInfoBanner(
            icon: Icons.verified_user_outlined,
            tone: MfTone.neutral,
            title: 'Secure payment',
            message: 'Card details are entered in Stripe\'s secure payment sheet and protected by 256-bit SSL encryption. '
                'MediFind never stores your card number.',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(String id, String title, IconData icon, {bool enabled = true}) {
    final isSelected = enabled && _selectedMethod == id;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final primary = MfColors.tone(context, MfTone.primary);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: isSelected,
      label: enabled ? title : '$title, coming soon',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? () => setState(() => _selectedMethod = id) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.xs),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: enabled ? primary.container : cs.surfaceContainer,
                    borderRadius: MfRadius.smAll,
                  ),
                  child: Icon(icon, color: enabled ? primary.foreground : cs.onSurfaceVariant, size: 22),
                ),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Text(
                    title,
                    style: text.titleSmall?.copyWith(color: enabled ? null : cs.onSurfaceVariant),
                  ),
                ),
                if (!enabled)
                  const MfStatusChip(label: 'Coming soon', tone: MfTone.neutral)
                else
                  Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? primary.foreground : cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);
    final plan = _getPlanDetails();

    try {
      // Only card payments (Stripe) are supported; wallet options are disabled.
      await _handleStripePayment(plan);
    } on StripeException catch (e) {
      if (mounted && _prepared == null) _startPreparing();
      if (mounted) {
        final cancelled = e.error.code == FailureCode.Canceled;
        final reason = e.error.localizedMessage ?? e.error.message ?? 'Unknown error';
        showMfSnackBar(
          context,
          cancelled
              ? 'Payment cancelled. You have not been charged.'
              : 'Payment failed: $reason',
          tone: cancelled ? MfTone.neutral : MfTone.danger,
        );
      }
    } catch (e) {
      if (mounted) {
        showMfSnackBar(context, 'Payment failed: $e', tone: MfTone.danger);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Real Stripe payment sheet flow (CARD only).
  Future<void> _handleStripePayment(Map<String, dynamic> plan) async {
    // 1–2. PaymentIntent + sheet, prepared when the screen opened (retried if that failed)
    PaymentIntentInfo intent;
    try {
      intent = await (_prepared ?? _preparePayment());
    } catch (_) {
      _prepared = _preparePayment();
      intent = await _prepared!;
    }
    // A PaymentIntent is used once; prepare a fresh one if this attempt is cancelled
    _prepared = null;

    // 3. Present the (already loaded) sheet for card entry — throws StripeException
    //    if the user cancels — then confirm the payment with Stripe.
    final option = await Stripe.instance.presentPaymentSheet();
    if (option == null) {
      throw const StripeException(error: LocalizedErrorMessage(code: FailureCode.Canceled));
    }
    await Stripe.instance.confirmPaymentSheetPayment();

    // 4. Payment confirmed by Stripe — ask the server to apply the upgrade.
    //    The server verifies the PaymentIntent succeeded for this user + plan.
    if (!mounted) return;
    await ref.read(upgradeSubscriptionProvider(UpgradeSubscriptionParams(
      plan: widget.planId,
      paymentIntentId: intent.paymentIntentId,
    )).future);
    ref.invalidate(currentUserProvider);
    if (!mounted) return;
    context.pushReplacement('/payment-success', extra: {
      'planName': plan['name'],
      'transactionId': intent.paymentIntentId,
    });
  }
}
