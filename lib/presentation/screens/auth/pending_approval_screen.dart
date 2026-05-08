import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String email;

  const PendingApprovalScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.wp, vertical: 4.hp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 4.hp),

              // Animated pending badge
              _PendingBadge(),

              SizedBox(height: 4.hp),

              // Title
              Text(
                'Application Submitted!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 1.hp),
              Text(
                'Your responder application is under admin review.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 4.hp),

              // Step tracker card
              _StepTrackerCard(isDark: isDark),

              SizedBox(height: 3.hp),

              // Info box about email
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryLight.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mail_outline_rounded,
                        color: AppColors.primaryLight, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check your inbox',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Once your credentials are approved by admin, a one-time verification code will be sent to:',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email.isNotEmpty ? email : 'your registered email',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 4.hp),

              // Primary CTA — Enter OTP
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/verify-email',
                    extra: {'email': email},
                  ),
                  icon: const Icon(Icons.key_rounded, color: Colors.white),
                  label: const Text(
                    'Enter Verification Code',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    padding: EdgeInsets.symmetric(vertical: 2.hp),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              SizedBox(height: 2.hp),

              // Secondary — back to login
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.8.hp),
                    side: BorderSide(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 3.hp),

              // Support hint
              Text(
                'Approval usually takes 1–2 business days.\nNeed help? Contact support@medifind.app',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 2.hp),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated pending badge
// ---------------------------------------------------------------------------
class _PendingBadge extends StatefulWidget {
  @override
  State<_PendingBadge> createState() => _PendingBadgeState();
}

class _PendingBadgeState extends State<_PendingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.amber.shade300,
              Colors.orange.shade600,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.35),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.hourglass_top_rounded,
          color: Colors.white,
          size: 56,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step tracker showing the 3-step responder verification journey
// ---------------------------------------------------------------------------
class _StepTrackerCard extends StatelessWidget {
  final bool isDark;
  const _StepTrackerCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(
        icon: Icons.how_to_reg_rounded,
        label: 'Registration\nSubmitted',
        color: Colors.green,
        done: true,
      ),
      _Step(
        icon: Icons.admin_panel_settings_rounded,
        label: 'Admin\nReview',
        color: Colors.orange,
        done: false,
        active: true,
      ),
      _Step(
        icon: Icons.verified_rounded,
        label: 'Account\nActivated',
        color: AppColors.primaryLight,
        done: false,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final leftDone = steps[i ~/ 2].done;
            return Expanded(
              child: Container(
                height: 2,
                color: leftDone ? Colors.green : Colors.grey.shade300,
              ),
            );
          }
          final step = steps[i ~/ 2];
          return _StepNode(step: step, isDark: isDark);
        }),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String label;
  final Color color;
  final bool done;
  final bool active;
  const _Step({
    required this.icon,
    required this.label,
    required this.color,
    this.done = false,
    this.active = false,
  });
}

class _StepNode extends StatelessWidget {
  final _Step step;
  final bool isDark;
  const _StepNode({required this.step, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: step.done
                ? Colors.green.withOpacity(0.15)
                : step.active
                    ? Colors.orange.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
            border: Border.all(
              color: step.done
                  ? Colors.green
                  : step.active
                      ? Colors.orange
                      : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Icon(
            step.done ? Icons.check_rounded : step.icon,
            color: step.done
                ? Colors.green
                : step.active
                    ? Colors.orange
                    : Colors.grey.shade400,
            size: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                step.active ? FontWeight.bold : FontWeight.w500,
            color: step.done
                ? Colors.green
                : step.active
                    ? Colors.orange
                    : Colors.grey.shade500,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
