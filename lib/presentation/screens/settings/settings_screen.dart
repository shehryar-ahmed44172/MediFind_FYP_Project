import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../../../services/location/location_service.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool showHeader;
  const SettingsScreen({super.key, this.showHeader = true});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final role = user?.role ?? 'PATIENT';
    final themeMode = ref.watch(accessibilityProvider).themeMode;
    final isDeaf = (user?.patientType?.toUpperCase() ?? '') == 'DEAF';

    final sections = <Widget>[
      // ── PATIENT ──────────────────────────────────────────────────
      if (role == 'PATIENT') ...[
        _section('Appearance & accessibility', [
          MfIconTile(
            icon: Icons.contrast_rounded,
            label: 'App theme',
            subtitle: _themeLabel(themeMode),
            onTap: _showThemeDialog,
          ),
          MfIconTile(
            icon: Icons.accessibility_new_rounded,
            label: 'Accessibility & text',
            subtitle: 'Text size, high contrast, vibration and text-only mode',
            onTap: () => context.push('/accessibility-settings'),
          ),
        ]),
        _section('Health & safety', [
          MfIconTile(
            icon: Icons.medical_information_outlined,
            label: 'Medical profile',
            subtitle: 'Blood group, allergies and conditions',
            onTap: () => context.push('/home/medical-profile'),
          ),
          MfIconTile(
            icon: Icons.people_outline_rounded,
            label: 'My caregivers',
            subtitle: 'Manage trusted caregiver accounts',
            onTap: () => context.push('/home/caregivers'),
          ),
          // Deaf patient — predefined messages
          if (isDeaf)
            MfIconTile(
              icon: Icons.chat_outlined,
              label: 'Quick phrases',
              subtitle: 'Pre-written phrases for silent SOS communication',
              onTap: () => context.push('/predefined-messages'),
            ),
        ]),
        _section('Plan', [
          MfIconTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription plans',
            subtitle: 'Upgrade your plan for premium features',
            onTap: () => context.push('/subscription-plans'),
          ),
        ]),
      ],

      // ── RESPONDER ─────────────────────────────────────────────────
      if (role == 'RESPONDER') ...[
        _section('Appearance & accessibility', [
          MfIconTile(
            icon: Icons.contrast_rounded,
            label: 'Theme & appearance',
            subtitle: _themeLabel(themeMode),
            onTap: _showThemeDialog,
          ),
          MfIconTile(
            icon: Icons.accessibility_new_rounded,
            label: 'Accessibility & voice alerts',
            subtitle: 'Text size, contrast, vibration and hands-free voice alerts',
            onTap: () => context.push('/accessibility-settings'),
          ),
        ]),
        _section('Response history', [
          MfIconTile(
            icon: Icons.history_rounded,
            label: 'Emergency logs',
            subtitle: 'Review your past emergency responses',
            onTap: () => context.go('/responder/history'),
          ),
        ]),
        _section('Plan', [
          MfIconTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription plans',
            subtitle: 'Priority dispatch and full history',
            onTap: () => context.push('/subscription-plans'),
          ),
        ]),
        _section('System tools', [
          MfIconTile(
            icon: Icons.monitor_heart_outlined,
            label: 'Diagnostics',
            subtitle: 'Socket status, push token and system monitoring',
            tone: MfTone.neutral,
            onTap: () => context.push('/diagnostics'),
          ),
        ]),
      ],

      // ── CAREGIVER ─────────────────────────────────────────────────
      if (role == 'CAREGIVER') ...[
        _section('Appearance & accessibility', [
          MfIconTile(
            icon: Icons.contrast_rounded,
            label: 'Theme & appearance',
            subtitle: _themeLabel(themeMode),
            onTap: _showThemeDialog,
          ),
          MfIconTile(
            icon: Icons.accessibility_new_rounded,
            label: 'Accessibility & text',
            subtitle: 'Text size, high contrast and vibration',
            onTap: () => context.push('/accessibility-settings'),
          ),
        ]),
        _section('Account & patients', [
          MfIconTile(
            icon: Icons.supervisor_account_outlined,
            label: 'My patients',
            subtitle: 'View and manage your linked patients',
            onTap: () => context.push('/caregiver/my-patients'),
          ),
          MfIconTile(
            icon: Icons.person_add_alt_outlined,
            label: 'Link new patient',
            subtitle: 'Connect with a new patient via email',
            onTap: () => context.push('/caregiver/my-patients/link-patient'),
          ),
        ]),
        _section('Plan', [
          MfIconTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription plans',
            subtitle: 'Upgrade your plan to monitor more patients',
            onTap: () => context.push('/subscription-plans'),
          ),
        ]),
      ],

      // ── ALL ROLES ─────────────────────────────────────────────────
      _section('Notifications', [
        MfIconTile(
          icon: Icons.notifications_none_rounded,
          label: 'Notifications',
          subtitle: 'Emergency updates and messages',
          onTap: () => showMfNotificationsSheet(context),
        ),
      ]),

      if (kDebugMode)
        _section('Testing tools', [
          MfIconTile(
            icon: Icons.location_searching_rounded,
            label: 'Simulate distance',
            subtitle: LocationService.debugLatOffset == 0 ? 'Disabled' : 'Active (500 m offset)',
            tone: MfTone.neutral,
            onTap: _toggleSimulatedDistance,
          ),
        ]),

      // Test builds only: the address this APK talks to can be changed here.
      if (AppConstants.isDevelopment)
        _section('Connection', [
          MfIconTile(
            icon: Icons.dns_outlined,
            label: 'Server address',
            subtitle: AppConstants.activeHost,
            tone: MfTone.neutral,
            onTap: () => context.push('/server-address'),
          ),
        ]),

      _section('Account', [
        MfIconTile(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          subtitle: user?.email,
          tone: MfTone.danger,
          showChevron: false,
          onTap: _confirmSignOut,
        ),
      ]),
    ];

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
      children: [
        ...sections,
        const SizedBox(height: MfSpace.xs),
        _VersionFooter(),
      ],
    );

    if (!widget.showHeader) return body;
    return MfScaffold(title: 'Settings', body: body);
  }

  Widget _section(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MfSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MfSectionTitle(title),
          MfListGroup(children: rows),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light mode';
    }
  }

  void _toggleSimulatedDistance() {
    // Toggle 500m offset (~0.005 degrees)
    if (LocationService.debugLatOffset == 0) {
      LocationService.debugLatOffset = 0.005;
      LocationService.debugLngOffset = 0.005;
    } else {
      LocationService.debugLatOffset = 0.0;
      LocationService.debugLngOffset = 0.0;
    }

    // Rebuild to update the subtitle
    setState(() {});

    showMfSnackBar(
      context,
      LocationService.debugLatOffset == 0
          ? 'Location spoofing disabled'
          : 'Location spoofed (500 m offset applied)',
      tone: MfTone.info,
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to send SOS alerts and receive updates.',
      confirmLabel: 'Sign out',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed) return;
    await ref.read(logoutProvider.future);
    if (mounted) context.go('/login');
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final currentMode = ref.watch(accessibilityProvider).themeMode;
            return AlertDialog(
              title: const Text('App theme'),
              contentPadding: const EdgeInsets.symmetric(vertical: MfSpace.sm),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _themeOption(context, ref, 'System default', Icons.brightness_auto_outlined, ThemeMode.system, currentMode),
                  _themeOption(context, ref, 'Light mode', Icons.light_mode_outlined, ThemeMode.light, currentMode),
                  _themeOption(context, ref, 'Dark mode', Icons.dark_mode_outlined, ThemeMode.dark, currentMode),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _themeOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeMode currentMode,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = mode == currentMode;
    return Semantics(
      selected: isSelected,
      child: ListTile(
        minTileHeight: MfSize.primaryButton,
        leading: Icon(icon, color: isSelected ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
        trailing: isSelected ? Icon(Icons.check_rounded, color: cs.primary) : null,
        onTap: () {
          ref.read(accessibilityProvider.notifier).setThemeMode(mode);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        children: [
          Text('MediFind Mobile App', style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: MfSpace.xxs),
          Text('Version 1.0.0 Build 44', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
