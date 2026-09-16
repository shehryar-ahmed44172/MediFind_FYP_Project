import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String planId;
  const CheckoutScreen({super.key, required this.planId});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedMethod = 'CARD';
  bool _isProcessing = false;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Selected Plan', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              plan['name'],
                              style: TextStyle(color: AppColors.primaryTeal, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monthly Fee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          Text('PKR ${plan['price'].toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(
                            'PKR ${plan['price'].toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryNavy),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Text('Select Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                _buildPaymentTile('CARD', 'Credit / Debit Card (Stripe)', Icons.credit_card_rounded, const Color(0xFF6366F1)),
                // Wallet gateways are not integrated yet — shown but disabled so
                // no plan can be upgraded without a verified payment.
                _buildPaymentTile('JAZZCASH', 'JazzCash Wallet', Icons.account_balance_wallet_rounded, const Color(0xFFF59E0B), enabled: false),
                _buildPaymentTile('EASYPAISA', 'EasyPaisa Wallet', Icons.payments_rounded, const Color(0xFF10B981), enabled: false),

                const SizedBox(height: 40),

                // Stripe sandbox notice for CARD
                if (_selectedMethod == 'CARD') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF6366F1)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Sandbox mode — use test card 4242 4242 4242 4242, any future date, any CVC.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF4338CA), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Security note
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text('Secure 256-bit SSL Encryption', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Sticky Pay button
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : Text('Pay PKR ${plan['price'].toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(String id, String title, IconData icon, Color color, {bool enabled = true}) {
    final isSelected = enabled && _selectedMethod == id;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: isSelected,
      label: enabled ? title : '$title, coming soon',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: enabled ? () => setState(() => _selectedMethod = id) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    if (!enabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Coming soon',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                        ),
                      )
                    else if (isSelected)
                      Icon(Icons.check_circle_rounded, color: color),
                  ],
                ),
              ),
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
      if (mounted) {
        final cancelled = e.error.code == FailureCode.Canceled;
        final reason = e.error.localizedMessage ?? e.error.message ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cancelled
                ? 'Payment cancelled. You have not been charged.'
                : 'Payment failed: $reason'),
            backgroundColor: cancelled ? Colors.grey.shade800 : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Real Stripe payment sheet flow (CARD only).
  Future<void> _handleStripePayment(Map<String, dynamic> plan) async {
    // 1. Create PaymentIntent on the backend
    final apiClient = ref.read(apiClientProvider);
    final intent = await apiClient.createPaymentIntent(widget.planId);

    // 2. Initialise the Payment Sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: intent.clientSecret,
        merchantDisplayName: 'MediFind',
        style: ThemeMode.light,
      ),
    );

    // 3. Present the Payment Sheet — throws StripeException if user cancels
    await Stripe.instance.presentPaymentSheet();

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
