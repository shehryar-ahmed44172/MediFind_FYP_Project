import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/caregiver_providers.dart';
import '../../widgets/common/app_header.dart';

class CaregiverHistoryScreen extends ConsumerWidget {
  const CaregiverHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncPatients = ref.watch(getLinkedPatientsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          AppHeader(greetingOverride: 'Alert History'),
          Expanded(
            child: asyncPatients.when(
              data: (patients) {
                if (patients.isEmpty) {
                  return _buildEmptyState(context, theme);
                }
                return _buildHistoryFeed(context, theme);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFeed(BuildContext context, ThemeData theme) {
    // Simulated combined history of emergencies and medical reports
    final historyItems = [
      {
        'type': 'EMERGENCY',
        'patient': 'Muhammad Sabir',
        'title': 'SOS: Medical Emergency',
        'time': '2 hours ago',
        'status': 'RESOLVED',
        'icon': Icons.emergency_rounded,
        'color': Colors.red,
      },
      {
        'type': 'REPORT',
        'patient': 'Muhammad Sabir',
        'title': 'New Prescription Uploaded',
        'time': 'Yesterday',
        'status': 'VIEWED',
        'icon': Icons.description_rounded,
        'color': AppColors.primary,
      },
      {
        'type': 'EMERGENCY',
        'patient': 'Sarah Khan',
        'title': 'SOS: Minor Injury',
        'time': '3 days ago',
        'status': 'RESOLVED',
        'icon': Icons.health_and_safety_rounded,
        'color': Colors.orange,
      },
      {
        'type': 'REPORT',
        'patient': 'Sarah Khan',
        'title': 'Lab Result: Blood Test',
        'time': '1 week ago',
        'status': 'NEW',
        'icon': Icons.biotech_rounded,
        'color': Colors.blue,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: historyItems.length,
      itemBuilder: (context, index) {
        final item = historyItems[index];
        return _buildHistoryCard(context, item, theme);
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item, ThemeData theme) {
    final bool isEmergency = item['type'] == 'EMERGENCY';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.neumorphicOut,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (item['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['patient'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text(item['time'] as String, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item['title'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['status'] as String,
                      style: TextStyle(fontSize: 10, color: item['color'] as Color, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No History Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('All patient alerts and reports will appear here.'),
        ],
      ),
    );
  }
}
