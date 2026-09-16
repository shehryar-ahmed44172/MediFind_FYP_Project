import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    final user = ref.watch(currentUserProvider).valueOrNull;
    final role = user?.role ?? 'PATIENT';

    final isPatient   = role == 'PATIENT';
    final isResponder = role == 'RESPONDER';
    final isCaregiver = role == 'CAREGIVER';

    final isDeafPatient   = isPatient && (user?.patientType?.toUpperCase() == 'DEAF');
    final isNormalPatient = isPatient && !isDeafPatient;

    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Accessibility',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
        children: [
          // ── DEAF & HARD OF HEARING ───────────────────────────────────────────
          MfCard(
            tone: MfTone.primary,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.md, MfSpace.md, MfSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.hearing_disabled_outlined, color: MfColors.tone(context, MfTone.primary).foreground),
                      const SizedBox(width: MfSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text('Deaf & hard of hearing', style: text.titleMedium),
                            ),
                            const SizedBox(height: MfSpace.xxs),
                            Text(
                              'Emergency alerts arrive as a flashing screen and vibration, never sound only.',
                              style: text.bodySmall?.copyWith(color: cs.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _SwitchRow(
                  icon: Icons.text_fields_rounded,
                  title: 'Text-only mode',
                  subtitle: 'Removes voice and mic elements and shows quick phrases in chat',
                  value: settings.textOnlyMode,
                  onChanged: (_) => notifier.toggleTextOnlyMode(),
                ),
                const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                _SwitchRow(
                  icon: Icons.vibration_rounded,
                  title: 'Vibration feedback',
                  subtitle: isDeafPatient
                      ? 'Primary alert channel. Vibrates on SOS trigger, responder assignment and status changes'
                      : isResponder
                          ? 'Vibrate on incoming emergency alerts and acceptances'
                          : isCaregiver
                              ? 'Vibrate on patient SOS and caregiver notifications'
                              : 'Vibrate on SOS trigger and important alerts',
                  value: settings.vibrationFeedback,
                  onChanged: (_) => notifier.toggleVibrationFeedback(),
                ),
                const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                _SwitchRow(
                  icon: Icons.contrast_rounded,
                  title: 'High contrast',
                  subtitle: 'Increase colour contrast for better visibility',
                  value: settings.highContrast,
                  onChanged: (_) => notifier.toggleHighContrast(),
                ),
                if (isDeafPatient) ...[
                  const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                  MfIconTile(
                    icon: Icons.chat_outlined,
                    label: 'Quick messages',
                    subtitle: 'Edit the one-tap phrases shown above the chat input',
                    onTap: () => context.push('/predefined-messages'),
                  ),
                ],
                if (isPatient) ...[
                  const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                  MfIconTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About deaf & hearing modes',
                    subtitle: 'What changes in Deaf mode and how to switch',
                    onTap: () => context.push('/home/patient-type-info'),
                  ),
                ],
                if (isPatient) ...[
                  const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                  MfIconTile(
                    icon: Icons.badge_outlined,
                    label: 'Show to people nearby',
                    subtitle: 'Full-screen card explaining that you are deaf',
                    onTap: () => context.push('/home/show-card'),
                  ),
                ],
                const SizedBox(height: MfSpace.xxs),
              ],
            ),
          ),

          const SizedBox(height: MfSpace.lg),

          // ── DISPLAY ─────────────────────────────────────────────────────────
          const MfSectionTitle('Display'),
          MfCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FontSizeSlider(
                  value: settings.fontSizeMultiplier,
                  onChanged: (val) => notifier.setFontSizeMultiplier(val),
                ),
                const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                _SwitchRow(
                  icon: Icons.touch_app_outlined,
                  title: 'Large buttons',
                  subtitle: 'Bigger tap targets for users with limited dexterity',
                  value: settings.largeButtons,
                  onChanged: (_) => notifier.toggleLargeButtons(),
                ),
                const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                _ThemeModeRow(
                  value: settings.themeMode,
                  onChanged: notifier.setThemeMode,
                ),
              ],
            ),
          ),

          // ── SOUND ───────────────────────────────────────────────────────────
          // Voice Guidance — Normal patients and responders only (never deaf patients)
          if (isNormalPatient || isResponder) ...[
            const SizedBox(height: MfSpace.lg),
            MfSectionTitle(isResponder ? 'Voice alerts' : 'Sound'),
            MfCard(
              padding: EdgeInsets.zero,
              child: _SwitchRow(
                icon: isResponder
                    ? Icons.record_voice_over_outlined
                    : Icons.volume_up_outlined,
                title: isResponder ? 'Hands-free voice alerts' : 'Voice guidance',
                subtitle: isResponder
                    ? 'Reads patient details, emergency type and location aloud while driving'
                    : 'Speaks emergency status updates aloud (e.g. "Responder assigned and on the way")',
                value: settings.voiceGuidanceEnabled,
                onChanged: (_) => notifier.toggleVoiceGuidance(),
              ),
            ),
          ],

          const SizedBox(height: MfSpace.lg),

          // ── ROLE-SPECIFIC TIP ─────────────────────────────────────────────────
          _buildTipCard(isDeafPatient, isNormalPatient, isResponder, isCaregiver),

          const SizedBox(height: MfSpace.lg),

          // ── RESET TO DEFAULTS ─────────────────────────────────────────────────
          MfSecondaryButton(
            label: 'Reset to profile defaults',
            icon: Icons.restore_rounded,
            tone: MfTone.neutral,
            onPressed: () async {
              final confirmed = await showMfConfirmDialog(
                context,
                title: 'Reset accessibility settings?',
                message: 'All options on this screen return to the defaults for your profile.',
                confirmLabel: 'Reset',
                icon: Icons.restore_rounded,
              );
              if (!confirmed) return;
              notifier.resetToProfileDefaults(user?.patientType);
              if (context.mounted) {
                showMfSnackBar(context, 'Settings reset to profile defaults', tone: MfTone.success);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(
    bool isDeafPatient,
    bool isNormalPatient,
    bool isResponder,
    bool isCaregiver,
  ) {
    if (isDeafPatient) {
      return const MfInfoBanner(
        icon: Icons.hearing_disabled_outlined,
        title: 'Deaf mode tips',
        message:
            'All emergency alerts use vibration and full-screen visual flashes. '
            'Keep Vibration feedback on and make sure your phone is not on silent. '
            'Set up Quick messages so you can send pre-written messages in one tap during an emergency.',
      );
    } else if (isNormalPatient) {
      return const MfInfoBanner(
        icon: Icons.info_outline_rounded,
        title: 'Quick SOS tip',
        message:
            'SOS is designed to be triggered in just 2 taps:\n'
            '1. Long-press the SOS button on the home screen\n'
            '2. Cancel within 60 seconds if it was a mistake, or tap Send SOS now',
      );
    } else if (isResponder) {
      return const MfInfoBanner(
        icon: Icons.info_outline_rounded,
        title: 'Response guidelines',
        message:
            'Enable Hands-free voice alerts so patient details are read aloud '
            'the moment you accept an emergency, with no need to look at the screen while driving. '
            'Keep Vibration feedback on so you never miss an incoming alert.',
      );
    } else if (isCaregiver) {
      return const MfInfoBanner(
        icon: Icons.shield_outlined,
        title: 'Monitoring tips',
        message:
            'You will receive instant vibration and visual alerts if any of your '
            'linked patients trigger an emergency SOS. Keep Vibration feedback on '
            'and ensure the app runs in the background.',
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Switch row: whole row tappable, 56dp min height ─────────────────────────
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      toggled: value,
      label: title,
      hint: subtitle,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
            child: Row(
              children: [
                Icon(icon, color: value ? MfColors.tone(context, MfTone.primary).foreground : cs.onSurfaceVariant),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: MfSpace.xs),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Font Size Slider ──────────────────────────────────────────────────────────
class _FontSizeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _FontSizeSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final percent = '${(value * 100).toInt()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.sm, MfSpace.md, MfSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.format_size_rounded, color: cs.onSurfaceVariant),
              const SizedBox(width: MfSpace.sm),
              Expanded(child: Text('Text size', style: text.titleSmall)),
              MfStatusChip(label: percent, tone: MfTone.primary),
            ],
          ),
          Semantics(
            label: 'Text size',
            value: percent,
            child: Slider(
              value: value,
              min: 1.0, // 100% floor — never smaller than default
              max: 1.5,
              divisions: 5,
              label: percent,
              onChanged: onChanged,
            ),
          ),
          Row(
            children: [
              Text('100%', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('150%', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: MfSpace.xs),
          // Live preview — the app-wide text scale is applied through the
          // theme, so these styles already reflect the current setting.
          Container(
            padding: const EdgeInsets.all(MfSpace.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: MfRadius.smAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: MfSpace.xxs),
                Text('Responder is on the way', style: text.titleMedium),
                Text('Arriving in about 6 minutes.', style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme mode segmented control ─────────────────────────────────────────────
class _ThemeModeRow extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeModeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(MfSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode_outlined, color: cs.onSurfaceVariant),
              const SizedBox(width: MfSpace.sm),
              Expanded(child: Text('Theme', style: text.titleSmall)),
            ],
          ),
          const SizedBox(height: MfSpace.sm),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(0, MfSize.minTouch),
              shape: const RoundedRectangleBorder(borderRadius: MfRadius.smAll),
            ),
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}
