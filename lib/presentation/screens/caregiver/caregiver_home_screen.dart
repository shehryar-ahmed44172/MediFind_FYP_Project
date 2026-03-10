import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class CaregiverHomeScreen extends ConsumerWidget {
  const CaregiverHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Mock patients — in production wire to a caregiverPatientsProvider
    final linkedPatients = <Map<String, dynamic>>[];

    return Scaffold(
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(logoutProvider.future);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: linkedPatients.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No patients linked to your account',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 12),
                  const Text(
                    'Ask a patient to add you as their caregiver from their profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: linkedPatients.length,
              itemBuilder: (ctx, i) {
                final patient = linkedPatients[i];
                final hasActiveEmergency =
                    patient['hasActiveEmergency'] as bool? ?? false;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: hasActiveEmergency
                          ? Colors.red.shade100
                          : Colors.blue.shade100,
                      child: Icon(Icons.person,
                          color: hasActiveEmergency
                              ? Colors.red
                              : Colors.blue),
                    ),
                    title: Text(patient['name'] ?? 'Patient',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: hasActiveEmergency
                        ? const Text('🆘 ACTIVE EMERGENCY',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold))
                        : const Text('No active emergency',
                            style: TextStyle(color: Colors.green)),
                    trailing: hasActiveEmergency
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () => context.go(
                              '/caregiver/tracking/${patient['emergencyId']}',
                            ),
                            child: const Text('Track',
                                style: TextStyle(color: Colors.white)),
                          )
                        : const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}
