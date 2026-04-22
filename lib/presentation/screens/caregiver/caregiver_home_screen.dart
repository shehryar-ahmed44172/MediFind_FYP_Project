import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_providers.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/caregiver_connection.dart';

// Import the various screens for tabs
import 'my_patients_screen.dart';
import 'caregiver_map_screen.dart';
import 'caregiver_history_screen.dart';
import '../profile/user_profile_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/common/app_header.dart';

class CaregiverHomeScreen extends ConsumerStatefulWidget {
  const CaregiverHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends ConsumerState<CaregiverHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _DashboardView(),
    const MyPatientsScreen(),
    const CaregiverMapScreen(),
    const CaregiverHistoryScreen(),
    const SettingsScreen(showHeader: false),
    const UserProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomNav(theme),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0, theme),
              _buildNavItem(Icons.people_rounded, 'Patients', 1, theme),
              _buildNavItem(Icons.map_rounded, 'Maps', 2, theme),
              _buildNavItem(Icons.history_rounded, 'History', 3, theme),
              _buildNavItem(Icons.settings_rounded, 'Settings', 4, theme),
              _buildNavItem(Icons.person_rounded, 'Profile', 5, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.white : Colors.white.withOpacity(0.45);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                color: color, 
                size: isSelected ? 22 : 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncPatients = ref.watch(getLinkedPatientsProvider);
    final asyncUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          const AppHeader(showLogout: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(getLinkedPatientsProvider.future),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Greeting
                  SliverToBoxAdapter(
                    child: ref.watch(currentUserProvider).when(
                      data: (user) => Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello,',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Text(
                              user?.fullName.split(' ')[0] ?? 'Caregiver',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  // 2. Stats
                  SliverToBoxAdapter(
                    child: asyncPatients.when(
                      data: (patients) => _buildStatsRow(context, patients, theme),
                      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),

              // 3. Monitored Patients Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monitored Patients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (asyncPatients.hasValue && asyncPatients.value!.isNotEmpty)
                        Text('Active Previews', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
              ),

              // 4. Patients List
              asyncPatients.when(
                data: (patients) {
                  if (patients.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context, theme),
                    );
                  }

                  final sortedPatients = List<CaregiverConnection>.from(patients)
                    ..sort((a, b) {
                      if (a.hasActiveEmergency == true && b.hasActiveEmergency != true) return -1;
                      if (a.hasActiveEmergency != true && b.hasActiveEmergency == true) return 1;
                      return 0;
                    });

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPatientCard(context, sortedPatients[index], theme),
                      childCount: sortedPatients.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red)))),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
          ],
        ),
    );
  }

  Widget _buildStatsRow(BuildContext context, List<CaregiverConnection> patients, ThemeData theme) {
    final activeAlerts = patients.where((p) => p.hasActiveEmergency == true).length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(context, 'Total Monitored', patients.length.toString(), Icons.people_rounded, AppColors.primary, theme),
          const SizedBox(width: 20),
          _buildStatCard(context, 'Active Alerts', activeAlerts.toString(), Icons.warning_amber_rounded, activeAlerts > 0 ? Colors.red : Colors.green, theme),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.neumorphicOut,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(
              title, 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w600, 
                color: Colors.grey.shade600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, CaregiverConnection patient, ThemeData theme) {
    final bool isActive = patient.hasActiveEmergency == true;
    final Color statusColor = patient.status == 'PENDING' ? Colors.orange : (isActive ? Colors.red : Colors.green);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isActive ? AppShadows.sosMassiveGlow : AppShadows.neumorphicOut,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isActive && patient.activeEmergencyId != null) {
                context.push('/caregiver/tracking/${patient.activeEmergencyId}');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: statusColor.withOpacity(0.12),
                        child: Icon(Icons.person_rounded, size: 40, color: statusColor),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.patientName ?? patient.patientEmail ?? 'Unknown Patient',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(patient.relationship, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(width: 8),
                            if (patient.bloodType != null) ...[
                              Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade400)),
                              const SizedBox(width: 8),
                              Text('Blood: ${patient.bloodType}', style: TextStyle(color: Colors.red.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    const Icon(Icons.emergency_share_rounded, color: Colors.red, size: 28)
                  else
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              shape: BoxShape.circle,
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text('No patients linked yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Link a patient to start monitoring their safety status in real-time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/caregiver/link-patient'),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Link Now'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
