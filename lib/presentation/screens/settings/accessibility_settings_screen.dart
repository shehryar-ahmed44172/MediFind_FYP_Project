import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  bool _voiceGuidance = false;
  bool _largeButtons = false;
  bool _highContrast = false;
  bool _vibrationFeedback = true;
  bool _textOnlyMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            icon: Icons.record_voice_over_outlined,
            title: 'Voice Guidance',
            subtitle: 'Read buttons and alerts aloud for blind users',
            value: _voiceGuidance,
            onChanged: (v) => setState(() => _voiceGuidance = v),
          ),
          _AccessibilityTile(
            icon: Icons.contrast_rounded,
            title: 'High Contrast Mode',
            subtitle: 'Increase color contrast for better visibility',
            value: _highContrast,
            onChanged: (v) => setState(() => _highContrast = v),
          ),
          _AccessibilityTile(
            icon: Icons.text_fields_rounded,
            title: 'Text-Only Interface',
            subtitle: 'Simplified text-based mode for deaf users',
            value: _textOnlyMode,
            onChanged: (v) => setState(() => _textOnlyMode = v),
          ),

          const SizedBox(height: 16),
          _SectionHeader('Physical Accessibility'),

          _AccessibilityTile(
            icon: Icons.zoom_in_rounded,
            title: 'Large Buttons Mode',
            subtitle: 'Bigger buttons for users with limited dexterity',
            value: _largeButtons,
            onChanged: (v) => setState(() => _largeButtons = v),
          ),
          _AccessibilityTile(
            icon: Icons.vibration_rounded,
            title: 'Vibration Feedback',
            subtitle: 'Vibrate on SOS trigger and important alerts',
            value: _vibrationFeedback,
            onChanged: (v) => setState(() => _vibrationFeedback = v),
          ),

          const SizedBox(height: 24),

          // SOS Minimization Tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Quick SOS Tip',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
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

          ElevatedButton(
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
          ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
