import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';
import '../../widgets/navigation/app_drawer.dart';

class PatientShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const PatientShell({super.key, required this.navigationShell, required this.state});

  @override
  ConsumerState<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends ConsumerState<PatientShell> {
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
    final location = widget.state.matchedLocation.toLowerCase();

    String? title;
    switch (currentIndex) {
      case 0:
        if (location.contains('emergency-contacts')) {
          title = 'Emergency Contacts';
        } else if (location.contains('medical-profile')) {
          title = 'Medical Profile';
        } else {
          title = null;
        }
        break;
      case 1: title = 'Medical Records'; break;
      case 2: title = 'My Caregivers'; break;
      case 3: title = 'User Profile'; break;
      case 4: title = 'Messages'; break;
      default: title = null;
    }

    final isEmergencyRoute = (location.contains('emergency') ||
            location.contains('sos') ||
            location.contains('tracking')) &&
        !location.contains('contacts');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // If not on the home tab, go back to it
        if (currentIndex != 0) {
          widget.navigationShell.goBranch(0, initialLocation: true);
          return;
        }
        // On home tab — confirm exit
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
            if (!isEmergencyRoute)
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
        bottomNavigationBar: !isEmergencyRoute
            ? BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (index) => widget.navigationShell.goBranch(index),
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Records'),
                  BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Caregivers'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
                  BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
                ],
              )
            : null,
      ),
    );
  }
}
