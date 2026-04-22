import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/caregiver_providers.dart';
import '../../../domain/entities/caregiver_connection.dart';
import '../../widgets/common/app_header.dart';

class CaregiverMapScreen extends ConsumerWidget {
  const CaregiverMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncPatients = ref.watch(getLinkedPatientsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          AppHeader(greetingOverride: 'Patient Locations'),
          Expanded(
            child: asyncPatients.when(
              data: (patients) {
                if (patients.isEmpty) {
                  return _buildEmptyState(context, theme);
                }
                return _buildMapLayout(context, patients, theme);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLayout(BuildContext context, List<CaregiverConnection> patients, ThemeData theme) {
    return Column(
      children: [
        // Premium Map View Header
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.neumorphicIn,
            ),
            child: Stack(
              children: [
                // Simulated Map Background
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Opacity(
                      opacity: 0.1,
                      child: Image.network(
                        'https://api.mapbox.com/styles/v1/mapbox/light-v10/static/-122.4241,37.78,14.25,0,60/600x600?access_token=placeholder',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
                // Map Icon and Message
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_rounded, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'Live Location Monitoring',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitoring ${patients.length} linked patients',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Interactive Legend
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text('Active', style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // List of Patients with Location Details
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, -10))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text('Patient Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: patients.length,
                    itemBuilder: (context, index) => _buildLocationCard(context, patients[index], theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(BuildContext context, CaregiverConnection patient, ThemeData theme) {
    final bool isActive = patient.hasActiveEmergency == true;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive ? AppShadows.sosMassiveGlow : AppShadows.neumorphicOut,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: (isActive ? Colors.red : AppColors.primary).withOpacity(0.1),
            child: Icon(Icons.person, color: isActive ? Colors.red : AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.patientName ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.pin_drop_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'EMERGENCY ACTIVE' : 'Last update: Just now',
                      style: TextStyle(
                        color: isActive ? Colors.red : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('TRACK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            )
          else
            const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No Locations Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Link a patient to start monitoring them.'),
        ],
      ),
    );
  }
}
