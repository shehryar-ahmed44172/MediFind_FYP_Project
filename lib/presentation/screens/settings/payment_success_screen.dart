import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class PaymentSuccessScreen extends ConsumerWidget {
  final String planName;

  /// Stripe PaymentIntent id (e.g. `pi_...`) of the confirmed payment.
  final String? transactionId;
  const PaymentSuccessScreen({super.key, required this.planName, this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated Success Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF10B981),
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to the $planName plan. Your medical account has been upgraded with premium life-saving features.',
                style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Receipt Details
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('Transaction ID', transactionId ?? 'Not available'),
                    const SizedBox(height: 12),
                    _buildReceiptRow('Date', DateFormat('MMMM d, yyyy').format(DateTime.now())),
                    const SizedBox(height: 12),
                    _buildReceiptRow('Plan', planName),
                    const Divider(height: 32),
                    _buildReceiptRow('Status', 'COMPLETED', isStatus: true),
                  ],
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final role = ref.read(currentUserProvider).valueOrNull?.role ?? 'PATIENT';
                    final route = role == 'CAREGIVER'
                        ? '/caregiver'
                        : role == 'RESPONDER'
                            ? '/responder'
                            : '/home';
                    context.go(route);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Go to Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(width: 16),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isStatus ? const Color(0xFF10B981) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
