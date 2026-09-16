import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

class SubscriptionPlansScreen extends ConsumerStatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  ConsumerState<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends ConsumerState<SubscriptionPlansScreen> {
  String? _loadingPlan;

  @override
  void initState() {
    super.initState();
    // Always fetch fresh user data so subscription status is up to date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(currentUserProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Subscription plans',
      body: userAsync.when(
        data: (user) {
          final role = (user?.role ?? 'PATIENT').toUpperCase();
          final currentPlan = user?.subscriptionPlan ?? 'FREE';
          final plans = _plansForRole(role);
          final headline = role == 'CAREGIVER'
              ? 'Care more, worry less'
              : role == 'RESPONDER'
                  ? 'Advance your response career'
                  : 'Choose the plan that fits your care';
          final subtitle = role == 'CAREGIVER'
              ? 'Monitor more patients, get faster alerts, and access complete medical histories.'
              : role == 'RESPONDER'
                  ? 'Get priority dispatch, advanced case tools, and full analytics to grow your impact.'
                  : 'Unlock advanced medical tracking, unlimited caregivers, and priority emergency dispatch.';

          return ListView(
            padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
            children: [
              Text(headline, style: text.headlineSmall),
              const SizedBox(height: MfSpace.xs),
              Text(subtitle, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: MfSpace.lg),
              _buildPlanCard(context, 'FREE', 'Standard', '0', currentPlan == 'FREE', plans['FREE']!),
              const SizedBox(height: MfSpace.md),
              _buildPlanCard(context, 'PROFESSIONAL', 'Professional', '499',
                  currentPlan == 'PROFESSIONAL', plans['PROFESSIONAL']!),
              const SizedBox(height: MfSpace.md),
              _buildPlanCard(context, 'EXECUTIVE', 'Executive', '2,499',
                  currentPlan == 'EXECUTIVE', plans['EXECUTIVE']!),
              const SizedBox(height: MfSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: MfSpace.xxs),
                  Flexible(
                    child: Text(
                      'Payments are processed securely by Stripe',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(MfSpace.gutter),
          child: MfSkeleton.list(count: 3, itemHeight: 220),
        ),
        error: (e, _) => MfErrorState(
          title: 'Could not load your plan',
          message: '$e',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    String planId,
    String title,
    String price,
    bool isCurrent,
    List<String> features,
  ) {
    final isLoading = _loadingPlan == planId;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final primary = MfColors.tone(context, MfTone.primary);

    return MfCard(
      tone: isCurrent ? MfTone.primary : null,
      padding: const EdgeInsets.all(MfSpace.md),
      semanticLabel: isCurrent ? '$title plan, current plan' : '$title plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: MfSpace.xxs),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'PKR ', style: text.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
                          TextSpan(text: price, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                          TextSpan(text: ' /month', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                const MfStatusChip(
                  label: 'Current plan',
                  tone: MfTone.primary,
                  icon: Icons.check_circle_outline_rounded,
                ),
            ],
          ),
          const SizedBox(height: MfSpace.sm),
          const Divider(height: 1),
          const SizedBox(height: MfSpace.sm),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: MfSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, color: primary.foreground, size: 20),
                    const SizedBox(width: MfSpace.xs),
                    Expanded(child: Text(f, style: text.bodyMedium)),
                  ],
                ),
              )),
          const SizedBox(height: MfSpace.sm),
          isCurrent
              ? const MfSecondaryButton(
                  label: 'Current plan',
                  icon: Icons.check_rounded,
                  large: true,
                  onPressed: null,
                )
              : MfPrimaryButton(
                  label: 'Select $title',
                  loading: isLoading,
                  onPressed: isLoading ? null : () => _handleUpgrade(planId),
                ),
        ],
      ),
    );
  }

  Map<String, List<String>> _plansForRole(String role) {
    if (role == 'CAREGIVER') {
      return {
        'FREE': ['Monitor 1 Patient', 'Basic Emergency Alerts', 'Location Access'],
        'PROFESSIONAL': [
          'Monitor Up to 5 Patients',
          'Priority Alerts',
          'Full Medical History View',
          'Live Patient Tracking',
        ],
        'EXECUTIVE': [
          'Unlimited Patients',
          'Instant Critical Alerts',
          'Full Health Records',
          'Multi-patient Dashboard',
          'VIP Support Access',
        ],
      };
    }
    if (role == 'RESPONDER') {
      return {
        'FREE': ['Standard Emergency Dispatch', 'Basic Profile & Credentials', '30-day Case History'],
        'PROFESSIONAL': [
          'Priority Dispatch Queue',
          'Advanced Case Management',
          '1-year Case History',
          'Enhanced Profile Visibility',
        ],
        'EXECUTIVE': [
          'Elite Priority Dispatch',
          'Full Analytics Dashboard',
          'Unlimited Case History',
          'Custom Specialization Badge',
          'VIP Support Access',
        ],
      };
    }
    // PATIENT (default)
    return {
      'FREE': ['Standard SOS Response', 'Basic Medical Profile', '1 Caregiver Connection'],
      'PROFESSIONAL': [
        'Priority SOS Dispatch',
        'Enhanced Medical History',
        'Up to 5 Caregivers',
        'Live Tracking for Family',
      ],
      'EXECUTIVE': [
        'Instant Elite Dispatch',
        'Full Digital Health Record',
        'Unlimited Caregivers',
        'Unlimited Report Storage',
        'VIP Support Access',
      ],
    };
  }

  Future<void> _handleUpgrade(String planId) async {
    context.push('/checkout/$planId');
  }
}
