import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  // Using Riverpod provider instead of local state variables


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Visual Accessibility'),

          _AccessibilityTile(
            icon: Icons.contrast_rounded,
            title: 'High Contrast Mode',
            subtitle: 'Increase color contrast for better visibility',
            value: settings.highContrast,
            onChanged: (v) => notifier.toggleHighContrast(),
          ),
          _AccessibilityTile(
            icon: Icons.text_fields_rounded,
            title: 'Text-Only Interface',
            subtitle: 'Simplified text-based mode for deaf users',
            value: settings.textOnlyMode,
            onChanged: (v) => notifier.toggleTextOnlyMode(),
          ),
          
          const SizedBox(height: 16),
          _SectionHeader('Font Size'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Row(
              children: [
                const Icon(Icons.format_size, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: settings.fontSizeMultiplier,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label: '${(settings.fontSizeMultiplier * 100).toInt()}%',
                    onChanged: (val) => notifier.setFontSizeMultiplier(val),
                  ),
                ),
                Text('${(settings.fontSizeMultiplier * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _SectionHeader('Physical Accessibility'),

          _AccessibilityTile(
            icon: Icons.zoom_in_rounded,
            title: 'Large Buttons Mode',
            subtitle: 'Bigger buttons for users with limited dexterity',
            value: settings.largeButtons,
            onChanged: (v) => notifier.toggleLargeButtons(),
          ),
          _AccessibilityTile(
            icon: Icons.vibration_rounded,
            title: 'Vibration Feedback',
            subtitle: 'Vibrate on SOS trigger and important alerts',
            value: settings.vibrationFeedback,
            onChanged: (v) => notifier.toggleVibrationFeedback(),
          ),

          const SizedBox(height: 24),

          // SOS Minimization Tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.neumorphicIn,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Quick SOS Tip',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'SOS is designed to be triggered in just 2 taps: \n'
                  '1. Long press the SOS button on the home screen\n'
                  '2. Confirm in the 10-second countdown',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Accessibility settings saved!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.scaffoldBackgroundColor,
              foregroundColor: theme.colorScheme.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),

          // Reset to Defaults Button
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                final user = ref.read(currentUserProvider).valueOrNull;
                notifier.initializeFromUser(user?.patientType);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to profile defaults!'),
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

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
        secondary: Icon(icon,
            color:
                value ? Theme.of(context).colorScheme.primary : Colors.grey),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
