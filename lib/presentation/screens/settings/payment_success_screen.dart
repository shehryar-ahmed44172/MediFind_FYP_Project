import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

class PaymentSuccessScreen extends ConsumerWidget {
  final String planName;

  /// Stripe PaymentIntent id (e.g. `pi_...`) of the confirmed payment.
  final String? transactionId;
  const PaymentSuccessScreen({super.key, required this.planName, this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final success = MfColors.tone(context, MfTone.success);

    return MfScaffold(
      title: 'Payment complete',
      showBack: false,
      bottomBar: MfPrimaryButton(
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: () {
          final role = ref.read(currentUserProvider).valueOrNull?.role ?? 'PATIENT';
          final route = role == 'CAREGIVER'
              ? '/caregiver'
              : role == 'RESPONDER'
                  ? '/responder'
                  : '/home';
          context.go(route);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.xl, MfSpace.gutter, MfSpace.xl),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: success.container,
                shape: BoxShape.circle,
                border: Border.all(color: success.border),
              ),
              child: Icon(Icons.check_rounded, color: success.foreground, size: 40, semanticLabel: 'Success'),
            ),
          ),
          const SizedBox(height: MfSpace.lg),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text('Payment successful', style: text.headlineSmall, textAlign: TextAlign.center),
          ),
          const SizedBox(height: MfSpace.xs),
          Text(
            'Your account is now on the $planName plan. Premium features are available right away.',
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MfSpace.xl),

          // Receipt Details
          const MfSectionTitle('Receipt'),
          MfListGroup(
            children: [
              _buildReceiptRow(context, 'Plan', planName),
              _buildReceiptRow(context, 'Transaction ID', transactionId ?? 'Not available', selectable: true),
              _buildReceiptRow(context, 'Date', DateFormat('MMMM d, yyyy').format(DateTime.now())),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Status', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                    const MfStatusChip(
                      label: 'Completed',
                      tone: MfTone.success,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(BuildContext context, String label, String value, {bool selectable = false}) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          selectable
              ? SelectableText(value, style: text.titleSmall)
              : Text(value, style: text.titleSmall),
        ],
      ),
    );
  }
}
