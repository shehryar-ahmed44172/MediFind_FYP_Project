import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../providers/caregiver_dashboard_provider.dart';

/// Caregiver activity history: linked patients' emergencies from
/// GET /api/emergencies/history (real data only).
class CaregiverHistoryScreen extends ConsumerWidget {
  const CaregiverHistoryScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(caregiverEmergencyHistoryProvider);
    try {
      await ref.read(caregiverEmergencyHistoryProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(caregiverEmergencyHistoryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/caregiver'),
        ),
        title: const Text(
          'Activity History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: historyAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 160),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => _buildMessageState(
            icon: Icons.cloud_off_rounded,
            iconColor: AppColors.error,
            title: 'Could not load history',
            body: 'Check your connection and try again.',
            action: ElevatedButton.icon(
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
            ),
          ),
          data: (emergencies) {
            if (emergencies.isEmpty) {
              return _buildMessageState(
                icon: Icons.history_toggle_off_rounded,
                iconColor: Colors.grey.shade500,
                title: 'No activity yet',
                body: 'History will appear here after an emergency.',
              );
            }
            final active = emergencies.where((e) => !e.isTerminal).toList();
            final past = emergencies.where((e) => e.isTerminal).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (active.isNotEmpty) ...[
                  _sectionHeader('Active emergencies'),
                  ...active.map((e) => _EmergencyCard(details: e)),
                ],
                if (past.isNotEmpty) ...[
                  _sectionHeader('Past emergencies'),
                  ...past.map((e) => _EmergencyCard(details: e)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Semantics(
        header: true,
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    Widget? action,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 64, color: iconColor),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        if (action != null) ...[
          const SizedBox(height: 24),
          Center(child: action),
        ],
      ],
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final CaregiverEmergencyDetails details;
  const _EmergencyCard({required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = details.isResolved
        ? AppColors.success
        : details.status == 'CANCELLED'
            ? Colors.grey.shade700
            : AppColors.error;
    final label = caregiverStatusLabel(details.status);
    final type = details.emergencyType.replaceAll('_', ' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: details.isTerminal ? AppShadows.neumorphicOut : AppShadows.sosMassiveGlow,
          color: theme.scaffoldBackgroundColor,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/caregiver/tracking/${details.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      details.isResolved
                          ? Icons.check_circle_rounded
                          : details.status == 'CANCELLED'
                              ? Icons.cancel_rounded
                              : Icons.emergency_rounded,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                details.patientName ?? 'Linked patient',
                                style:
                                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(caregiverRelativeTime(details.createdAt),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('SOS: $type', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        if (details.responderName != null) ...[
                          const SizedBox(height: 2),
                          Text('Responder: ${details.responderName}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label.toUpperCase(),
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!details.isTerminal)
                    ElevatedButton(
                      onPressed: () => context.push('/caregiver/tracking/${details.id}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(72, 48),
                      ),
                      child: const Text('Track', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 20),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
