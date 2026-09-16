import 'package:flutter/material.dart';
import '../../../core/utils/emergency_status.dart';
import 'mf_tokens.dart';

/// Small status pill: icon + label, tinted by [tone].
class MfStatusChip extends StatelessWidget {
  final String label;
  final MfTone tone;
  final IconData? icon;
  final bool solid;
  final VoidCallback? onTap;
  final String? tooltip;

  const MfStatusChip({
    super.key,
    required this.label,
    this.tone = MfTone.neutral,
    this.icon,
    this.solid = false,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, tone);
    final fg = solid ? t.onSolid : t.foreground;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.xs, vertical: MfSpace.xxs),
      decoration: BoxDecoration(
        color: solid ? t.solid : t.container,
        borderRadius: MfRadius.smAll,
        border: Border.all(color: solid ? t.solid : t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: MfSpace.xxs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return Semantics(label: label, excludeSemantics: true, child: chip);
    return Semantics(
      button: true,
      label: tooltip ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: MfRadius.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MfSize.minTouch),
          child: Center(widthFactor: 1, child: chip),
        ),
      ),
    );
  }

  /// Chip for an emergency status string (uses [EmergencyStatus.label]).
  factory MfStatusChip.emergency(String? status, {Key? key}) {
    final s = EmergencyStatus.normalize(status);
    MfTone tone;
    IconData icon;
    if (EmergencyStatus.isResolved(s)) {
      tone = MfTone.success;
      icon = Icons.check_circle_outline_rounded;
    } else if (EmergencyStatus.isCancelled(s)) {
      tone = MfTone.neutral;
      icon = Icons.block_rounded;
    } else if (s == 'ARRIVED') {
      tone = MfTone.success;
      icon = Icons.location_on_outlined;
    } else if (EmergencyStatus.isAssigned(s)) {
      tone = MfTone.primary;
      icon = Icons.two_wheeler_rounded;
    } else {
      tone = MfTone.danger;
      icon = Icons.sos_rounded;
    }
    return MfStatusChip(key: key, label: EmergencyStatus.label(s), tone: tone, icon: icon);
  }
}

/// Inline banner for notices (deaf mode, warnings, offline, info).
class MfInfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final MfTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  const MfInfoBanner({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.tone = MfTone.info,
    this.actionLabel,
    this.onAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, tone);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(MfSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: t.foreground, size: 24),
          const SizedBox(width: MfSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(color: t.foreground)),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(message!, style: text.bodySmall?.copyWith(color: cs.onSurface)),
                ],
                if (actionLabel != null && onAction != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: t.foreground,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: t.foreground),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      child: Material(
        color: Color.alphaBlend(t.container, cs.surface),
        shape: RoundedRectangleBorder(
          borderRadius: MfRadius.mdAll,
          side: BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// A single step of an [MfStatusTimeline].
class MfTimelineStep {
  final String label;
  final IconData icon;
  final String? caption;
  const MfTimelineStep(this.label, this.icon, {this.caption});
}

/// Who is looking at an emergency timeline.
enum MfTimelinePerspective { patient, caregiver }

/// THE status timeline used by patient tracking, responder active emergency
/// and caregiver tracking.
class MfStatusTimeline extends StatelessWidget {
  final List<MfTimelineStep> steps;

  /// Index of the current step. Steps before it are complete.
  final int currentIndex;

  final Axis axis;

  /// Shows the timeline as cancelled (current step marked, no progress color).
  final bool cancelled;

  /// When true, the current (last) step is shown as complete.
  final bool completed;

  const MfStatusTimeline({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.axis = Axis.horizontal,
    this.cancelled = false,
    this.completed = false,
  });

  /// Standard emergency progress: SOS sent → assigned → on the way → arrived → resolved.
  factory MfStatusTimeline.emergency({
    Key? key,
    required String? status,
    MfTimelinePerspective perspective = MfTimelinePerspective.patient,
    Axis axis = Axis.horizontal,
  }) {
    final patient = perspective == MfTimelinePerspective.patient;
    final s = EmergencyStatus.normalize(status);
    return MfStatusTimeline(
      key: key,
      axis: axis,
      currentIndex: emergencyIndex(s),
      cancelled: EmergencyStatus.isCancelled(s),
      completed: EmergencyStatus.isResolved(s),
      steps: [
        MfTimelineStep(patient ? 'SOS sent' : 'Searching', Icons.sos_rounded),
        const MfTimelineStep('Assigned', Icons.person_pin_circle_outlined),
        const MfTimelineStep('On the way', Icons.two_wheeler_rounded),
        const MfTimelineStep('Arrived', Icons.location_on_outlined),
        const MfTimelineStep('Resolved', Icons.check_circle_outline_rounded),
      ],
    );
  }

  /// Maps a backend status to the 5-step emergency timeline index.
  static int emergencyIndex(String? status) {
    switch (EmergencyStatus.normalize(status)) {
      case 'ASSIGNED':
      case 'ACCEPTED':
      case 'RESPONDER_ASSIGNED':
        return 1;
      case 'EN_ROUTE':
        return 2;
      case 'ARRIVED':
      case 'TREATING':
      case 'TRANSPORTED':
        return 3;
      case 'RESOLVED':
      case 'COMPLETED':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = currentIndex.clamp(0, steps.length - 1);
    final label = cancelled
        ? 'Progress: cancelled'
        : 'Progress: step ${current + 1} of ${steps.length}, ${steps[current].label}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: axis == Axis.horizontal ? _horizontal(context, current) : _vertical(context, current),
    );
  }

  _StepVisual _visual(BuildContext context, int i, int current) {
    final cs = Theme.of(context).colorScheme;
    final primary = MfColors.tone(context, MfTone.primary).solid;
    final success = MfColors.tone(context, MfTone.success).solid;
    final done = i < current || (completed && i == current);
    final isCurrent = i == current && !done;
    if (cancelled) {
      return _StepVisual(
        fill: i <= current ? cs.onSurfaceVariant : cs.surface,
        border: cs.outline,
        iconColor: i <= current ? cs.surface : cs.onSurfaceVariant,
        line: cs.outlineVariant,
        icon: i == current ? Icons.close_rounded : steps[i].icon,
        textColor: cs.onSurfaceVariant,
        bold: i == current,
      );
    }
    return _StepVisual(
      fill: done ? success : (isCurrent ? primary : cs.surface),
      border: done ? success : (isCurrent ? primary : cs.outline),
      iconColor: done || isCurrent ? Colors.white : cs.onSurfaceVariant,
      line: i < current ? success : cs.outlineVariant,
      icon: done ? Icons.check_rounded : steps[i].icon,
      textColor: i <= current ? cs.onSurface : cs.onSurfaceVariant,
      bold: isCurrent,
    );
  }

  Widget _circle(_StepVisual v, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: v.fill,
          border: Border.all(color: v.border, width: 1.5),
        ),
        child: Icon(v.icon, size: size * 0.55, color: v.iconColor),
      );

  Widget _horizontal(BuildContext context, int current) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Builder(builder: (context) {
              final v = _visual(context, i, current);
              final prevLine = i == 0 ? Colors.transparent : _visual(context, i - 1, current).line;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Container(height: 2, color: prevLine)),
                      _circle(v, 28),
                      Expanded(
                        child: Container(height: 2, color: i == steps.length - 1 ? Colors.transparent : v.line),
                      ),
                    ],
                  ),
                  const SizedBox(height: MfSpace.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      steps[i].label,
                      textAlign: TextAlign.center,
                      style: text.labelSmall?.copyWith(
                        color: v.textColor,
                        fontWeight: v.bold ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
      ],
    );
  }

  Widget _vertical(BuildContext context, int current) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Builder(builder: (context) {
            final v = _visual(context, i, current);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      _circle(v, 32),
                      if (i < steps.length - 1)
                        Expanded(child: Container(width: 2, color: v.line, constraints: const BoxConstraints(minHeight: 16))),
                    ],
                  ),
                  const SizedBox(width: MfSpace.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: MfSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].label,
                            style: text.titleSmall?.copyWith(
                              color: v.textColor,
                              fontWeight: v.bold ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (steps[i].caption != null)
                            Text(steps[i].caption!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _StepVisual {
  final Color fill;
  final Color border;
  final Color iconColor;
  final Color line;
  final IconData icon;
  final Color textColor;
  final bool bold;
  const _StepVisual({
    required this.fill,
    required this.border,
    required this.iconColor,
    required this.line,
    required this.icon,
    required this.textColor,
    required this.bold,
  });
}
