import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primaryNavy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              centerTitle: true,
              title: const Text(
                'MediFind Premium',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0C637E),
                      Color(0xFF2496A7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 100,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: userAsync.when(
              data: (user) {
                final role = (user?.role ?? 'PATIENT').toUpperCase();
                final headline = role == 'CAREGIVER'
                    ? 'Care More, Worry Less'
                    : role == 'RESPONDER'
                        ? 'Advance Your Response Career'
                        : 'Elevate Your Experience';
                final subtitle = role == 'CAREGIVER'
                    ? 'Monitor more patients, get faster alerts, and access complete medical histories.'
                    : role == 'RESPONDER'
                        ? 'Get priority dispatch, advanced case tools, and full analytics to grow your impact.'
                        : 'Unlock advanced medical tracking, unlimited caregivers, and priority emergency dispatch.';
                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                  child: Column(
                    children: [
                      Text(
                        headline,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryNavy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(height: 120),
              error: (_, __) => const SizedBox(height: 120),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: userAsync.when(
              data: (user) {
                final currentPlan = user?.subscriptionPlan ?? 'FREE';
                final role = (user?.role ?? 'PATIENT').toUpperCase();
                final plans = _plansForRole(role);
                return SliverList(
                  delegate: SliverChildListDelegate([
                    _buildPlanCard(context, 'FREE', 'Standard', '0', currentPlan == 'FREE',
                        plans['FREE']!, const Color(0xFF94A3B8)),
                    const SizedBox(height: 20),
                    _buildPlanCard(context, 'PROFESSIONAL', 'Professional', '499',
                        currentPlan == 'PROFESSIONAL', plans['PROFESSIONAL']!, const Color(0xFF2496A7)),
                    const SizedBox(height: 20),
                    _buildPlanCard(context, 'EXECUTIVE', 'Executive', '2,499',
                        currentPlan == 'EXECUTIVE', plans['EXECUTIVE']!, const Color(0xFF0C637E)),
                    const SizedBox(height: 40),
                  ]),
                );
              },
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ),
        ],
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
    Color accentColor,
  ) {
    final isLoading = _loadingPlan == planId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isCurrent ? accentColor : Colors.grey.shade100,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'PKR ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                        Text(
                          price,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const Text(
                          '/mo',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'ACTIVE',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded, color: accentColor, size: 14),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 14, 
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isCurrent || isLoading ? null : () => _handleUpgrade(planId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade100,
                      disabledForegroundColor: Colors.grey.shade400,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading 
                        ? const SizedBox(
                            height: 24, 
                            width: 24, 
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)
                          )
                        : Text(
                            isCurrent ? 'Current Plan' : 'Select $title',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
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
