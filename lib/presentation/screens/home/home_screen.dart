import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../home/widgets/connectivity_banner.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (!isConnected) const ConnectivityBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // top bar
                    _buildHeader(theme),
                    const SizedBox(height: 24),

                    // profile summary
                    _buildMedicalProfileSnapshot(theme),
                    const SizedBox(height: 32),

                    // main sos btn
                    _buildMassiveSOSButton(theme),
                    const SizedBox(height: 24),

                    // attach report btn
                    _buildAttachReportOption(theme),
                    const SizedBox(height: 32),

                    // grid for emergency types
                    _buildEmergencyTypes(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(Icons.person_outline, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome,',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'John Doe', // TODO: Hook up to auth provider later
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            shape: BoxShape.circle,
            boxShadow: AppShadows.neumorphicOut,
          ),
          child: const Icon(Icons.notifications_none_rounded, color: Colors.black87),
        )
      ],
    );
  }

  Widget _buildMedicalProfileSnapshot(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.neumorphicOut,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medical Profile',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () => context.go('/home/medical-profile'),
                child: Row(
                  children: [
                    Text(
                      'View all ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, 
                      size: 14, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProfileStat(theme, 'Blood', 'O+', Icons.bloodtype, Colors.red),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildProfileStat(theme, 'Allergies', 'Peanuts', Icons.warning_amber_rounded, Colors.orange),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildProfileStat(theme, 'Meds', '3 Active', Icons.medication_liquid_rounded, AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(ThemeData theme, String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMassiveSOSButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => context.go('/home/emergency'),
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.scaffoldBackgroundColor,
            boxShadow: AppShadows.neumorphicOut,
          ),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF4D4D), Color(0xFFD32F2F)],
              ),
              boxShadow: AppShadows.sosMassiveGlow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fingerprint_rounded,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PRESS & HOLD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachReportOption(ThemeData theme) {
    return InkWell(
      onTap: () {
        // trigger dialog later
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attach Report dialog opened!')),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attachment_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Attach Medical Report Script',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTypes(ThemeData theme) {
    final types = [
      {'title': 'Cardiac', 'icon': Icons.favorite_border_rounded, 'color': Colors.red},
      {'title': 'Breathing', 'icon': Icons.air_rounded, 'color': AppColors.primary},
      {'title': 'Bleeding', 'icon': Icons.water_drop_outlined, 'color': Colors.redAccent},
      {'title': 'Burn', 'icon': Icons.local_fire_department_outlined, 'color': Colors.orange},
      {'title': 'Accident', 'icon': Icons.car_crash_outlined, 'color': Colors.amber},
      {'title': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Colors.grey},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Types',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            final color = type['color'] as Color;
            return InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.neumorphicOut,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(type['icon'] as IconData, color: color, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      type['title'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA3B1C6).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0, true, theme),
              _buildNavItem(Icons.content_paste_rounded, 'Reports', 1, false, theme),
              _buildNavItem(Icons.location_on_rounded, 'Alerts', 2, false, theme),
              _buildNavItem(Icons.person_rounded, 'Profile', 3, false, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isSelected, ThemeData theme) {
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 1) context.go('/home/medical-reports');
        if (index == 3) context.go('/home/profile');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : Colors.grey.shade400,
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
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
