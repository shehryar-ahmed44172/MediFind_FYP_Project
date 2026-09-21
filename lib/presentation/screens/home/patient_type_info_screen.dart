import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// Explains how MediFind adapts to deaf and hearing patients.
class PatientTypeInfoScreen extends ConsumerWidget {
  /// Pass a patientType to highlight one category, or null to use the
  /// signed-in patient's type (both are always shown).
  final String? patientType;
  const PatientTypeInfoScreen({super.key, this.patientType});

  static const _deafFeatures = [
    (Icons.flash_on_outlined, 'Visual alerts', 'Every alert flashes the screen. Nothing depends on sound.'),
    (Icons.vibration_rounded, 'Strong vibration', 'Distinct vibration patterns confirm SOS, assignment and arrival.'),
    (Icons.quickreply_outlined, 'Quick phrases', 'Send pre-written messages to responders with one tap.'),
    (Icons.mic_off_outlined, 'Text-only interface', 'Microphone and voice controls are hidden; chat always shows Send.'),
    (Icons.hearing_disabled_outlined, 'Responders are told', 'Your responder sees "Deaf: text only" before accepting.'),
    (Icons.badge_outlined, 'Show to people nearby', 'A full-screen card explains you are deaf and need help.'),
    (Icons.timer_outlined, 'Visual countdown', 'The SOS countdown is shown in large numbers instead of beeps.'),
  ];

  static const _hearingFeatures = [
    (Icons.sos_outlined, 'One-tap SOS', 'Request an emergency responder in seconds.'),
    (Icons.medical_information_outlined, 'Medical profile', 'Blood group, allergies and medications shared with your responder.'),
    (Icons.record_voice_over_outlined, 'Voice guidance', 'Optional spoken prompts and voice messages in chat.'),
    (Icons.people_outline_rounded, 'Caregivers', 'Linked caregivers are notified and can follow your emergency.'),
    (Icons.map_outlined, 'Live tracking', 'Follow the responder on the map with an estimated arrival time.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final type = (patientType ?? user?.patientType)?.toUpperCase();
    final isPatient = (user?.role ?? 'PATIENT').toUpperCase() == 'PATIENT';

    final deafCard = _ModeCard(
      icon: Icons.hearing_disabled_rounded,
      title: 'Deaf mode',
      subtitle: 'For Deaf and hard of hearing patients. Text-first, visual and vibration alerts.',
      isCurrent: type == 'DEAF',
      features: _deafFeatures,
    );
    final hearingCard = _ModeCard(
      icon: Icons.hearing_rounded,
      title: 'Hearing mode',
      subtitle: 'Standard alerts with sound, voice guidance and all features.',
      isCurrent: type == 'NORMAL',
      features: _hearingFeatures,
    );

    return MfScaffold(
      title: 'Deaf & hearing modes',
      subtitle: 'How MediFind adapts to you',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
        children: [
          Text(
            'MediFind is built deaf-first. Every emergency step works without sound, '
            'and hearing patients get the same features with optional voice support.',
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: MfSpace.lg),
          // Current mode first.
          if (type == 'NORMAL') ...[hearingCard, const SizedBox(height: MfSpace.md), deafCard]
          else ...[deafCard, const SizedBox(height: MfSpace.md), hearingCard],
          const SizedBox(height: MfSpace.lg),
          const MfInfoBanner(
            icon: Icons.info_outline_rounded,
            tone: MfTone.primary,
            title: 'Changing your mode',
            message: 'Your mode is chosen during registration, and you can switch it any time with '
                'the Deaf mode switch in Accessibility settings. Responders always see your current mode.',
          ),
          if (isPatient) ...[
            const SizedBox(height: MfSpace.md),
            MfListGroup(
              children: [
                MfIconTile(
                  icon: Icons.settings_accessibility_rounded,
                  label: 'Accessibility settings',
                  subtitle: 'Switch Deaf mode, vibration, contrast and text size',
                  onTap: () => context.push('/accessibility-settings'),
                ),
                MfIconTile(
                  icon: Icons.edit_note_rounded,
                  label: 'Edit medical profile',
                  subtitle: 'Blood group, allergies, medications and contacts',
                  onTap: () => context.push('/home/medical-profile/edit'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCurrent;
  final List<(IconData, String, String)> features;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCurrent,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final t = MfColors.tone(context, MfTone.primary);
    return MfCard(
      tone: isCurrent ? MfTone.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.container, borderRadius: MfRadius.smAll),
                child: Icon(icon, color: t.foreground),
              ),
              const SizedBox(width: MfSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title, style: text.titleMedium)),
                    Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: MfSpace.xs),
                const MfStatusChip(label: 'Your mode', icon: Icons.check_rounded, tone: MfTone.primary, solid: true),
              ],
            ],
          ),
          const SizedBox(height: MfSpace.sm),
          const Divider(height: 1),
          const SizedBox(height: MfSpace.xs),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MfSpace.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(f.$1, size: 20, color: t.foreground),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$2, style: text.titleSmall),
                        Text(f.$3, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
