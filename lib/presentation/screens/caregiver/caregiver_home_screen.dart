import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/caregiver_providers.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/caregiver_connection.dart';

class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    final asyncPatients = ref.watch(getLinkedPatientsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.favorite_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Caregiver Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Link New Patient',
            onPressed: () {
              context.go('/caregiver/link-patient');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(logoutProvider.future);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: asyncPatients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error loading patients: $error', style: const TextStyle(color: Colors.red)),
        ),
        data: (linkedPatients) {
          if (linkedPatients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No patients linked to your account',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 12),
                  const Text(
                    'Link a patient by tapping the Add icon above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/caregiver/link-patient'),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Link Patient'),
                  ),
                ],
              ),
            );
          }

          // Segregate into active alerts and normal statuses
          final activeAlerts = linkedPatients.where((p) => p.hasActiveEmergency == true).toList();
          
          return CustomScrollView(
            slivers: [
              // Dashboard Stats summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildStatCard(context, 'Total Patients', linkedPatients.length.toString(), Icons.people, AppColors.primary),
                      const SizedBox(width: 16),
                      _buildStatCard(context, 'Active Alerts', activeAlerts.length.toString(), Icons.warning_amber_rounded, activeAlerts.isEmpty ? Colors.green : Colors.red),
                    ],
                  ),
                ),
              ),
              
              if (activeAlerts.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('🚨 Active Emergencies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildPatientCard(context, activeAlerts[i], true),
                    childCount: activeAlerts.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Linked Patients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final patient = linkedPatients[i];
                    if (patient.hasActiveEmergency == true) return const SizedBox.shrink(); // Handled above
                    return _buildPatientCard(context, patient, false);
                  },
                  childCount: linkedPatients.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.neumorphicOut,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, CaregiverConnection patient, bool isActiveAlert) {
    final theme = Theme.of(context);
    
    // Status text based on pending/accepted state
    String statusText = patient.status == 'PENDING' ? 'Invitation Pending' : (isActiveAlert ? '🆘 ACTIVE EMERGENCY' : 'Safe');
    Color statusColor = patient.status == 'PENDING' ? Colors.orange : (isActiveAlert ? Colors.red : Colors.green);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActiveAlert ? AppShadows.sosMassiveGlow : AppShadows.neumorphicOut,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Text(patient.patientName ?? patient.patientEmail ?? 'Patient', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildSmallInfoChip(Icons.family_restroom, patient.relationship, Colors.blue),
                const SizedBox(width: 8),
                if (patient.patientAge != null)
                  _buildSmallInfoChip(Icons.cake, '${patient.patientAge} yrs', Colors.purple),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (patient.bloodType != null)
                   _buildSmallInfoChip(Icons.bloodtype, 'Blood: ${patient.bloodType}', Colors.red),
                const SizedBox(width: 8),
                Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: isActiveAlert && patient.activeEmergencyId != null
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => context.go(
                  '/caregiver/tracking/${patient.activeEmergencyId}',
                ),
                child: const Text('Track', style: TextStyle(color: Colors.white)),
              )
            : IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  // Show details
                },
              ),
      ),
    );
  }

  Widget _buildSmallInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

