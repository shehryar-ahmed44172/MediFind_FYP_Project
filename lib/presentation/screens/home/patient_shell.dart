import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/navigation/mf_role_shell.dart';

/// Patient dashboard: SOS (Home) · Messages · Medical ID · Profile.
class PatientShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const PatientShell({super.key, required this.navigationShell, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final firstName = (user?.fullName ?? '').trim().split(' ').first;

    return MfRoleShell(
      navigationShell: navigationShell,
      tabs: [
        MfShellTab(
          icon: Icons.emergency_outlined,
          selectedIcon: Icons.emergency_rounded,
          label: 'SOS',
          title: 'MediFind',
          showBrand: true,
          subtitle: firstName.isEmpty ? null : 'Hello, $firstName',
        ),
        const MfShellTab(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Messages',
          title: 'Messages',
        ),
        const MfShellTab(
          icon: Icons.medical_information_outlined,
          selectedIcon: Icons.medical_information_rounded,
          label: 'Medical ID',
          title: 'Medical ID',
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
