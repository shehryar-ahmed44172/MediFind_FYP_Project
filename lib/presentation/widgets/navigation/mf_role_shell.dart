import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import 'app_drawer.dart';

/// One bottom-navigation destination of a role shell.
class MfShellTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Header title shown while this tab is active.
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Show the MediFind logo mark in the header (the role's home tab).
  final bool showBrand;

  const MfShellTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBrand = false,
  });
}

/// Shared shell for patient / caregiver / responder dashboards:
/// one [MfHeader] with a menu button opening the [AppDrawer], labeled
/// [NavigationBar], back-to-first-tab and exit
/// confirmation on system back.
class MfRoleShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<MfShellTab> tabs;

  /// Optional widget rendered between header and tab content (e.g. banners).
  final Widget? topBanner;

  const MfRoleShell({
    super.key,
    required this.navigationShell,
    required this.tabs,
    this.topBanner,
  });

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex.clamp(0, tabs.length - 1);
    final tab = tabs[index];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0, initialLocation: true);
          return;
        }
        final exit = await showMfConfirmDialog(
          context,
          title: 'Exit MediFind?',
          message: 'You will stay signed in and can return at any time.',
          confirmLabel: 'Exit',
          cancelLabel: 'Stay',
        );
        if (exit) SystemNavigator.pop();
      },
      child: Scaffold(
        // Unified sidebar (SRS FR8.1) alongside the bottom tabs.
        drawer: const AppDrawer(),
        appBar: MfHeader(
          title: tab.title,
          subtitle: tab.subtitle,
          showBrand: tab.showBrand,
          showBack: false,
          leading: Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Open menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          actions: [...tab.actions, const MfNotificationsButton()],
        ),
        body: Column(
          children: [
            if (topBanner != null) topBanner!,
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: t.label,
                  tooltip: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
