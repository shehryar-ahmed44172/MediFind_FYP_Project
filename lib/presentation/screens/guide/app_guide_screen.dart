import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'guide_content.dart';

/// "How MediFind works" — the always-available help screen.
///
/// Same steps as the welcome tour plus the questions people ask later
/// (privacy, permissions, no internet) and a short explanation of the four
/// roles, so a visitor or supervisor can understand the whole system from
/// inside the app.
class AppGuideScreen extends ConsumerWidget {
  const AppGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final textOnly = ref.watch(accessibilityProvider.select((s) => s.textOnlyMode));
    final role = (user?.role ?? 'PATIENT').toUpperCase();
    final isDeaf = role == 'PATIENT' &&
        ((user?.patientType ?? '').toUpperCase() == 'DEAF' || textOnly);

    final sections = GuideContent.help(role, isDeaf);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'How MediFind works',
      subtitle: 'Guide for ${GuideContent.roleLabel(role, isDeaf).toLowerCase()}s',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
        children: [
          MfCard(
            tone: MfTone.primary,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logos/medifind_mark.png',
                    width: 40, height: 40, excludeFromSemantics: true),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emergency help in one tap', style: text.titleMedium),
                      const SizedBox(height: MfSpace.xxs),
                      Text(
                        'MediFind connects you to the nearest verified motorbike ambulance, '
                        'and works fully without speaking or hearing.',
                        style: text.bodySmall?.copyWith(color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MfSpace.lg),

          for (final section in sections) ...[
            MfSectionTitle(section.title),
            for (final step in section.steps) ...[
              _GuideStepCard(step: step),
              const SizedBox(height: MfSpace.sm),
            ],
            const SizedBox(height: MfSpace.md),
          ],

          // ── Where to go next ────────────────────────────────────────────
          const MfSectionTitle('More help'),
          MfListGroup(
            children: [
              MfIconTile(
                icon: Icons.play_circle_outline_rounded,
                label: 'Show the welcome tour again',
                subtitle: 'The short introduction you saw after signing in',
                onTap: () => context.push('/welcome-guide'),
              ),
              if (role == 'PATIENT')
                MfIconTile(
                  icon: Icons.hearing_disabled_outlined,
                  label: 'Deaf & hearing modes',
                  subtitle: 'What changes in Deaf mode and how to switch',
                  onTap: () => context.push('/home/patient-type-info'),
                ),
              MfIconTile(
                icon: Icons.settings_accessibility_rounded,
                label: 'Accessibility settings',
                subtitle: 'Text size, contrast, vibration and voice guidance',
                onTap: () => context.push('/accessibility-settings'),
              ),
            ],
          ),
          const SizedBox(height: MfSpace.lg),
          const MfInfoBanner(
            icon: Icons.phone_in_talk_outlined,
            tone: MfTone.warning,
            title: 'In an emergency without internet',
            message: 'MediFind needs a data connection. If you have no internet, call 1122.',
          ),
        ],
      ),
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  final GuideStep step;
  const _GuideStepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tone = MfColors.tone(context, MfTone.primary);

    return MfCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tone.container, borderRadius: MfRadius.smAll),
            child: Icon(step.icon, color: tone.foreground),
          ),
          const SizedBox(width: MfSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(step.title, style: text.titleSmall)),
                const SizedBox(height: 2),
                Text(
                  step.body,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                ),
                for (final point in step.points)
                  Padding(
                    padding: const EdgeInsets.only(top: MfSpace.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: tone.foreground),
                        const SizedBox(width: MfSpace.xs),
                        Expanded(child: Text(point, style: text.bodySmall)),
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
