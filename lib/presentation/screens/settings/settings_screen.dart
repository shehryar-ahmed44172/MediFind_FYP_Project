import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_header.dart';

class SettingsScreen extends ConsumerWidget {
  final bool showHeader;
  const SettingsScreen({Key? key, this.showHeader = true}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final role = user?.role ?? 'PATIENT';

    return Column(
      children: [
        if (showHeader) AppHeader(greetingOverride: 'Settings'),
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
                  () {
                    // Placeholder for theme selection
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Theme settings coming soon!')),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSettingsTile(
                  context,
                  Icons.format_size_rounded,
                  'Text & Appearance',
                  'Adjust font sizes and visual elements',
                  const Color(0xFF8B5CF6),
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
                  () => context.push('/home/medical-profile'),
                ),
                const SizedBox(height: 16),
                _buildSettingsTile(
                  context,
                  Icons.people_alt_rounded,
                  'My Caregivers',
                  'Manage trusted caregiver accounts',
                  const Color(0xFFF59E0B),
                  () => context.push('/home/caregivers'),
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
                  () {},
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(theme, 'Response History'),
                _buildSettingsTile(
                  context,
                  Icons.history_rounded,
                  'Emergency Logs',
                  'Review your past emergency responses',
                  const Color(0xFF4F46E5),
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
                  () => context.push('/diagnostics'),
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
                  () {},
                ),
                const SizedBox(height: 32),
                _buildSectionHeader(theme, 'Account & Patients'),
                _buildSettingsTile(
                  context,
                  Icons.supervisor_account_rounded,
                  'My Patients',
                  'View and manage your linked patients',
                  const Color(0xFF8B5CF6),
                  () => context.go('/caregiver/my-patients'),
                ),
                const SizedBox(height: 16),
                _buildSettingsTile(
                  context,
                  Icons.person_add_rounded,
                  'Link New Patient',
                  'Connect with a new patient via email',
                  const Color(0xFFEC4899),
                  () => context.go('/caregiver/link-patient'),
                ),
              ],

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
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.red.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, size: 20),
                      const SizedBox(width: 12),
                      const Text(
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
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
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
            color: Colors.grey.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ),
      ),
    );
  }
}
