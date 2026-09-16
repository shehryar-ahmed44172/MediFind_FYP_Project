import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../domain/entities/medical_profile.dart';
import '../../../domain/entities/user.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_profile_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// Medical ID tab (patient): critical medical summary, emergency QR code and
/// entry points to the full medical profile, reports, emergency contacts and
/// caregivers.
class MedicalIdScreen extends ConsumerWidget {
  const MedicalIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    if (userAsync.isLoading && user == null) {
      return const Padding(
        padding: EdgeInsets.all(MfSpace.md),
        child: SingleChildScrollView(child: _Skeleton()),
      );
    }
    if (user == null) {
      return MfErrorState(
        message: 'Could not load your account.',
        onRetry: () => ref.invalidate(currentUserProvider),
      );
    }

    final profileAsync = ref.watch(getMedicalProfileProvider(user.id));
    final settings = ref.watch(accessibilityProvider);
    final isDeaf = (user.patientType ?? '').toUpperCase() == 'DEAF' || settings.textOnlyMode;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(getMedicalProfileProvider(user.id));
        await ref.read(getMedicalProfileProvider(user.id).future).catchError((_) => null);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.md, MfSpace.md, MfSpace.xl),
        children: [
          profileAsync.when(
            loading: () => const _Skeleton(),
            error: (e, _) => MfCard(
              child: MfErrorState(
                compact: true,
                message: 'Could not load your medical profile.',
                onRetry: () => ref.invalidate(getMedicalProfileProvider(user.id)),
              ),
            ),
            data: (profile) => profile == null
                ? MfCard(
                    child: MfEmptyState(
                      compact: true,
                      icon: Icons.medical_information_outlined,
                      title: 'No medical information yet',
                      message: 'Add your blood group, allergies and conditions so responders can help you faster.',
                      actionLabel: 'Add medical information',
                      actionIcon: Icons.add_rounded,
                      onAction: () => context.push('/home/medical-profile/edit'),
                    ),
                  )
                : _SummaryCard(user: user, profile: profile),
          ),
          const SizedBox(height: MfSpace.lg),
          if (isDeaf) ...[
            MfCard(
              tone: MfTone.primary,
              onTap: () => context.push('/home/show-card'),
              semanticLabel: 'Show to people nearby. Full-screen card explaining you are deaf.',
              child: const _RowContent(
                icon: Icons.co_present_outlined,
                title: 'Show to people nearby',
                subtitle: 'Full-screen card: "I am deaf, please write or type".',
              ),
            ),
            const SizedBox(height: MfSpace.lg),
          ],
          const MfSectionTitle('Records'),
          MfListGroup(
            children: [
              MfIconTile(
                icon: Icons.assignment_ind_outlined,
                label: 'Full medical profile',
                subtitle: 'Conditions, medications, notes',
                onTap: () => context.push('/home/medical-profile'),
              ),
              MfIconTile(
                icon: Icons.folder_open_outlined,
                label: 'Medical reports',
                subtitle: 'Upload and view reports',
                onTap: () => context.push('/home/medical-reports'),
              ),
              MfIconTile(
                icon: Icons.contact_phone_outlined,
                label: 'Emergency contacts',
                subtitle: profileAsync.valueOrNull == null
                    ? 'People to contact in an emergency'
                    : '${profileAsync.valueOrNull!.emergencyContacts.length} saved',
                onTap: () => context.push('/home/emergency-contacts'),
              ),
              MfIconTile(
                icon: Icons.groups_outlined,
                label: 'My caregivers',
                subtitle: 'People who get your SOS alerts',
                onTap: () => context.push('/home/caregivers'),
              ),
            ],
          ),
          const SizedBox(height: MfSpace.lg),
          const MfInfoBanner(
            icon: Icons.lock_outline_rounded,
            tone: MfTone.neutral,
            title: 'Your medical ID is private',
            message: 'Only you can show the QR code. Responders see your data only during an '
                'active emergency, and every access is logged.',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final User user;
  final MedicalProfile profile;
  const _SummaryCard({required this.user, required this.profile});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDeaf = (user.patientType ?? profile.patientType).toUpperCase() == 'DEAF';
    final allergies = profile.allergies.where((a) => a.trim().isNotEmpty).toList();
    final conditions = profile.chronicDiseases.where((a) => a.trim().isNotEmpty).toList();

    return MfCard(
      padding: const EdgeInsets.all(MfSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MfAvatar(imageUrl: user.profileImageUrl, name: user.fullName, size: 48),
              const SizedBox(width: MfSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: text.titleMedium),
                    const SizedBox(height: MfSpace.xxs),
                    MfStatusChip(
                      label: isDeaf ? 'Deaf / hard of hearing' : 'Hearing',
                      icon: isDeaf ? Icons.hearing_disabled_rounded : Icons.hearing_rounded,
                      tone: isDeaf ? MfTone.primary : MfTone.neutral,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MfSpace.md),
          const Divider(height: 1),
          const SizedBox(height: MfSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Fact(
                  label: 'Blood group',
                  child: Text(
                    profile.bloodType.trim().isEmpty ? 'Not set' : profile.bloodType,
                    style: text.headlineSmall?.copyWith(color: cs.error),
                  ),
                ),
              ),
              Expanded(
                child: _Fact(
                  label: 'Medications',
                  child: Text('${profile.medications.length}', style: text.headlineSmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: MfSpace.md),
          _Fact(
            label: 'Allergies',
            child: allergies.isEmpty
                ? Text('None recorded', style: text.bodyMedium)
                : Wrap(
                    spacing: MfSpace.xs,
                    runSpacing: MfSpace.xs,
                    children: [
                      for (final a in allergies)
                        MfStatusChip(label: a, tone: MfTone.danger, icon: Icons.warning_amber_rounded),
                    ],
                  ),
          ),
          const SizedBox(height: MfSpace.md),
          _Fact(
            label: 'Conditions',
            child: conditions.isEmpty
                ? Text('None recorded', style: text.bodyMedium)
                : Wrap(
                    spacing: MfSpace.xs,
                    runSpacing: MfSpace.xs,
                    children: [for (final c in conditions) MfStatusChip(label: c, tone: MfTone.neutral)],
                  ),
          ),
          const SizedBox(height: MfSpace.lg),
          MfPrimaryButton(
            label: 'Show emergency QR code',
            icon: Icons.qr_code_2_rounded,
            onPressed: () => showMedicalQrSheet(context, user: user, profile: profile),
          ),
          const SizedBox(height: MfSpace.xs),
          MfSecondaryButton(
            label: 'Edit medical information',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/home/medical-profile/edit'),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final Widget child;
  const _Fact({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: MfSpace.xxs),
        child,
      ],
    );
  }
}

class _RowContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _RowContent({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, MfTone.primary);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, color: t.foreground, size: 28),
        const SizedBox(width: MfSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              Text(subtitle, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: t.foreground),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MfSkeleton(height: 280, radius: MfRadius.md),
        SizedBox(height: MfSpace.lg),
        MfSkeleton(width: 120, height: 18),
        SizedBox(height: MfSpace.sm),
        MfSkeleton(height: 200, radius: MfRadius.md),
      ],
    );
  }
}

/// Bottom sheet with a QR code containing the patient's critical medical info
/// so first responders or bystanders can scan it without the app.
Future<void> showMedicalQrSheet(
  BuildContext context, {
  required User? user,
  required MedicalProfile? profile,
}) {
  final name = user?.fullName ?? 'Unknown';
  final blood = profile?.bloodType ?? 'Unknown';
  final allergies = (profile?.allergies.isNotEmpty ?? false) ? profile!.allergies.join(', ') : 'None';
  final conditions =
      (profile?.chronicDiseases.isNotEmpty ?? false) ? profile!.chronicDiseases.join(', ') : 'None';
  final isDeaf = profile?.patientType.toUpperCase() == 'DEAF';

  final qrData = 'MEDIFIND MEDICAL ID\n'
      'Name: $name\n'
      'Blood Type: $blood\n'
      'Allergies: $allergies\n'
      'Conditions: $conditions\n'
      'DEAF/MUTE: ${isDeaf ? "YES" : "NO"}';

  return showMfBottomSheet<void>(
    context,
    title: 'Emergency medical ID',
    subtitle: 'Anyone can scan this code to see your critical medical information.',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Semantics(
            image: true,
            label: 'QR code with your name, blood type, allergies and conditions',
            child: Container(
              padding: const EdgeInsets.all(MfSpace.md),
              decoration: BoxDecoration(
                color: Colors.white, // QR codes need a white quiet zone in every theme
                borderRadius: MfRadius.mdAll,
                border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        if (isDeaf) ...[
          const SizedBox(height: MfSpace.md),
          const MfStatusChip(
            label: 'Deaf / hard of hearing status included',
            icon: Icons.hearing_disabled_rounded,
            tone: MfTone.primary,
          ),
        ],
        const SizedBox(height: MfSpace.md),
        MfSecondaryButton(
          label: 'Close',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}
