import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';
import '../../widgets/navigation/app_drawer.dart';

class ResponderShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const ResponderShell({super.key, required this.navigationShell, required this.state});

  @override
  ConsumerState<ResponderShell> createState() => _ResponderShellState();
}

class _ResponderShellState extends ConsumerState<ResponderShell> {
  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(child: Text('Exit MediFind?')),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      case 1: title = 'History'; break;
      case 2: title = 'Profile'; break;
      case 3: title = 'Messages'; break;
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
              showProfile: currentIndex != 2,
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
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
          ],
        ),
      ),
    );
  }
}
