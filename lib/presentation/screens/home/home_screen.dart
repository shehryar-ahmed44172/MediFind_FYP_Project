import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../home/widgets/connectivity_banner.dart';
import '../home/patient_type_info_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.local_hospital_rounded,
                color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('MediFind'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Accessibility Settings',
            onPressed: () => context.go('/home/settings/accessibility'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outlined),
            tooltip: 'My Profile',
            onPressed: () => context.go('/home/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isConnected) const ConnectivityBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- SOS Section ----
                _SOSCard(),
                const SizedBox(height: 16),

                // ---- Patient Type Banner ----
                _PatientTypeBanner(patientType: 'NORMAL'),
                const SizedBox(height: 20),

                // ---- Quick Actions ----
                Text('Quick Access',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _QuickActionsGrid(),
                const SizedBox(height: 20),

                // ---- Emergency History ----
                Text('Recent Emergencies',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _EmergencyHistorySection(),
                const SizedBox(height: 20),

                // ---- Logout ----
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await ref.read(logoutProvider.future);
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
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
// SOS Card widget
// ---------------------------------------------------------------------------
class _SOSCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '🆘 Emergency SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Press for immediate emergency response',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.go('/home/emergency'),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency_rounded, size: 40, color: Colors.red),
                  SizedBox(height: 4),
                  Text(
                    'SOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Patient Type Banner
// ---------------------------------------------------------------------------
class _PatientTypeBanner extends StatelessWidget {
  final String patientType;
  const _PatientTypeBanner({required this.patientType});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(patientType);
    return InkWell(
      onTap: () => context.go('/home/patient-type-info'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: config['color'].withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: config['color'].withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(config['icon'], color: config['color'], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config['title'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: config['color'],
                    ),
                  ),
                  Text(
                    config['subtitle'],
                    style: TextStyle(
                      fontSize: 12,
                      color: config['color'].withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: config['color'].withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getConfig(String type) {
    switch (type) {
      case 'DEAF':
        return {
          'color': const Color(0xFF00897B),
          'icon': Icons.hearing_disabled_rounded,
          'title': 'Deaf Mode Active',
          'subtitle': 'Visual alerts, vibration & text messages enabled',
        };
      case 'BLIND':
        return {
          'color': const Color(0xFFF57C00),
          'icon': Icons.visibility_off_rounded,
          'title': 'Blind Mode Active',
          'subtitle': 'Voice guidance & audio alerts enabled',
        };
      default:
        return {
          'color': const Color(0xFF1976D2),
          'icon': Icons.person_rounded,
          'title': 'Standard Patient',
          'subtitle': 'Full feature access enabled — Tap to learn more',
        };
    }
  }
}

// ---------------------------------------------------------------------------
// Quick Actions Grid
// ---------------------------------------------------------------------------
class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.favorite_outlined,
        label: 'Medical\nProfile',
        color: Colors.pink,
        onTap: () => context.go('/home/medical-profile'),
      ),
      _QuickAction(
        icon: Icons.description_outlined,
        label: 'Medical\nReports',
        color: Colors.blue,
        onTap: () => context.go('/home/medical-reports'),
      ),
      _QuickAction(
        icon: Icons.people_outlined,
        label: 'My\nCaregivers',
        color: Colors.green,
        onTap: () => context.go('/home/caregivers'),
      ),
      _QuickAction(
        icon: Icons.person_outlined,
        label: 'My\nProfile',
        color: Colors.purple,
        onTap: () => context.go('/home/profile'),
      ),
      _QuickAction(
        icon: Icons.accessibility_new_rounded,
        label: 'How App\nHelps Me',
        color: Colors.orange,
        onTap: () => context.go('/home/patient-type-info'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: actions
          .map((a) => _buildCard(context, a))
          .toList(),
    );
  }

  Widget _buildCard(BuildContext context, _QuickAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: action.color.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(action.icon, color: action.color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: action.color.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ---------------------------------------------------------------------------
// Emergency History Section (placeholder for now)
// ---------------------------------------------------------------------------
class _EmergencyHistorySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: wire to getUserEmergenciesProvider when backend is ready
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'No past emergencies recorded',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
