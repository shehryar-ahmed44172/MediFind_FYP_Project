import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_providers.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/caregiver_connection.dart';
import '../../../core/utils/responsive.dart';

class CaregiverHomeScreen extends ConsumerStatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  ConsumerState<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends ConsumerState<CaregiverHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncPatients = ref.watch(getLinkedPatientsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: RefreshIndicator(
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
                      Text('Hello,', style: TextStyle(color: Colors.grey, fontSize: 1.8.hp)),
                      Text(user?.fullName.split(' ')[0] ?? 'Caregiver',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 3.2.hp)),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            
            // 2. Quick Actions Grid
            SliverToBoxAdapter(
              child: _buildQuickActionGrid(theme),
            ),

            // 3. Monitored Patients Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Monitoring', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (asyncPatients.hasValue && asyncPatients.value!.isNotEmpty)
                      Text('Recent Updates', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
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

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return RepaintBoundary(
                        child: _buildPatientCard(context, patients[index], theme),
                      );
                    },
                    childCount: patients.length,
                    addAutomaticKeepAlives: true,
                    addRepaintBoundaries: true,
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
    );
  }

  Widget _buildQuickActionGrid(ThemeData theme) {
    // 'push': true  → opens as a full-screen overlay above the shell (context.push)
    // 'push': false → switches tab via shell (context.go)
    final actions = [
      {'title': 'My Patients', 'icon': Icons.people_rounded, 'color': AppColors.primary, 'route': '/caregiver/my-patients', 'push': false},
      {'title': 'Live Map', 'icon': Icons.map_rounded, 'color': Colors.blue, 'route': '/caregiver/maps', 'push': false},
      {'title': 'Messages', 'icon': Icons.chat_bubble_rounded, 'color': Colors.orange, 'route': '/caregiver/chats', 'push': false},
      {'title': 'History', 'icon': Icons.history_rounded, 'color': Colors.indigo, 'route': '/caregiver/history', 'push': true},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final color = action['color'] as Color;
        return InkWell(
          onTap: () {
            final route = action['route'] as String?;
            if (route != null) {
              final shouldPush = action['push'] as bool? ?? false;
              if (shouldPush) {
                context.push(route);
              } else {
                context.go(route);
              }
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action['icon'] as IconData, color: color, size: 28),
                const SizedBox(height: 8),
                Text(action['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      },
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
            onPressed: () => context.push('/caregiver/my-patients/link-patient'),
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
