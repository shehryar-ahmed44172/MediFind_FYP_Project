import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';
import '../../widgets/navigation/app_drawer.dart';

class CaregiverShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const CaregiverShell({super.key, required this.navigationShell, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    String? title;
    final currentIndex = navigationShell.currentIndex;

    // Map index to titles for the header
    switch (currentIndex) {
      case 0: title = 'Dashboard'; break;
      case 1: title = 'My Patients'; break;
      case 2: title = 'Patient Tracking'; break;
      case 3: title = 'Profile'; break;
      case 4: title = 'Messages'; break;
      default: title = null;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      endDrawer: const AppDrawer(),
      body: Column(
        children: [
          AppHeader(
            greetingOverride: title,
            showLogout: false,
            showProfile: currentIndex != 3,
            canPop: state.uri.pathSegments.length > 2, 
          ),
          Expanded(
            child: navigationShell,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => navigationShell.goBranch(index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Patients'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
        ],
      ),
    );
  }
}
