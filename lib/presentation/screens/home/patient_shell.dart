import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';
import '../../widgets/navigation/app_drawer.dart';

class PatientShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const PatientShell({super.key, required this.navigationShell, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    String? title;
    final location = state.matchedLocation.toLowerCase();
    final currentIndex = navigationShell.currentIndex;
    
    // Map index to titles for the header
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

    final isEmergencyRoute = location.contains('emergency') || 
                             location.contains('sos') || 
                             location.contains('tracking');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      endDrawer: const AppDrawer(),
      body: Column(
        children: [
          if (!isEmergencyRoute)
            AppHeader(
              greetingOverride: title,
              showLogout: false,
              showProfile: currentIndex != 3,
              canPop: currentIndex == 0 ? state.uri.pathSegments.length > 1 : state.uri.pathSegments.length > 2,
            ),
          Expanded(
            child: navigationShell,
          ),
        ],
      ),
      bottomNavigationBar: !isEmergencyRoute ? BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => navigationShell.goBranch(index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Records'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Caregivers'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
        ],
      ) : null,
    );
  }
}
