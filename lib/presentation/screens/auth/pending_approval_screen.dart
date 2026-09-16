import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/auth_common.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String email;

  const PendingApprovalScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: MfSpace.gutter, vertical: MfSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthStepIntro(
                    icon: Icons.hourglass_top_rounded,
                    tone: MfTone.warning,
                    title: 'Awaiting admin approval',
                    message: 'Your responder application has been submitted and is under admin review.',
                  ),
                  const SizedBox(height: MfSpace.lg),

                  // ── Verification journey ─────────────────────────────────
                  const MfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MfSectionTitle('Application status'),
                        SizedBox(height: MfSpace.xs),
                        MfStatusTimeline(
                          axis: Axis.vertical,
                          currentIndex: 1,
                          steps: [
                            MfTimelineStep(
                              'Registration submitted',
                              Icons.how_to_reg_outlined,
                              caption: 'Your details and documents were received',
                            ),
                            MfTimelineStep(
                              'Admin review',
                              Icons.admin_panel_settings_outlined,
                              caption: 'Usually takes 1 to 2 business days',
                            ),
                            MfTimelineStep(
                              'Account activated',
                              Icons.verified_outlined,
                              caption: 'Verify with the code sent by email',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MfSpace.md),

                  MfInfoBanner(
                    icon: Icons.mail_outline_rounded,
                    tone: MfTone.primary,
                    title: 'Check your inbox',
                    message: 'Once your credentials are approved, a one-time verification code will be sent to '
                        '${email.isNotEmpty ? email : 'your registered email'}.',
                  ),
                  const SizedBox(height: MfSpace.lg),

                  MfPrimaryButton(
                    label: 'Enter verification code',
                    icon: Icons.pin_outlined,
                    onPressed: () => context.push('/verify-email', extra: {'email': email}),
                  ),
                  const SizedBox(height: MfSpace.sm),
                  MfSecondaryButton(
                    label: 'Back to log in',
                    icon: Icons.login_rounded,
                    onPressed: () => context.go('/login'),
                  ),
                  const SizedBox(height: MfSpace.lg),
                  Text(
                    'Need help? Contact support@medifind.app',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
