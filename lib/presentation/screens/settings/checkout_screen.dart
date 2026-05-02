import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return {'name': 'Professional', 'price': 1500.0};
      case 'EXECUTIVE':
        return {'name': 'Executive', 'price': 4500.0};
      default:
        return {'name': 'Free', 'price': 0.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _getPlanDetails();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                
                _buildPaymentTile('CARD', 'Credit / Debit Card', Icons.credit_card_rounded, const Color(0xFF6366F1)),
                _buildPaymentTile('JAZZCASH', 'JazzCash Wallet', Icons.account_balance_wallet_rounded, const Color(0xFFF59E0B)),
                _buildPaymentTile('EASYPAISA', 'EasyPaisa Wallet', Icons.payments_rounded, const Color(0xFF10B981)),
                
                const SizedBox(height: 40),
                
                // Security Note
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
                      const SizedBox(height: 8),
                      Text('Transaction ID: MFD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}', 
                        style: TextStyle(color: Colors.grey.shade300, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          // Sticky Bottom Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
                ],
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

  Widget _buildPaymentTile(String id, String title, IconData icon, Color color) {
    final isSelected = _selectedMethod == id;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 2))
          ],
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
            if (isSelected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);
    final plan = _getPlanDetails();
    
    try {
      // 1. Process Mock Payment
      final success = await ref.read(processPaymentProvider(
        PaymentParams(amount: plan['price'], method: _selectedMethod)
      ).future);
      
      if (success && mounted) {
        // 2. Perform Backend Upgrade
        await ref.read(upgradeSubscriptionProvider(widget.planId).future);
        
        if (mounted) {
          context.pushReplacement('/payment-success', extra: plan['name']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
