import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../widgets/common/app_header.dart';
import '../../../services/location/location_service.dart';

class SettingsScreen extends ConsumerWidget {
  final bool showHeader;
  const SettingsScreen({super.key, this.showHeader = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final role = user?.role ?? 'PATIENT';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          if (showHeader) const AppHeader(greetingOverride: 'Settings', canPop: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
  
                // ── PATIENT ──────────────────────────────────────────────────
                if (role == 'PATIENT') ...[
                  _buildSectionHeader(theme, 'Appearance'),
                  _buildSettingsTile(
                    context,
                    Icons.palette_rounded,
                    'App Theme',
                    'Switch between Light, Dark and System modes',
                    const Color(0xFF6366F1),
                    theme,
                    () => _showThemeDialog(context, ref),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsTile(
                    context,
                    Icons.format_size_rounded,
                    'Text & Appearance',
                    'Adjust font sizes and visual elements',
                    const Color(0xFF8B5CF6),
                    theme,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Appearance settings coming soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, 'Health & Security'),
                  _buildSettingsTile(
                    context,
                    Icons.medical_services_rounded,
                    'Medical Profile',
                    'Update blood group, allergies & conditions',
                    const Color(0xFFEF4444),
                    theme,
                    () => context.push('/home/medical-profile'),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsTile(
                    context,
                    Icons.people_alt_rounded,
                    'My Caregivers',
                    'Manage trusted caregiver accounts',
                    const Color(0xFFF59E0B),
                    theme,
                    () => context.go('/home/caregivers'),
                  ),
                  const SizedBox(height: 16),
                  // Deaf Patient — predefined messages
                  if ((user?.patientType?.toUpperCase() ?? '') == 'DEAF') ...[
                    _buildSettingsTile(
                      context,
                      Icons.hearing_disabled_rounded,
                      'Quick Phrases',
                      'Set up pre-written phrases for silent SOS communication',
                      const Color(0xFF2496A7),
                      theme,
                      () => context.push('/predefined-messages'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildSettingsTile(
                    context,
                    Icons.card_membership_rounded,
                    'Subscription Plans',
                    'Upgrade your plan for premium features',
                    const Color(0xFF10B981),
                    theme,
                    () => context.push('/subscription-plans'),
                  ),
                ],
  
                // ── RESPONDER ─────────────────────────────────────────────────
                if (role == 'RESPONDER') ...[
                  _buildSectionHeader(theme, 'App Experience'),
                  _buildSettingsTile(
                    context,
                    Icons.palette_rounded,
                    'Theme & Appearance',
                    'Customize the look and feel of your dashboard',
                    const Color(0xFF6366F1),
                    theme,
                    () => _showThemeDialog(context, ref),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, 'Response History'),
                  _buildSettingsTile(
                    context,
                    Icons.history_rounded,
                    'Emergency Logs',
                    'Review your past emergency responses',
                    const Color(0xFF4F46E5),
                    theme,
                    () => context.go('/responder/history'),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, 'System Tools'),
                  _buildSettingsTile(
                    context,
                    Icons.terminal_rounded,
                    'Diagnostics',
                    'Socket status, FCM & system monitoring',
                    const Color(0xFF64748B),
                    theme,
                    () => context.go('/diagnostics'),
                  ),
                ],
  
                // ── CAREGIVER ─────────────────────────────────────────────────
                if (role == 'CAREGIVER') ...[
                  _buildSectionHeader(theme, 'App Experience'),
                  _buildSettingsTile(
                    context,
                    Icons.palette_rounded,
                    'Theme & Appearance',
                    'Customize colors and layout preferences',
                    const Color(0xFF6366F1),
                    theme,
                    () => _showThemeDialog(context, ref),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, 'Account & Patients'),
                  _buildSettingsTile(
                    context,
                    Icons.supervisor_account_rounded,
                    'My Patients',
                    'View and manage your linked patients',
                    const Color(0xFF8B5CF6),
                    theme,
                    () => context.go('/caregiver/my-patients'),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsTile(
                    context,
                    Icons.person_add_rounded,
                    'Link New Patient',
                    'Connect with a new patient via email',
                    const Color(0xFFEC4899),
                    theme,
                    () => context.go('/caregiver/my-patients/link-patient'),
                  ),
                ],
  
                const SizedBox(height: 32),
                _buildSectionHeader(theme, 'Testing Tools'),
                _buildSettingsTile(
                  context,
                  Icons.location_searching_rounded,
                  'Simulate Distance',
                  LocationService.debugLatOffset == 0 ? 'Disabled' : 'Active (500m Offset)',
                  Colors.teal,
                  theme,
                  () {
                    // Toggle 500m offset (~0.005 degrees)
                    if (LocationService.debugLatOffset == 0) {
                      LocationService.debugLatOffset = 0.005;
                      LocationService.debugLngOffset = 0.005;
                    } else {
                      LocationService.debugLatOffset = 0.0;
                      LocationService.debugLngOffset = 0.0;
                    }
                    
                    // Force rebuild of settings screen to update subtitle
                    (context as Element).markNeedsBuild();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocationService.debugLatOffset == 0 
                          ? 'Location spoofing disabled' 
                          : 'Location spoofed (500m offset applied)'),
                        backgroundColor: Colors.teal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),
                
                // Premium Logout Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(logoutProvider.future);
                      if (context.mounted) context.go('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: Colors.red.withOpacity(0.2)),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Log Out',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'MediFind Mobile App',
                        style: TextStyle(
                          color: Colors.grey.shade400, 
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0 Build 44',
                        style: TextStyle(color: Colors.grey.shade300, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final currentMode = ref.watch(accessibilityProvider).themeMode;
        return AlertDialog(
          title: const Text('Select App Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(context, ref, 'System Default', Icons.brightness_auto, ThemeMode.system, currentMode),
              _buildThemeOption(context, ref, 'Light Mode', Icons.light_mode_rounded, ThemeMode.light, currentMode),
              _buildThemeOption(context, ref, 'Dark Mode', Icons.dark_mode_rounded, ThemeMode.dark, currentMode),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(BuildContext context, WidgetRef ref, String label, IconData icon, ThemeMode mode, ThemeMode currentMode) {
    final isSelected = mode == currentMode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () {
        ref.read(accessibilityProvider.notifier).setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    ThemeData theme,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title, 
          style: const TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            letterSpacing: -0.2,
          )
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle, 
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ),
      ),
    );
  }
}
