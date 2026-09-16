import 'package:flutter/material.dart';
import '../../../../core/utils/emergency_status.dart';
import '../../../widgets/design_system/design_system.dart';

/// Pictogram for an emergency type (Material rounded/outlined icons).
IconData responderEmergencyTypeIcon(String? type) {
  switch (EmergencyTypes.normalize(type)) {
    case EmergencyTypes.cardiac:
      return Icons.monitor_heart_outlined;
    case EmergencyTypes.breathing:
      return Icons.air_rounded;
    case EmergencyTypes.fall:
      return Icons.personal_injury_outlined;
    case EmergencyTypes.trauma:
      return Icons.local_hospital_outlined;
    case EmergencyTypes.stroke:
      return Icons.psychology_outlined;
    case EmergencyTypes.seizure:
      return Icons.bolt_rounded;
    case EmergencyTypes.diabetic:
      return Icons.bloodtype_outlined;
    default:
      return Icons.emergency_outlined;
  }
}

/// Tinted square with the emergency-type pictogram.
class ResponderTypePictogram extends StatelessWidget {
  final String? type;
  final double size;
  final MfTone tone;

  const ResponderTypePictogram({
    super.key,
    required this.type,
    this.size = 44,
    this.tone = MfTone.primary,
  });

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.container,
          borderRadius: MfRadius.smAll,
          border: Border.all(color: t.border),
        ),
        child: Icon(responderEmergencyTypeIcon(type), color: t.foreground, size: size * 0.55),
      ),
    );
  }
}

/// Prominent "DEAF · Text only" badge for request cards.
class ResponderDeafBadge extends StatelessWidget {
  const ResponderDeafBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Deaf patient. Communicate by text only.',
      excludeSemantics: true,
      child: const MfStatusChip(
        label: 'DEAF · Text only',
        icon: Icons.hearing_disabled_rounded,
        tone: MfTone.warning,
        solid: true,
      ),
    );
  }
}

/// Deaf-patient notice: "Communicate by text only" with one-tap quick
/// messages (optional) and an Open chat action.
class ResponderDeafCommsCard extends StatelessWidget {
  final String message;
  final List<String> quickMessages;
  final ValueChanged<String>? onQuickMessage;
  final VoidCallback? onOpenChat;
  final VoidCallback? onMoreMessages;

  const ResponderDeafCommsCard({
    super.key,
    this.message = 'Use text chat only. Avoid voice calls.',
    this.quickMessages = const [],
    this.onQuickMessage,
    this.onOpenChat,
    this.onMoreMessages,
  });

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, MfTone.warning);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return MfCard(
      tone: MfTone.warning,
      padding: const EdgeInsets.all(MfSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hearing_disabled_rounded, color: t.foreground, size: 28),
                const SizedBox(width: MfSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deaf patient: communicate by text only',
                          style: text.titleSmall?.copyWith(color: t.foreground)),
                      const SizedBox(height: 2),
                      Text(message, style: text.bodySmall?.copyWith(color: cs.onSurface)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (quickMessages.isNotEmpty && onQuickMessage != null) ...[
            const SizedBox(height: MfSpace.sm),
            Text('Tap to send', style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: MfSpace.xxs),
            Wrap(
              spacing: MfSpace.xs,
              runSpacing: MfSpace.xxs,
              children: [
                for (final m in quickMessages)
                  ActionChip(
                    avatar: const Icon(Icons.send_rounded, size: 16),
                    label: Text(m),
                    tooltip: 'Send "$m"',
                    onPressed: () => onQuickMessage!(m),
                  ),
              ],
            ),
          ],
          if (onOpenChat != null || onMoreMessages != null) ...[
            const SizedBox(height: MfSpace.sm),
            Row(
              children: [
                if (onOpenChat != null)
                  Expanded(
                    child: MfPrimaryButton(
                      label: 'Open chat',
                      icon: Icons.chat_bubble_outline_rounded,
                      height: MfSize.minTouch,
                      onPressed: onOpenChat,
                    ),
                  ),
                if (onOpenChat != null && onMoreMessages != null) const SizedBox(width: MfSpace.xs),
                if (onMoreMessages != null)
                  Expanded(
                    child: MfSecondaryButton(
                      label: 'More messages',
                      icon: Icons.message_outlined,
                      onPressed: onMoreMessages,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
