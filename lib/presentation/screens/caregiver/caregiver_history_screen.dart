import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/caregiver_dashboard_provider.dart';
import '../../widgets/design_system/design_system.dart';

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
    final historyAsync = ref.watch(caregiverEmergencyHistoryProvider);

    return MfScaffold(
      title: 'Emergency history',
      fallbackRoute: '/caregiver',
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: historyAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(MfSpace.gutter),
            children: [MfSkeleton.list(count: 5, itemHeight: 104)],
          ),
          error: (e, _) => _scrollableState(
            MfErrorState(
              title: 'Could not load history',
              message: 'Check your connection and try again.',
              onRetry: () => _refresh(ref),
            ),
          ),
          data: (emergencies) {
            if (emergencies.isEmpty) {
              return _scrollableState(
                const MfEmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No activity yet',
                  message: 'History will appear here after an emergency.',
                ),
              );
            }
            final active = emergencies.where((e) => !e.isTerminal).toList();
            final past = emergencies.where((e) => e.isTerminal).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.xs, MfSpace.gutter, MfSpace.xl),
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
      padding: const EdgeInsets.only(top: MfSpace.md),
      child: MfSectionTitle(title),
    );
  }

  /// Keeps pull-to-refresh working for full-height states.
  Widget _scrollableState(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final CaregiverEmergencyDetails details;
  const _EmergencyCard({required this.details});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final type = details.emergencyType.replaceAll('_', ' ');
    final when = caregiverRelativeTime(details.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: MfSpace.sm),
      child: MfCard(
        tone: details.isTerminal ? null : MfTone.danger,
        onTap: () => context.push('/caregiver/tracking/${details.id}'),
        semanticLabel: '${details.patientName ?? 'Linked patient'}, $type, ${caregiverStatusLabel(details.status)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.patientName ?? 'Linked patient',
                        style: text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text('SOS: $type', style: text.bodyMedium),
                      if (details.responderName != null)
                        Text(
                          'Responder: ${details.responderName}',
                          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: MfSpace.xs),
                if (when.isNotEmpty)
                  Text(when, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: MfSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MfStatusChip.emergency(details.status),
                  ),
                ),
                const SizedBox(width: MfSpace.xs),
                if (!details.isTerminal)
                  MfPrimaryButton(
                    label: 'Track live',
                    icon: Icons.my_location_rounded,
                    tone: MfTone.danger,
                    expanded: false,
                    height: MfSize.minTouch,
                    onPressed: () => context.push('/caregiver/tracking/${details.id}'),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
