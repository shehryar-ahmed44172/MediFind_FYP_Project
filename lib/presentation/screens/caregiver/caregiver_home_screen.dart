import 'package:flutter/material.dart';
import '../../../core/utils/emergency_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_providers.dart';
import '../../../domain/entities/caregiver_connection.dart';
import '../../providers/caregiver_dashboard_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/profile/invitations_list_widget.dart';
import 'caregiver_patient_actions.dart';

/// Caregiver "Patients" tab root. The shell draws the header.
class CaregiverHomeScreen extends ConsumerStatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  ConsumerState<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends ConsumerState<CaregiverHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final asyncPatients = ref.watch(getLinkedPatientsProvider);
    // Refreshes emergency data on socket events while the caregiver is signed in.
    ref.watch(caregiverEmergencySocketSyncProvider);
    final activeEmergencies =
        ref.watch(caregiverActiveEmergenciesProvider).valueOrNull ?? const <CaregiverEmergencyDetails>[];

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(caregiverEmergencyHistoryProvider);
          ref.invalidate(pendingInvitationsProvider);
          try {
            ref.invalidate(getLinkedPatientsProvider);
            await ref.read(getLinkedPatientsProvider.future);
          } catch (_) {}
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Greeting
            SliverToBoxAdapter(child: _buildGreeting(context)),

            // 2. Live SOS cards (updated on PATIENT_EMERGENCY / RESPONDER_ASSIGNED)
            if (activeEmergencies.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.xs, MfSpace.gutter, 0),
                sliver: SliverList.separated(
                  itemCount: activeEmergencies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: MfSpace.sm),
                  itemBuilder: (context, i) => _ActiveSosCard(emergency: activeEmergencies[i]),
                ),
              ),

            // 3. Pending link requests (accept / decline)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: MfSpace.xs),
                child: InvitationsListWidget(),
              ),
            ),

            // 4. Summary + linked patients
            ...asyncPatients.when(
              skipLoadingOnRefresh: true,
              data: (patients) {
                if (patients.isEmpty) {
                  return [
                    SliverToBoxAdapter(
                      child: MfEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No patients linked yet',
                        message: 'Link a patient to start monitoring their safety status in real time.',
                        actionLabel: 'Link patient',
                        actionIcon: Icons.person_add_alt_rounded,
                        onAction: () => context.push('/caregiver/my-patients/link-patient'),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildQuickLinks(context)),
                  ];
                }
                return [
                  SliverToBoxAdapter(child: _buildStatsRow(patients, activeEmergencies)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.lg, MfSpace.xs, 0),
                      child: MfSectionTitle(
                        'Linked patients',
                        subtitle: '${patients.length} linked',
                        actionLabel: 'See all',
                        onAction: () => context.push('/caregiver/my-patients'),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: MfSpace.gutter),
                    sliver: SliverList.separated(
                      itemCount: patients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: MfSpace.sm),
                      itemBuilder: (context, index) {
                        final patient = patients[index];
                        final active = activeEmergencies
                            .where((e) => e.patientId == patient.patientId)
                            .firstOrNull;
                        return RepaintBoundary(
                          child: _PatientCard(patient: patient, activeEmergency: active),
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, 0),
                      child: MfSecondaryButton(
                        label: 'Link patient',
                        icon: Icons.person_add_alt_rounded,
                        onPressed: () => context.push('/caregiver/my-patients/link-patient'),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildQuickLinks(context)),
                ];
              },
              loading: () => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, 0),
                  sliver: SliverToBoxAdapter(child: MfSkeleton.list(count: 3, itemHeight: 120)),
                ),
              ],
              error: (err, _) => [
                SliverToBoxAdapter(
                  child: MfErrorState(
                    title: 'Could not load your patients',
                    message: 'Check your connection and try again.',
                    onRetry: () => ref.invalidate(getLinkedPatientsProvider),
                  ),
                ),
                SliverToBoxAdapter(child: _buildQuickLinks(context)),
              ],
            ),

            const SliverToBoxAdapter(child: SizedBox(height: MfSpace.xl)),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ref.watch(currentUserProvider).when(
          data: (user) => Padding(
            padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user?.fullName.split(' ')[0] ?? 'Caregiver'}',
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: MfSpace.xxs),
                Text(
                  'Caregiver dashboard',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  /// Former quick-action grid (My patients, Live map, Messages, History).
  Widget _buildQuickLinks(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.lg, MfSpace.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MfSectionTitle('Quick actions'),
          MfQuickActionGrid(
            children: [
              MfIconTile(
                vertical: true,
                icon: Icons.people_outline_rounded,
                label: 'See all patients',
                subtitle: 'Links, pending invitations and declined requests',
                onTap: () => context.push('/caregiver/my-patients'),
              ),
              MfIconTile(
                vertical: true,
                icon: Icons.history_rounded,
                label: 'Emergency history',
                subtitle: 'Past and active emergencies',
                onTap: () => context.push('/caregiver/history'),
              ),
              MfIconTile(
                vertical: true,
                icon: Icons.map_outlined,
                label: 'Live map',
                subtitle: 'Where active emergencies are',
                onTap: () => context.go('/caregiver/maps'),
              ),
              MfIconTile(
                vertical: true,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Messages',
                subtitle: 'Chats with patients and responders',
                onTap: () => context.go('/caregiver/chats'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<CaregiverConnection> patients, List<CaregiverEmergencyDetails> activeEmergencies) {
    final activeAlerts = activeEmergencies.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: MfStatTile(
                value: patients.length.toString(),
                label: 'Total monitored',
                icon: Icons.people_outline_rounded,
              ),
            ),
            const SizedBox(width: MfSpace.sm),
            Expanded(
              child: MfStatTile(
                value: activeAlerts.toString(),
                label: 'Active alerts',
                icon: activeAlerts > 0 ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                tone: activeAlerts > 0 ? MfTone.danger : MfTone.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Active SOS for a linked patient: who, what, status, when, "Track live".
class _ActiveSosCard extends StatelessWidget {
  final CaregiverEmergencyDetails emergency;
  const _ActiveSosCard({required this.emergency});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final danger = MfColors.tone(context, MfTone.danger);
    final type = EmergencyTypes.label(emergency.emergencyType);
    final who = emergency.patientName ?? 'A linked patient';
    final started = caregiverRelativeTime(emergency.createdAt);

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Active SOS from $who. ${caregiverStatusLabel(emergency.status)}.',
      child: MfCard(
        tone: MfTone.danger,
        onTap: () => context.push('/caregiver/tracking/${emergency.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.emergency_share_outlined, color: danger.foreground, size: 20),
                const SizedBox(width: MfSpace.xs),
                Expanded(
                  child: Text(
                    'Active SOS',
                    style: text.labelLarge?.copyWith(color: danger.foreground, fontWeight: FontWeight.w600),
                  ),
                ),
                if (started.isNotEmpty)
                  Text(started, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: MfSpace.xs),
            Text(who, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: MfSpace.xxs),
            Text(type, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: MfSpace.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MfStatusChip.emergency(emergency.status),
            ),
            const SizedBox(height: MfSpace.md),
            MfPrimaryButton(
              label: 'Track live',
              icon: Icons.my_location_rounded,
              tone: MfTone.danger,
              semanticLabel: 'Track $who live',
              onPressed: () => context.push('/caregiver/tracking/${emergency.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linked patient with safety status and per-patient actions.
class _PatientCard extends ConsumerWidget {
  final CaregiverConnection patient;
  final CaregiverEmergencyDetails? activeEmergency;
  const _PatientCard({required this.patient, required this.activeEmergency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final String? activeEmergencyId = activeEmergency?.id ??
        (patient.hasActiveEmergency == true ? patient.activeEmergencyId : null);
    final bool isActive = activeEmergencyId != null;
    final name = patient.patientName ?? patient.patientEmail ?? 'Unknown patient';
    final details = [
      patient.relationship,
      if (patient.bloodType != null) 'Blood ${patient.bloodType}',
    ].join('  ·  ');

    return MfCard(
      tone: isActive ? MfTone.danger : null,
      semanticLabel: isActive ? '$name, active emergency' : name,
      onTap: () {
        if (activeEmergencyId != null) {
          context.push('/caregiver/tracking/$activeEmergencyId');
        } else {
          openCaregiverPatientProfile(context, patient.patientId);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MfAvatar(name: name, size: 44),
              const SizedBox(width: MfSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(details, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    if (isActive) ...[
                      const SizedBox(height: MfSpace.xxs),
                      Text(
                        caregiverStatusLabel(activeEmergency?.status ?? 'ACTIVE'),
                        style: text.bodySmall?.copyWith(
                          color: MfColors.tone(context, MfTone.danger).foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: MfSpace.xs),
              caregiverLinkStatusChip(linkStatus: patient.status, sosActive: isActive),
            ],
          ),
          const SizedBox(height: MfSpace.sm),
          if (isActive) ...[
            MfPrimaryButton(
              label: 'Track live',
              icon: Icons.my_location_rounded,
              tone: MfTone.danger,
              height: MfSize.minTouch,
              semanticLabel: 'Track $name live',
              onPressed: () => context.push('/caregiver/tracking/$activeEmergencyId'),
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
                  onPressed: () => openCaregiverPatientProfile(context, patient.patientId),
                ),
              ),
              if (patient.status != 'PENDING' && patient.status != 'REJECTED') ...[
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: MfSecondaryButton(
                    label: 'Message',
                    icon: Icons.chat_bubble_outline_rounded,
                    semanticLabel: 'Message $name',
                    onPressed: () => openCaregiverPatientChat(
                      context,
                      ref,
                      patientId: patient.patientId,
                      patientName: patient.patientName,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
