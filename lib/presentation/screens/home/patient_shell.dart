import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/app_header.dart';
import '../../theme/app_theme.dart';

class PatientShell extends ConsumerWidget {
  final Widget child;
  const PatientShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = GoRouterState.of(context);
    final path = state.uri.path;
    String? title;
    int currentIndex = 0;

    if (path.contains('/home/medical-reports')) {
      title = 'Medical Records';
      currentIndex = 1;
    } else if (path.contains('/home/medical-profile')) {
      title = 'Medical Profile';
      currentIndex = 0;
    } else if (path.contains('/home/caregivers')) {
      title = 'My Caregivers';
      currentIndex = 2;
    } else if (path.contains('/profile')) {
      title = 'User Profile';
      currentIndex = 3;
    } else if (path.contains('/settings')) {
      title = 'Settings';
      currentIndex = 4;
    } else if (path == '/home' || path == '/') {
      title = null; // Home uses logo ONLY
      currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          AppHeader(
            greetingOverride: title,
            showProfile: currentIndex != 3, // Don't show profile avatar if already on profile page
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, currentIndex),
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
              _buildNavItem(context, Icons.home_rounded, 'Home', 0, currentIndex == 0, '/home'),
              _buildNavItem(context, Icons.content_paste_rounded, 'Reports', 1, currentIndex == 1, '/home/medical-reports'),
              _buildNavItem(context, Icons.people_alt_rounded, 'Care', 2, currentIndex == 2, '/home/caregivers'),
              _buildNavItem(context, Icons.person_rounded, 'Profile', 3, currentIndex == 3, '/profile'),
              _buildNavItem(context, Icons.settings_rounded, 'Settings', 4, currentIndex == 4, '/settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index, bool isSelected, String route) {
    return InkWell(
      onTap: () => context.go(route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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
