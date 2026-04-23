import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';

class ResponderShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final GoRouterState state;
  const ResponderShell({Key? key, required this.navigationShell, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    String? title;
    final currentIndex = navigationShell.currentIndex;

    // Map index to titles for the header
    switch (currentIndex) {
      case 1: title = 'Response History'; break;
      case 2: title = 'Settings'; break;
      case 3: title = 'User Profile'; break;
      default: title = null;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          AppHeader(
            greetingOverride: title,
            showProfile: currentIndex != 3,
            canPop: state.uri.pathSegments.length > 2,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, Icons.home_rounded, 'Dashboard', 0, currentIndex == 0),
              _buildNavItem(context, Icons.history_rounded, 'History', 1, currentIndex == 1),
              _buildNavItem(context, Icons.settings_rounded, 'Settings', 2, currentIndex == 2),
              _buildNavItem(context, Icons.person_rounded, 'Profile', 3, currentIndex == 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index, bool isSelected) {
    final color = isSelected ? Colors.white : Colors.white.withOpacity(0.45);

    return InkWell(
      onTap: () => _onTap(context, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
