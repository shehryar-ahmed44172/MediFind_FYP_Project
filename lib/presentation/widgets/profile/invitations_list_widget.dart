import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_providers.dart';
import '../design_system/design_system.dart';

/// Pending caregiver link requests addressed to the signed-in user
/// (caregiver or patient) with Accept / Decline actions.
///
/// Renders nothing while there are no pending invitations.
class InvitationsListWidget extends ConsumerWidget {
  const InvitationsListWidget({super.key});

  Future<void> _respond(
      BuildContext context, WidgetRef ref, String invitationId, bool accept) async {
    try {
      await ref.read(respondToInvitationProvider({
        'invitationId': invitationId,
        'accept': accept,
      }).future);
      ref.invalidate(allCaregiverLinksProvider);
      ref.invalidate(caregiverLinksProvider);
      if (!context.mounted) return;
      showMfSnackBar(
        context,
        accept ? 'Invitation accepted' : 'Invitation declined',
        tone: accept ? MfTone.success : MfTone.neutral,
      );
    } catch (e) {
      if (!context.mounted) return;
      showMfSnackBar(context, 'Could not respond to invitation: $e', tone: MfTone.danger);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final role = ref.watch(currentUserProvider).valueOrNull?.role;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return invitationsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: MfSpace.gutter, vertical: MfSpace.xs),
        child: MfSkeleton.list(count: 1, itemHeight: 88),
      ),
      error: (error, _) => const SizedBox.shrink(),
      data: (invitations) {
        if (invitations.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: MfSpace.gutter, vertical: MfSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MfSectionTitle('Pending requests (${invitations.length})'),
              for (final inv in invitations)
                Padding(
                  padding: const EdgeInsets.only(bottom: MfSpace.sm),
                  // Uses the widget's own context (stays mounted after the
                  // row disappears) so the result snackbar still shows.
                  child: Builder(builder: (_) {
                    // The "other party" is the patient when a caregiver is signed in.
                    final name = role == 'CAREGIVER'
                        ? (inv.patientName ?? inv.patientEmail ?? 'Patient')
                        : (inv.caregiverName ?? inv.caregiverEmail ?? 'Caregiver');
                    return MfCard(
                      tone: MfTone.warning,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              MfAvatar(name: name, size: 40),
                              const SizedBox(width: MfSpace.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: text.titleSmall),
                                    Text(
                                      'Wants to connect as: ${inv.relationship}',
                                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: MfSpace.sm),
                          Row(
                            children: [
                              Expanded(
                                child: MfSecondaryButton(
                                  label: 'Decline',
                                  icon: Icons.close_rounded,
                                  tone: MfTone.danger,
                                  semanticLabel: 'Decline request from $name',
                                  onPressed: () => _respond(context, ref, inv.id, false),
                                ),
                              ),
                              const SizedBox(width: MfSpace.sm),
                              Expanded(
                                child: MfPrimaryButton(
                                  label: 'Accept',
                                  icon: Icons.check_rounded,
                                  height: MfSize.minTouch,
                                  semanticLabel: 'Accept request from $name',
                                  onPressed: () => _respond(context, ref, inv.id, true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
            ],
          ),
        );
      },
    );
  }
}
