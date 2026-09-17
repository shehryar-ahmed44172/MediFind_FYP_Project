import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/emergency_status.dart';
import '../../providers/emergency_provider.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/responder_widgets.dart';

/// Responder "History" tab (header comes from the responder shell).
class ResponderHistoryScreen extends ConsumerWidget {
  const ResponderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(getResponderHistoryProvider);

    Future<void> refresh() async {
      ref.invalidate(getResponderHistoryProvider);
      await ref.read(getResponderHistoryProvider.future).catchError((_) => <dynamic>[]);
    }

    return historyAsync.when(
      data: (history) => RefreshIndicator(
        onRefresh: refresh,
        child: history.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const MfEmptyState(
                      icon: Icons.history_rounded,
                      title: 'No responses yet',
                      message: 'Emergencies you accept, decline or complete will be listed here.',
                    ),
                  ),
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, MfSpace.xl),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: MfSpace.xs),
                itemBuilder: (ctx, i) => _HistoryItemCard(item: history[i] as Map<String, dynamic>),
              ),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.all(MfSpace.gutter),
        child: MfSkeleton.list(count: 5, itemHeight: 88),
      ),
      error: (e, _) => MfErrorState(
        title: 'Could not load your history',
        message: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(getResponderHistoryProvider),
      ),
    );
  }
}

/// Status label / tone / icon for a history entry.
({String label, MfTone tone, IconData icon}) _statusVisual(String status) {
  switch (status) {
    case 'ACCEPTED':
    case 'RESPONDER_ASSIGNED':
      return (label: 'Accepted', tone: MfTone.primary, icon: Icons.check_circle_outline_rounded);
    case 'REJECTED':
      return (label: 'Declined', tone: MfTone.neutral, icon: Icons.do_not_disturb_on_outlined);
    case 'TAKEN':
      return (label: 'Taken by another responder', tone: MfTone.neutral, icon: Icons.people_outline_rounded);
    case 'COMPLETED':
    case 'RESOLVED':
      return (label: 'Completed', tone: MfTone.success, icon: Icons.task_alt_rounded);
    case 'CANCELLED':
      return (label: 'Cancelled', tone: MfTone.neutral, icon: Icons.event_busy_outlined);
    case 'EXPIRED':
      return (label: 'Expired', tone: MfTone.neutral, icon: Icons.timer_off_outlined);
    default:
      return (label: 'Pending', tone: MfTone.warning, icon: Icons.hourglass_empty_rounded);
  }
}

class _HistoryItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryItemCard({required this.item});

  String get _displayStatus {
    final status = item['status'] as String? ?? 'PENDING';
    // Prefer the EmergencyRequest status, but if it is still PENDING and the
    // parent emergency ended, show the emergency's status.
    final emergencyStatus = (item['emergency'] as Map<String, dynamic>?)?['status'] as String? ?? '';
    if (status == 'REJECTED' && item['rejectionReason'] == 'ASSIGNED_TO_ANOTHER_RESPONDER') return 'TAKEN';
    return (status == 'PENDING' &&
            (emergencyStatus == 'CANCELLED' || emergencyStatus == 'RESOLVED' || emergencyStatus == 'COMPLETED'))
        ? emergencyStatus
        : status;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final emergency = item['emergency'] as Map<String, dynamic>? ?? {};
    final patient = emergency['patient'] as Map<String, dynamic>? ?? {};
    final type = emergency['emergencyType'] as String?;
    final typeLabel = EmergencyTypes.label(type);
    final date = (DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now()).toLocal();
    final dateLabel = DateFormat('d MMM yyyy, h:mm a').format(date);
    final patientName = (patient['fullName'] as String?) ?? 'Unknown patient';
    final visual = _statusVisual(_displayStatus);

    return MfCard(
      onTap: () => _showHistoryDetails(context),
      semanticLabel: '$typeLabel emergency. Patient $patientName. ${visual.label}. $dateLabel. Opens details.',
      padding: const EdgeInsets.all(MfSpace.sm),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponderTypePictogram(type: type, tone: visual.tone == MfTone.success ? MfTone.success : MfTone.primary),
            const SizedBox(width: MfSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(typeLabel, style: text.titleSmall)),
                      MfStatusChip(label: visual.label, tone: visual.tone, icon: visual.icon),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(patientName, style: text.bodyMedium),
                  Text(dateLabel, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDetails(BuildContext context) {
    final emergency = item['emergency'] as Map<String, dynamic>? ?? {};
    final patient = emergency['patient'] as Map<String, dynamic>? ?? {};
    final date = (DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now()).toLocal();
    final visual = _statusVisual(_displayStatus);

    showMfBottomSheet<void>(
      context,
      title: 'Response details',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MfListGroup(
            children: [
              MfKeyValueRow(
                icon: Icons.person_outline_rounded,
                label: 'Patient',
                value: (patient['fullName'] as String?) ?? 'Unknown',
              ),
              MfKeyValueRow(
                icon: responderEmergencyTypeIcon(emergency['emergencyType'] as String?),
                label: 'Emergency type',
                value: EmergencyTypes.label(emergency['emergencyType'] as String?),
              ),
              MfKeyValueRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: DateFormat('EEE, d MMM yyyy, h:mm a').format(date),
              ),
              MfKeyValueRow(
                icon: visual.icon,
                label: 'Status',
                value: visual.label,
              ),
              if (item['rejectionReason'] != null && item['rejectionReason'] != 'ASSIGNED_TO_ANOTHER_RESPONDER')
                MfKeyValueRow(
                  icon: Icons.notes_rounded,
                  label: 'Reason',
                  value: item['rejectionReason'].toString(),
                ),
            ],
          ),
          const SizedBox(height: MfSpace.md),
          MfSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }
}
