import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/router.dart';
import '../../../services/location/responder_location_tracker.dart';
import '../../providers/auth_provider.dart';
import '../design_system/design_system.dart';

/// One destination in the [AppDrawer].
class _DrawerItem {
  final IconData icon;
  final String label;
  final String route;

  /// Tab roots switch branches with go(); other pages are pushed on top.
  final bool isTab;
  const _DrawerItem(this.icon, this.label, this.route, {this.isTab = false});
}

/// Unified sidebar navigation (SRS FR8.1) shared by every role shell.
///
/// Items are role-specific; the bottom navigation bar keeps the most used
/// destinations one tap away while the drawer lists everything.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static List<({String? title, List<_DrawerItem> items})> _sectionsFor(String role, bool isDeaf) {
    switch (role) {
      case 'CAREGIVER':
        return [
          (title: null, items: const [
            _DrawerItem(Icons.groups_outlined, 'My patients', '/caregiver', isTab: true),
            _DrawerItem(Icons.map_outlined, 'Live map', '/caregiver/maps', isTab: true),
            _DrawerItem(Icons.chat_bubble_outline_rounded, 'Messages', '/caregiver/chats', isTab: true),
            _DrawerItem(Icons.person_outline_rounded, 'Profile', '/caregiver/profile', isTab: true),
          ]),
          (title: 'Care', items: const [
            _DrawerItem(Icons.history_rounded, 'Emergency history', '/caregiver/history'),
            _DrawerItem(Icons.person_add_alt_1_outlined, 'Link a patient', '/caregiver/my-patients/link-patient'),
          ]),
        ];
      case 'RESPONDER':
        return [
          (title: null, items: const [
            _DrawerItem(Icons.notifications_active_outlined, 'Requests', '/responder', isTab: true),
            _DrawerItem(Icons.history_rounded, 'Response history', '/responder/history', isTab: true),
            _DrawerItem(Icons.person_outline_rounded, 'Profile', '/responder/profile', isTab: true),
          ]),
        ];
      default:
        return [
          (title: null, items: const [
            _DrawerItem(Icons.emergency_outlined, 'SOS home', '/home', isTab: true),
            _DrawerItem(Icons.chat_bubble_outline_rounded, 'Messages', '/chats', isTab: true),
            _DrawerItem(Icons.medical_information_outlined, 'Medical ID', '/medical-id', isTab: true),
            _DrawerItem(Icons.person_outline_rounded, 'Profile', '/profile', isTab: true),
          ]),
          (title: 'Health', items: const [
            _DrawerItem(Icons.monitor_heart_outlined, 'Medical profile', '/home/medical-profile'),
            _DrawerItem(Icons.content_paste_rounded, 'Medical reports', '/home/medical-reports'),
            _DrawerItem(Icons.contacts_outlined, 'Emergency contacts', '/home/emergency-contacts'),
            _DrawerItem(Icons.people_outline_rounded, 'My caregivers', '/home/caregivers'),
          ]),
          (title: 'Communication', items: [
            if (isDeaf) const _DrawerItem(Icons.quickreply_outlined, 'Quick phrases', '/predefined-messages'),
            if (isDeaf) const _DrawerItem(Icons.badge_outlined, 'Show to people nearby', '/home/show-card'),
            const _DrawerItem(Icons.hearing_disabled_outlined, 'Deaf & hearing modes', '/home/patient-type-info'),
          ]),
        ];
    }
  }

  static const _common = [
    _DrawerItem(Icons.settings_accessibility_rounded, 'Accessibility', '/accessibility-settings'),
    _DrawerItem(Icons.workspace_premium_outlined, 'Subscription plans', '/subscription-plans'),
    _DrawerItem(Icons.settings_outlined, 'Settings', '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final role = (user?.role ?? 'PATIENT').toUpperCase();
    final isDeaf = role == 'PATIENT' && (user?.patientType ?? '').toUpperCase() == 'DEAF';
    final location = GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path ?? '';

    final roleLabel = switch (role) {
      'CAREGIVER' => 'Caregiver',
      'RESPONDER' => 'Emergency responder',
      _ => isDeaf ? 'Patient · Deaf mode' : 'Patient',
    };

    final sections = [
      ..._sectionsFor(role, isDeaf),
      (title: 'App', items: _common),
    ];

    return NavigationDrawer(
      backgroundColor: cs.surface,
      selectedIndex: null,
      children: [
        // ── Brand + account header ───────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.md, MfSpace.md, 0),
            child: Row(
              children: [
                Image.asset('assets/logos/medifind_mark.png', width: 28, height: 28, excludeFromSemantics: true),
                const SizedBox(width: MfSpace.xs),
                Text('MediFind', style: text.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.sm, MfSpace.md, MfSpace.sm),
            child: Row(
              children: [
                MfAvatar(imageUrl: user?.profileImageUrl, name: user?.fullName, size: 52),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'MediFind user',
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(roleLabel, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                MfIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close menu',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: MfSpace.xs),

        for (final section in sections) ...[
          if (section.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(MfSpace.lg, MfSpace.sm, MfSpace.md, MfSpace.xxs),
              child: Semantics(
                header: true,
                child: Text(section.title!, style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ),
          for (final item in section.items)
            _DrawerTile(
              item: item,
              selected: item.isTab
                  ? (location == item.route)
                  : location.startsWith(item.route),
              onTap: () {
                Navigator.pop(context);
                if (item.isTab) {
                  context.go(item.route);
                } else {
                  context.push(item.route);
                }
              },
            ),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.xs),
          child: Divider(height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm),
          child: ListTile(
            minTileHeight: MfSize.minTouch + MfSpace.xs,
            shape: const RoundedRectangleBorder(borderRadius: MfRadius.mdAll),
            leading: Icon(Icons.logout_rounded, color: MfColors.sos(context)),
            title: Text('Sign out', style: text.titleSmall?.copyWith(color: MfColors.sos(context))),
            onTap: () => _handleLogout(context, ref),
          ),
        ),
        const SizedBox(height: MfSpace.md),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showMfConfirmDialog(
      context,
      title: 'Sign out',
      message: 'Are you sure you want to sign out of MediFind?',
      confirmLabel: 'Sign out',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!ok || !context.mounted) return;

    try {
      // Same sequence as the profile screen: clear tokens, force the auth
      // state to logged-out synchronously, then invalidate derived providers.
      final authRepo = await ref.read(authRepositoryProvider.future);
      await authRepo.logout();
      ref.read(authStateProvider.notifier).forceLoggedOut();
      ref.invalidate(currentUserIdProvider);
      ref.invalidate(currentUserRoleProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(responderLocationTrackerProvider);

      if (!context.mounted) return;
      AppRouter.skipNextRedirect();
      context.go('/login');
    } catch (e) {
      if (context.mounted) {
        showMfSnackBar(context, 'Sign out failed. Please try again.', tone: MfTone.danger);
      }
    }
  }
}

class _DrawerTile extends StatelessWidget {
  final _DrawerItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = MfColors.tone(context, MfTone.primary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm, vertical: 1),
      child: ListTile(
        minTileHeight: MfSize.minTouch + MfSpace.xs,
        selected: selected,
        selectedTileColor: t.container,
        selectedColor: t.foreground,
        iconColor: cs.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: MfRadius.mdAll),
        leading: Icon(item.icon),
        title: Text(item.label, style: text.titleSmall?.copyWith(color: selected ? t.foreground : null)),
        trailing: item.isTab ? null : Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
