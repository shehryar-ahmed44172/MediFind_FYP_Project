import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/caregiver_providers.dart';
import '../../../domain/entities/caregiver_connection.dart';
import '../../widgets/design_system/design_system.dart';
import 'caregiver_patient_actions.dart';

/// Pushed from the Patients tab: every caregiver link (all / pending / declined).
class MyPatientsScreen extends ConsumerStatefulWidget {
  const MyPatientsScreen({super.key});

  @override
  ConsumerState<MyPatientsScreen> createState() => _MyPatientsScreenState();
}

class _MyPatientsScreenState extends ConsumerState<MyPatientsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(allCaregiverLinksProvider);

    return MfScaffold(
      title: 'My patients',
      fallbackRoute: '/caregiver',
      headerBottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Pending'),
          Tab(text: 'Declined'),
        ],
      ),
      body: linksAsync.when(
        data: (links) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildLinksList(links, 'ALL'),
              _buildLinksList(links, 'PENDING'),
              _buildLinksList(links, 'REJECTED'),
            ],
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(MfSpace.gutter),
          child: MfSkeleton.list(count: 4, itemHeight: 112),
        ),
        error: (err, _) => MfErrorState(
          title: 'Could not load your patients',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(allCaregiverLinksProvider),
        ),
      ),
      bottomBar: MfPrimaryButton(
        label: 'Link patient',
        icon: Icons.person_add_alt_rounded,
        onPressed: () => context.push('/caregiver/my-patients/link-patient'),
      ),
    );
  }

  Widget _buildLinksList(List<CaregiverConnection> links, String statusFilter) {
    final filteredLinks = statusFilter == 'ALL'
        ? links
        : links.where((l) => l.status == statusFilter).toList();

    Future<void> onRefresh() async {
      try {
        ref.invalidate(allCaregiverLinksProvider);
        await ref.read(allCaregiverLinksProvider.future);
      } catch (_) {}
    }

    if (filteredLinks.isEmpty) {
      final (title, message) = switch (statusFilter) {
        'PENDING' => ('No pending invitations', 'Invitations waiting for a patient to accept appear here.'),
        'REJECTED' => ('No declined invitations', 'Invitations a patient declined appear here.'),
        _ => ('No patients yet', 'Tap "Link patient" to send an invitation.'),
      };
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: MfEmptyState(
                icon: statusFilter == 'ALL' ? Icons.people_outline_rounded : Icons.mail_outline_rounded,
                title: title,
                message: message,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.lg),
        itemCount: filteredLinks.length,
        separatorBuilder: (_, __) => const SizedBox(height: MfSpace.sm),
        itemBuilder: (context, index) => _PatientManageCard(link: filteredLinks[index]),
      ),
    );
  }
}

class _PatientManageCard extends ConsumerWidget {
  final CaregiverConnection link;
  const _PatientManageCard({required this.link});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bool isAccepted = link.status == 'ACCEPTED';
    final bool isRejected = link.status == 'REJECTED';
    final bool isPending = link.status == 'PENDING';
    final bool sosActive = isAccepted && link.hasActiveEmergency == true;
    final name = link.patientName ?? link.patientEmail ?? 'Unknown';

    return MfCard(
      tone: sosActive ? MfTone.danger : null,
      semanticLabel: name,
      onTap: () => openCaregiverPatientProfile(context, link.patientId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MfAvatar(name: name, size: 44),
              const SizedBox(width: MfSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(link.relationship, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: MfSpace.xs),
              caregiverLinkStatusChip(linkStatus: link.status, sosActive: sosActive),
            ],
          ),
          const SizedBox(height: MfSpace.sm),
          if (sosActive && link.activeEmergencyId != null) ...[
            MfPrimaryButton(
              label: 'Track live',
              icon: Icons.my_location_rounded,
              tone: MfTone.danger,
              height: MfSize.minTouch,
              onPressed: () => context.push('/caregiver/tracking/${link.activeEmergencyId}'),
            ),
            const SizedBox(height: MfSpace.xs),
          ],
          Row(
            children: [
              Expanded(
                child: MfSecondaryButton(
                  label: 'Profile',
                  icon: Icons.badge_outlined,
                  semanticLabel: 'View profile of $name',
                  onPressed: () => openCaregiverPatientProfile(context, link.patientId),
                ),
              ),
              if (isAccepted) ...[
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: MfSecondaryButton(
                    label: 'Message',
                    icon: Icons.chat_bubble_outline_rounded,
                    semanticLabel: 'Message $name',
                    onPressed: () => openCaregiverPatientChat(
                      context,
                      ref,
                      patientId: link.patientId,
                      patientName: link.patientName,
                    ),
                  ),
                ),
              ],
              if (isPending || isRejected) ...[
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: MfSecondaryButton(
                    label: 'Resend',
                    icon: Icons.refresh_rounded,
                    semanticLabel: 'Resend invitation to $name',
                    onPressed: () => _showResendConfirm(context, ref),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showResendConfirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Resend invitation?',
      message: 'This will send a new email notification to ${link.patientEmail ?? 'this patient'}.',
      confirmLabel: 'Resend',
      icon: Icons.mail_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;
    // The card is rebuilt away once the list refreshes, so snackbars use the
    // (long-lived) messenger's context instead of this card's context.
    try {
      await ref.read(resendInvitationProvider(link.patientId).future);
      if (messenger.mounted) {
        messenger.showSnackBar(mfSnackBar(messenger.context, 'Invitation resent', tone: MfTone.success));
      }
    } catch (e) {
      debugPrint('MyPatients: resend failed: $e');
      if (messenger.mounted) {
        messenger.showSnackBar(mfSnackBar(
          messenger.context,
          'Could not resend the invitation: ${e.toString().replaceAll('Exception:', '').trim()}',
          tone: MfTone.danger,
        ));
      }
    }
  }
}
