import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';

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
      default: title = null;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
      bottomNavigationBar: _buildBottomNav(context, currentIndex),
    );
  }

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, Icons.home_rounded, 'Home', 0, currentIndex == 0),
              _buildNavItem(context, Icons.people_rounded, 'Patients', 1, currentIndex == 1),
              _buildNavItem(context, Icons.map_rounded, 'Maps', 2, currentIndex == 2),
              _buildNavItem(context, Icons.history_rounded, 'History', 3, currentIndex == 3),
              _buildNavItem(context, Icons.settings_rounded, 'Settings', 4, currentIndex == 4),
              _buildNavItem(context, Icons.person_rounded, 'Profile', 5, currentIndex == 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index, bool isSelected) {
    final color = isSelected ? Colors.white : Colors.white.withOpacity(0.45);
    
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(context, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: isSelected ? 22 : 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
