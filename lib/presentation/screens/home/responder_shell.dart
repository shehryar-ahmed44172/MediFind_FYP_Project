import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/navigation/mf_role_shell.dart';

/// Responder dashboard: Requests (Home) · History · Profile.
class ResponderShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const ResponderShell({super.key, required this.navigationShell, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MfRoleShell(
      navigationShell: navigationShell,
      tabs: [
        const MfShellTab(
          icon: Icons.notifications_active_outlined,
          selectedIcon: Icons.notifications_active_rounded,
          label: 'Requests',
          title: 'MediFind',
          subtitle: 'Responder · Requests',
          showBrand: true,
        ),
        const MfShellTab(
          icon: Icons.history_rounded,
          selectedIcon: Icons.history_rounded,
          label: 'History',
          title: 'Response history',
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
