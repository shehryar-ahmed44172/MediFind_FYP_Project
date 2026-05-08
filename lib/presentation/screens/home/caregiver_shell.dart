import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';
import '../../widgets/navigation/app_drawer.dart';

class CaregiverShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const CaregiverShell({super.key, required this.navigationShell, required this.state});

  @override
  ConsumerState<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends ConsumerState<CaregiverShell> {
  Future<bool?> _showExitDialog() {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: theme.colorScheme.tertiary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Exit MediFind?')),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit? Your session will remain active and you can return anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = widget.navigationShell.currentIndex;

    String? title;
    switch (currentIndex) {
      case 0: title = 'Dashboard'; break;
      case 1: title = 'My Patients'; break;
      case 2: title = 'Patient Tracking'; break;
      case 3: title = 'Profile'; break;
      case 4: title = 'Messages'; break;
      default: title = null;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (currentIndex != 0) {
          widget.navigationShell.goBranch(0, initialLocation: true);
          return;
        }
        final shouldExit = await _showExitDialog();
        if (shouldExit == true && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        endDrawer: const AppDrawer(),
        body: Column(
          children: [
            AppHeader(
              greetingOverride: title,
              showLogout: false,
              showProfile: currentIndex != 3,
              canPop: currentIndex != 0 || widget.state.uri.pathSegments.length > 1,
            ),
            Expanded(
              child: widget.navigationShell,
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => widget.navigationShell.goBranch(index),
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Patients'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
          ],
        ),
      ),
    );
  }
}
