import 'package:flutter/material.dart';

class PatientTypeInfoScreen extends StatelessWidget {
  /// Pass a patientType to highlight one category, or null to show all.
  final String? patientType;
  const PatientTypeInfoScreen({Key? key, this.patientType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('How MediFind Helps You'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'MediFind is designed for everyone, with special support built for patients with disabilities.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 24),

          _PatientTypeCard(
            type: 'NORMAL',
            isActive: patientType == null || patientType == 'NORMAL',
            icon: Icons.person_rounded,
            color: const Color(0xFF1976D2),
            title: 'Standard Patient',
            subtitle: 'Full access to all features',
            features: const [
              'One-tap SOS emergency button',
              'Digital medical profile with blood type, allergies & medications',
              'Upload & store medical report images securely',
              'Assign and notify caregivers instantly',
              'Real-time responder tracking on map',
              'Select emergency category (Cardiac, Injury, etc.)',
            ],
          ),
          const SizedBox(height: 16),

          _PatientTypeCard(
            type: 'DEAF',
            isActive: patientType == null || patientType == 'DEAF',
            icon: Icons.hearing_disabled_rounded,
            color: const Color(0xFF00897B),
            title: 'Deaf / Hearing Impaired',
            subtitle: 'Text-first, vibration-powered emergency flow',
            features: const [
              '🔔 All alerts are fully visual — no audio required',
              '📳 Strong vibration feedback confirms SOS activation',
              '💬 Predefined emergency text messages sent to responders',
              '🔡 Text-only interface mode hides audio-dependent UI',
              '🎨 High-contrast mode for maximum visual clarity',
              '📍 Location & medical profile auto-attached to every SOS',
              '👁 Visual countdown with color changes instead of beeps',
            ],
          ),
          const SizedBox(height: 16),

          _PatientTypeCard(
            type: 'BLIND',
            isActive: patientType == null || patientType == 'BLIND',
            icon: Icons.visibility_off_rounded,
            color: const Color(0xFFF57C00),
            title: 'Blind / Visually Impaired',
            subtitle: 'Voice-first, audio-guided emergency activation',
            features: const [
              '🗣 Voice guidance reads every button and alert aloud',
              '🖐 Large tactile SOS button — easy to locate by touch',
              '🔊 Audio countdown feedback during the 10s safety window',
              '📢 App auto-generates a voice message for the responder (TTS)',
              '🩺 Medical summary read aloud to arriving responder',
              '📳 Vibration confirms SOS sent (for combined impairments)',
              '⚡ Minimal UI — large buttons, no complex navigation needed',
            ],
          ),
          const SizedBox(height: 24),

          // Reminder info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your patient type is set during registration and can be updated in your medical profile at any time.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.primary.shade800, height: 1.5),
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

// ---------------------------------------------------------------------------
// Patient Type Card
// ---------------------------------------------------------------------------
class _PatientTypeCard extends StatelessWidget {
  final String type;
  final bool isActive;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> features;

  const _PatientTypeCard({
    required this.type,
    required this.isActive,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'YOUR TYPE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Features list
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
