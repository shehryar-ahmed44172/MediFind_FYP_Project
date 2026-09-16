import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/navigation/mf_role_shell.dart';

/// Caregiver dashboard: Patients (Home) · Live Map · Messages · Profile.
class CaregiverShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const CaregiverShell({super.key, required this.navigationShell, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MfRoleShell(
      navigationShell: navigationShell,
      tabs: [
        MfShellTab(
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          label: 'Patients',
          title: 'MediFind',
          subtitle: 'Caregiver · My patients',
          showBrand: true,
          actions: [
            IconButton(
              tooltip: 'Emergency history',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => context.push('/caregiver/history'),
            ),
          ],
        ),
        const MfShellTab(
          icon: Icons.map_outlined,
          selectedIcon: Icons.map_rounded,
          label: 'Live map',
          title: 'Live map',
        ),
        const MfShellTab(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Messages',
          title: 'Messages',
        ),
        MfShellTab(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Profile',
          title: 'Profile',
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ],
    );
  }
}
