import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/caregiver_providers.dart';
import '../../theme/app_theme.dart';

class InvitationsListWidget extends ConsumerWidget {
  const InvitationsListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final theme = Theme.of(context);

    return invitationsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const SizedBox.shrink(),
      data: (invitations) {
        if (invitations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Pending Caregiver Requests (${invitations.length})', 
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
            ),
            ...invitations.map((inv) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.neumorphicOut,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: const Icon(Icons.person_add, color: Colors.orange),
                    ),
                    title: Text(inv.caregiverName ?? inv.caregiverEmail ?? 'Caregiver', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Wants to connect as: ${inv.relationship}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                          tooltip: 'Accept',
                          onPressed: () {
                            ref.read(respondToInvitationProvider({
                              'invitationId': inv.id,
                              'accept': true,
                            }));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                          tooltip: 'Decline',
                          onPressed: () {
                             ref.read(respondToInvitationProvider({
                              'invitationId': inv.id,
                              'accept': false,
                            }));
                          },
                        ),
                      ],
                    ),
                  ),
                )).toList(),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
