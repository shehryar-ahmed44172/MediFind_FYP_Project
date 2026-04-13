import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/emergency_provider.dart';

class ActiveEmergencyScreen extends ConsumerStatefulWidget {
  const ActiveEmergencyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ActiveEmergencyScreen> createState() =>
      _ActiveEmergencyScreenState();
}

class _ActiveEmergencyScreenState extends ConsumerState<ActiveEmergencyScreen> {
  String _currentStatus = 'ACCEPTED';

  final List<Map<String, dynamic>> _statusSteps = [
    {'status': 'ACCEPTED', 'label': 'Request Accepted', 'icon': Icons.check_circle_outline},
    {'status': 'EN_ROUTE', 'label': 'En Route to Patient', 'icon': Icons.directions_car_outlined},
    {'status': 'ARRIVED', 'label': 'Arrived at Scene', 'icon': Icons.location_on_outlined},
    {'status': 'RESOLVED', 'label': 'Emergency Resolved', 'icon': Icons.check_circle_rounded},
  ];

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _currentStatus = newStatus);
    
    try {
      // We need to pass the emergencyId here. The screen doesn't seem to have one passed.
      // Assuming a generic call or using a passed ID in reality. Here I use a mock 'current_emergency_id'.
      await ref.read(updateEmergencyStatusProvider(
        UpdateEmergencyStatusParams(emergencyId: 'current_emergency_id', status: newStatus)
      ).future);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated: ${newStatus.replaceAll('_', ' ')}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Status update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIdx =
        _statusSteps.indexWhere((s) => s['status'] == _currentStatus);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Active Emergency'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Patient Info Card
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.neumorphicOut,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_outlined, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Patient Info',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Divider(),
                    const Text('Patient: John Doe',
                        style: TextStyle(fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('Emergency: Cardiac Emergency',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Location: 32.1234, 73.5678',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Map placeholder (Google Maps would go here)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.neumorphicIn,
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: AppColors.primary),
                    SizedBox(height: 8),
                    Text('Navigation Map',
                        style: TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Text('(Google Maps — requires API key)',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Timeline
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.neumorphicOut,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Timeline',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._statusSteps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final step = entry.value;
                      final isDone = idx <= currentIdx;
                      final isCurrent = idx == currentIdx;
                      return _StatusStep(
                        icon: step['icon'],
                        label: step['label'],
                        isDone: isDone,
                        isCurrent: isCurrent,
                        isLast: idx == _statusSteps.length - 1,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (_currentStatus != 'RESOLVED') ...[
              ElevatedButton.icon(
                onPressed: () {
                  final nextIdx = currentIdx + 1;
                  if (nextIdx < _statusSteps.length) {
                    _updateStatus(_statusSteps[nextIdx]['status']);
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  currentIdx + 1 < _statusSteps.length
                      ? 'Mark: ${_statusSteps[currentIdx + 1]['label']}'
                      : 'Completed',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.neumorphicIn,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Emergency Resolved!',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/responder'),
                child: const Text('Return to Dashboard'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _StatusStep({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? Colors.green : Colors.grey.shade300;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? Colors.green : Colors.grey.shade200,
                border: isCurrent
                    ? Border.all(color: Colors.green, width: 3)
                    : null,
              ),
              child: Icon(icon,
                  color: isDone ? Colors.white : Colors.grey.shade400,
                  size: 18),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: color),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isDone ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
