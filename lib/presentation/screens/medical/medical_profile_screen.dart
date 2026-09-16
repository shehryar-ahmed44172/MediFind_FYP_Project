import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/medical_profile.dart';
import '../../providers/medical_profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

const _editRoute = '/home/medical-profile/edit';

class MedicalProfileScreen extends ConsumerWidget {
  const MedicalProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);

    return currentUserId.when(
      data: (userId) => _buildProfileContent(context, ref, userId ?? ''),
      loading: () => const MfScaffold(
        title: 'Medical profile',
        body: MfLoading(label: 'Loading your profile'),
      ),
      error: (e, _) => MfScaffold(
        title: 'Medical profile',
        body: MfErrorState(
          message: 'We could not load your account. Please try again.',
          onRetry: () => ref.invalidate(currentUserIdProvider),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, String userId) {
    final profileAsync = ref.watch(getMedicalProfileProvider(userId));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final hasProfile = profileAsync.valueOrNull != null;

    return MfScaffold(
      title: 'Medical profile',
      subtitle: 'Your health information',
      actions: [
        MfIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit medical profile',
          onPressed: () => context.push(_editRoute),
        ),
      ],
      bottomBar: hasProfile
          ? MfPrimaryButton(
              label: 'Edit medical profile',
              icon: Icons.edit_outlined,
              onPressed: () => context.push(_editRoute),
            )
          : null,
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return MfEmptyState(
              icon: Icons.medical_information_outlined,
              title: 'No medical profile yet',
              message: 'Add your blood type, allergies and medications so responders can treat you safely.',
              actionLabel: 'Create medical profile',
              actionIcon: Icons.add_rounded,
              onAction: () => context.push(_editRoute),
            );
          }
          final isDeaf =
              profile.patientType.toUpperCase() == 'DEAF' || user?.patientType?.toUpperCase() == 'DEAF';
          return _ProfileBody(profile: profile, isDeaf: isDeaf);
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(MfSpace.gutter),
          children: [
            const MfSkeleton(height: 132, radius: MfRadius.md),
            const SizedBox(height: MfSpace.sm),
            MfSkeleton.list(count: 3, itemHeight: 88),
          ],
        ),
        error: (e, _) => MfErrorState(
          title: 'Could not load your medical profile',
          message: e.toString().contains('timeout')
              ? 'The server is taking too long to respond. Please check your internet connection.'
              : 'We encountered an error while loading your profile. Please try again.',
          onRetry: () => ref.invalidate(getMedicalProfileProvider(userId)),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final MedicalProfile profile;
  final bool isDeaf;
  const _ProfileBody({required this.profile, required this.isDeaf});

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.day}/${l.month}/${l.year}, ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final danger = MfColors.tone(context, MfTone.danger);

    final disabilities = <String>[
      if (profile.disabilityType?.isNotEmpty == true) profile.disabilityType!,
      ...profile.disabilities.where((d) => d.isNotEmpty && d != profile.disabilityType),
    ];
    final notes = profile.additionalNotes?.trim() ?? '';
    final history = profile.medicalHistory?.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.lg),
      children: [
        // ── Critical information ─────────────────────────────────────────
        const MfSectionTitle('Critical information'),
        MfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm, vertical: MfSpace.xs),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: danger.container,
                      borderRadius: MfRadius.smAll,
                      border: Border.all(color: danger.border),
                    ),
                    child: Text(
                      profile.bloodType.isNotEmpty ? profile.bloodType : '--',
                      style:
                          text.headlineSmall?.copyWith(color: danger.foreground, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blood group', style: text.titleSmall),
                        Text(
                          profile.bloodType.isNotEmpty
                              ? 'Used for emergency transfusion decisions'
                              : 'Not set. Edit your profile to add it.',
                          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MfSpace.md),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: danger.foreground),
                  const SizedBox(width: MfSpace.xs),
                  Text('Allergies', style: text.titleSmall),
                ],
              ),
              const SizedBox(height: MfSpace.xs),
              if (profile.allergies.isEmpty)
                Text('No known allergies', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
              else
                Wrap(
                  spacing: MfSpace.xs,
                  runSpacing: MfSpace.xs,
                  children: [
                    for (final a in profile.allergies)
                      MfStatusChip(label: a, tone: MfTone.danger, icon: Icons.error_outline_rounded),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: MfSpace.lg),

        // ── Patient type / disabilities ──────────────────────────────────
        const MfSectionTitle('Patient type and accessibility'),
        if (isDeaf) ...[
          const MfInfoBanner(
            icon: Icons.hearing_disabled_outlined,
            tone: MfTone.primary,
            title: 'Deaf / hard of hearing patient',
            message: 'Communicates by text, writing or signs.',
          ),
          const SizedBox(height: MfSpace.xs),
        ],
        MfCard(
          padding: const EdgeInsets.symmetric(vertical: MfSpace.xxs),
          child: Column(
            children: [
              MfKeyValueRow(
                icon: Icons.person_outline_rounded,
                label: 'Patient type',
                value: isDeaf ? 'Deaf' : 'Normal',
              ),
              const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
              MfKeyValueRow(
                icon: Icons.accessible_forward_rounded,
                label: 'Disability / accessibility need',
                value: disabilities.isEmpty ? 'None specified' : disabilities.join(', '),
              ),
            ],
          ),
        ),
        const SizedBox(height: MfSpace.lg),

        // ── Chronic conditions ───────────────────────────────────────────
        const MfSectionTitle('Chronic conditions'),
        MfCard(
          child: SizedBox(
            width: double.infinity,
            child: profile.chronicDiseases.isEmpty
                ? Text('None recorded', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
                : Wrap(
                    spacing: MfSpace.xs,
                    runSpacing: MfSpace.xs,
                    children: [
                      for (final c in profile.chronicDiseases)
                        MfStatusChip(label: c, tone: MfTone.warning, icon: Icons.monitor_heart_outlined),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: MfSpace.lg),

        // ── Medications ──────────────────────────────────────────────────
        const MfSectionTitle('Current medications'),
        if (profile.medications.isEmpty)
          MfCard(
            child: SizedBox(
              width: double.infinity,
              child: Text('None recorded', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          )
        else
          MfListGroup(
            children: [
              for (final m in profile.medications) _MedicationRow(medication: m),
            ],
          ),
        const SizedBox(height: MfSpace.lg),

        // ── Emergency contacts summary ───────────────────────────────────
        MfSectionTitle(
          'Emergency contacts',
          actionLabel: 'Manage',
          onAction: () => context.push('/home/emergency-contacts'),
        ),
        if (profile.emergencyContacts.isEmpty)
          MfCard(
            child: SizedBox(
              width: double.infinity,
              child: Text('No emergency contacts added',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          )
        else
          MfListGroup(
            children: [
              for (final c in profile.emergencyContacts)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
                  child: Row(
                    children: [
                      MfAvatar(name: c.name, size: 40),
                      const SizedBox(width: MfSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: text.titleSmall),
                            Text(
                              '${c.relationship} · ${c.phoneNumber}',
                              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: MfSpace.lg),

        // ── Notes ────────────────────────────────────────────────────────
        if (notes.isNotEmpty || history.isNotEmpty) ...[
          const MfSectionTitle('Notes'),
          MfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notes.isNotEmpty) ...[
                  Text('Additional notes', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: MfSpace.xxs),
                  Text(notes, style: text.bodyMedium),
                ],
                if (notes.isNotEmpty && history.isNotEmpty) const SizedBox(height: MfSpace.sm),
                if (history.isNotEmpty) ...[
                  Text('Medical history', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: MfSpace.xxs),
                  Text(history, style: text.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(height: MfSpace.lg),
        ],

        // ── Related ──────────────────────────────────────────────────────
        const MfSectionTitle('Records'),
        MfListGroup(
          children: [
            MfIconTile(
              icon: Icons.description_outlined,
              label: 'Medical reports',
              subtitle: 'View and upload lab results, scans and prescriptions',
              onTap: () => context.push('/home/medical-reports'),
            ),
          ],
        ),

        if (profile.lastUpdated != null) ...[
          const SizedBox(height: MfSpace.md),
          Text(
            'Last updated ${_formatDate(profile.lastUpdated!)}',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final Medication medication;
  const _MedicationRow({required this.medication});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final details = [
      if (medication.dosage.isNotEmpty) medication.dosage,
      if (medication.frequency.isNotEmpty) medication.frequency,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
      child: Row(
        children: [
          Icon(Icons.medication_outlined, size: 20, color: cs.primary),
          const SizedBox(width: MfSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medication.name, style: text.titleSmall),
                if (details.isNotEmpty)
                  Text(details, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
