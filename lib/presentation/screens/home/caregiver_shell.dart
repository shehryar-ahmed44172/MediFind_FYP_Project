import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';
import '../../widgets/navigation/app_drawer.dart';

class CaregiverShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const CaregiverShell({Key? key, required this.navigationShell, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    String? title;
    final currentIndex = navigationShell.currentIndex;

    // Map index to titles for the header
    switch (currentIndex) {
      case 1: title = 'My Patients'; break;
      case 2: title = 'Patient Tracking'; break;
      case 3: title = 'Response History'; break;
      case 4: title = 'Settings'; break;
      case 5: title = 'User Profile'; break;
      case 6: title = 'Messages'; break;
      default: title = null;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      endDrawer: AppDrawer(),
      body: Column(
        children: [
          AppHeader(
            greetingOverride: title,
            showProfile: currentIndex != 5,
            canPop: state.uri.pathSegments.length > 2, // Caregiver routes are like /caregiver/map
          ),
          Expanded(
            child: navigationShell,
          ),
        ],
      ),
    );
  }
}
