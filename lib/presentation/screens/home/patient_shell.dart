import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';
import '../../widgets/navigation/app_drawer.dart';

class PatientShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const PatientShell({Key? key, required this.navigationShell, required this.state}) : super(key: key);

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
      case 4: title = 'Settings'; break;
      case 5: title = 'Messages'; break;
      default: title = null;
    }

    final isEmergencyRoute = location.contains('emergency') || 
                             location.contains('sos') || 
                             location.contains('tracking');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      endDrawer: AppDrawer(),
      body: Column(
        children: [
          if (!isEmergencyRoute)
            AppHeader(
              greetingOverride: title,
              showProfile: currentIndex != 3,
              canPop: currentIndex == 0 ? state.uri.pathSegments.length > 1 : state.uri.pathSegments.length > 2,
            ),
          Expanded(
            child: navigationShell,
          ),
        ],
      ),
    );
  }
}
