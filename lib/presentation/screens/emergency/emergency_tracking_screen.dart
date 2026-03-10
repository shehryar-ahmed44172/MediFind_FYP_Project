import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/emergency_provider.dart';

class EmergencyTrackingScreen extends ConsumerWidget {
  final String emergencyId;
  const EmergencyTrackingScreen({Key? key, required this.emergencyId})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to watch live emergency data
    final emergencyAsync = ref.watch(getEmergencyProvider(emergencyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Responder'),
        centerTitle: true,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: emergencyAsync.when(
        data: (emergency) => _buildBody(context),
        loading: () => _buildBody(context), // show UI immediately
        error: (_, __) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF006400), Color(0xFF228B22)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🚑 Help is on the way',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('ETA: ~8 minutes',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('Responder: Ahmed Khan',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Map
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.blue),
                  SizedBox(height: 8),
                  Text('Live Navigation Map',
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Responder & Patient live locations',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('(Google Maps API key required)',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status Timeline
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emergency Status',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _StatusItem(label: 'SOS Sent', isDone: true),
                  _StatusItem(label: 'Responder Assigned', isDone: true),
                  _StatusItem(label: 'Responder En Route', isDone: true),
                  _StatusItem(
                      label: 'Responder Arrived', isDone: false),
                  _StatusItem(
                      label: 'Emergency Resolved', isDone: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Cancel SOS (patients only, FR4.5)
          ElevatedButton.icon(
            onPressed: () => _showCancelDialog(context),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Emergency'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Emergency?'),
        content: const Text(
            'Are you sure you want to cancel the active emergency? The assigned responder will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, Keep Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Call updateEmergencyStatusProvider (CANCELLED)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency cancelled. Responder notified.'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Cancel Emergency',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final bool isDone;
  const _StatusItem({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isDone ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDone ? Colors.black : Colors.grey,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
