import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/emergency_provider.dart';
import '../../theme/app_theme.dart';

class ResponderHistoryScreen extends ConsumerWidget {
  const ResponderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(getResponderHistoryProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                const Text(
                  'Response History',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(getResponderHistoryProvider),
                ),
              ],
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (history) => history.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: history.length,
                      itemBuilder: (ctx, i) {
                        final item = history[i] as Map<String, dynamic>;
                        return _HistoryItemCard(item: item);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No past records found', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item['status'] as String? ?? 'PENDING';
    final emergency = item['emergency'] as Map<String, dynamic>? ?? {};
    final patient = emergency['patient'] as Map<String, dynamic>? ?? {};
    final type = (emergency['emergencyType'] as String? ?? 'Medical').toUpperCase();
    final date = DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'ACCEPTED':
      case 'RESPONDER_ASSIGNED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      case 'COMPLETED':
        statusColor = Colors.blue;
        statusIcon = Icons.task_alt;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return InkWell(
      onTap: () => _showHistoryDetails(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.cardShadow,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: Row(
            children: [
              Text(type.replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Patient: ${patient['fullName'] ?? 'Unknown User'}',
                  style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDetails(BuildContext context) {
    final emergency = item['emergency'] as Map<String, dynamic>? ?? {};
    final patient = emergency['patient'] as Map<String, dynamic>? ?? {};
    final date = DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Response Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.person_rounded, 'Patient', patient['fullName'] ?? 'Unknown'),
            _buildDetailRow(Icons.emergency_rounded, 'Type', emergency['emergencyType'] ?? 'Medical'),
            _buildDetailRow(Icons.calendar_today_rounded, 'Date', '${date.day}/${date.month}/${date.year}'),
            _buildDetailRow(Icons.info_outline_rounded, 'Status', item['status'] ?? 'N/A'),
            if (item['rejectionReason'] != null)
              _buildDetailRow(Icons.warning_amber_rounded, 'Reason', item['rejectionReason']),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
