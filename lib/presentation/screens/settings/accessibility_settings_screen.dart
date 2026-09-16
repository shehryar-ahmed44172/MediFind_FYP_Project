import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

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
    final theme = Theme.of(context);
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    final user = ref.watch(currentUserProvider).valueOrNull;
    final role = user?.role ?? 'PATIENT';

    final isPatient   = role == 'PATIENT';
    final isResponder = role == 'RESPONDER';
    final isCaregiver = role == 'CAREGIVER';

    final isDeafPatient   = isPatient && (user?.patientType?.toUpperCase() == 'DEAF');
    final isNormalPatient = isPatient && !isDeafPatient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── VISUAL ──────────────────────────────────────────────────────────
          const _SectionHeader('Visual'),

          _AccessibilityTile(
            icon: Icons.contrast_rounded,
            title: 'High Contrast Mode',
            subtitle: 'Increase colour contrast for better visibility',
            value: settings.highContrast,
            onChanged: (_) => notifier.toggleHighContrast(),
          ),

          // Text-Only Interface — Deaf patients only
          if (isDeafPatient)
            _AccessibilityTile(
              icon: Icons.text_fields_rounded,
              title: 'Text-Only Interface',
              subtitle:
                  'Removes voice/mic elements and enables quick-phrase shortcuts in chat',
              value: settings.textOnlyMode,
              onChanged: (_) => notifier.toggleTextOnlyMode(),
            ),

          const SizedBox(height: 16),

          // ── FONT SIZE ────────────────────────────────────────────────────────
          const _SectionHeader('Font Size'),
          _FontSizeSlider(
            value: settings.fontSizeMultiplier,
            onChanged: (val) => notifier.setFontSizeMultiplier(val),
            theme: theme,
          ),

          const SizedBox(height: 16),

          // ── PHYSICAL ─────────────────────────────────────────────────────────
          const _SectionHeader('Physical Accessibility'),

          _AccessibilityTile(
            icon: Icons.zoom_in_rounded,
            title: 'Large Buttons Mode',
            subtitle: 'Bigger tap targets for users with limited dexterity',
            value: settings.largeButtons,
            onChanged: (_) => notifier.toggleLargeButtons(),
          ),

          _AccessibilityTile(
            icon: Icons.vibration_rounded,
            title: 'Vibration Feedback',
            subtitle: isDeafPatient
                ? 'Primary alert channel — vibrates on SOS trigger, responder assignment, and status changes'
                : isResponder
                    ? 'Vibrate on incoming emergency alerts and acceptances'
                    : isCaregiver
                        ? 'Vibrate on patient SOS and caregiver notifications'
                        : 'Vibrate on SOS trigger and important alerts',
            value: settings.vibrationFeedback,
            onChanged: (_) => notifier.toggleVibrationFeedback(),
          ),

          const SizedBox(height: 16),

          // ── AUDIO ────────────────────────────────────────────────────────────
          // Voice Guidance — Normal patients and responders only (never deaf patients)
          if (isNormalPatient || isResponder) ...[
            _SectionHeader(isResponder ? 'Voice Alerts' : 'Audio'),

            _AccessibilityTile(
              icon: isResponder
                  ? Icons.record_voice_over_rounded
                  : Icons.volume_up_rounded,
              title: isResponder ? 'Hands-Free Voice Alerts' : 'Voice Guidance',
              subtitle: isResponder
                  ? 'Reads patient details, emergency type, and location aloud while driving — no need to look at the screen'
                  : 'Speaks emergency status updates aloud (e.g. "Responder assigned and on the way")',
              value: settings.voiceGuidanceEnabled,
              onChanged: (_) => notifier.toggleVoiceGuidance(),
            ),

            const SizedBox(height: 16),
          ],

          // ── QUICK PHRASES SHORTCUT — Deaf patients only ──────────────────────
          if (isDeafPatient) ...[
            const _SectionHeader('Communication'),
            _QuickPhrasesShortcut(theme: theme),
            const SizedBox(height: 16),
          ],

          // ── ROLE-SPECIFIC TIP ─────────────────────────────────────────────────
          _buildTipCard(
              theme, isDeafPatient, isNormalPatient, isResponder, isCaregiver),

          const SizedBox(height: 24),

          // ── RESET TO DEFAULTS ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                notifier.initializeFromUser(user?.patientType);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to profile defaults'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Reset to Profile Defaults'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTipCard(
    ThemeData theme,
    bool isDeafPatient,
    bool isNormalPatient,
    bool isResponder,
    bool isCaregiver,
  ) {
    if (isDeafPatient) {
      return _TipCard(
        theme: theme,
        icon: Icons.hearing_disabled_rounded,
        title: 'Deaf Mode Tips',
        message:
            'All emergency alerts use vibration and full-screen visual flashes. '
            'Keep Vibration Feedback ON and ensure your phone is not on silent. '
            'Set up Quick Phrases so you can send pre-written messages in one tap during an emergency.',
      );
    } else if (isNormalPatient) {
      return _TipCard(
        theme: theme,
        icon: Icons.info_outline_rounded,
        title: 'Quick SOS Tip',
        message:
            'SOS is designed to be triggered in just 2 taps:\n'
            '1. Long-press the SOS button on the home screen\n'
            '2. Confirm within the 10-second countdown',
      );
    } else if (isResponder) {
      return _TipCard(
        theme: theme,
        icon: Icons.bolt_rounded,
        title: 'Response Guidelines',
        message:
            'Enable Hands-Free Voice Alerts so patient details are read aloud '
            'the moment you accept an emergency — no need to look at the screen while driving. '
            'Keep Vibration Feedback ON so you never miss an incoming alert.',
      );
    } else if (isCaregiver) {
      return _TipCard(
        theme: theme,
        icon: Icons.security_rounded,
        title: 'Monitoring Tips',
        message:
            'You will receive instant vibration and visual alerts if any of your '
            'linked patients trigger an emergency SOS. Keep Vibration Feedback ON '
            'and ensure the app runs in the background.',
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Font Size Slider ──────────────────────────────────────────────────────────
class _FontSizeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ThemeData theme;

  const _FontSizeSlider({
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Row(
        children: [
          const Icon(Icons.format_size_rounded, color: Colors.grey),
          Expanded(
            child: Slider(
              value: value,
              min: 1.0,  // 100% floor — never smaller than default
              max: 1.5,
              divisions: 5,
              label: '${(value * 100).toInt()}%',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Phrases Shortcut (Deaf patients only) ───────────────────────────────
class _QuickPhrasesShortcut extends StatelessWidget {
  final ThemeData theme;
  const _QuickPhrasesShortcut({required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/predefined-messages'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.neumorphicOut,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Quick Phrases',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Edit the messages shown in your chat toolbar for fast one-tap sending',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ── Tip Card ──────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String title;
  final String message;

  const _TipCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.neumorphicIn,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Accessibility Tile ────────────────────────────────────────────────────────
class _AccessibilityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AccessibilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: value
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
