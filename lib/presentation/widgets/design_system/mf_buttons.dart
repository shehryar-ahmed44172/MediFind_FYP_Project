import 'package:flutter/material.dart';
import 'mf_tokens.dart';

/// Primary call-to-action. Full width by default, 56dp tall.
///
/// Use [tone] `MfTone.danger` for SOS / destructive primary actions.
class MfPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final MfTone tone;
  final String? semanticLabel;
  final double height;

  const MfPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.tone = MfTone.primary,
    this.semanticLabel,
    this.height = MfSize.primaryButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    ButtonStyle? style;
    if (tone != MfTone.primary) {
      final t = MfColors.tone(context, tone);
      style = FilledButton.styleFrom(
        backgroundColor: t.solid,
        foregroundColor: t.onSolid,
        disabledBackgroundColor: cs.surfaceContainerHighest,
        disabledForegroundColor: cs.onSurfaceVariant,
      );
    }
    final child = _ButtonContent(label: label, icon: icon, loading: loading, color: Colors.white);
    final button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: (style ?? const ButtonStyle()).copyWith(
          minimumSize: WidgetStatePropertyAll(Size(MfSize.minTouch, height)),
        ),
        child: child,
      ),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: expanded ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Secondary action: outlined, 48dp minimum (56dp when [large]).
class MfSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool large;
  final MfTone tone;
  final String? semanticLabel;

  const MfSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.large = false,
    this.tone = MfTone.primary,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final height = large ? MfSize.primaryButton : MfSize.minTouch;
    final t = MfColors.tone(context, tone);
    final fg = tone == MfTone.primary ? null : t.foreground;
    final button = OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        minimumSize: Size(MfSize.minTouch, height),
        side: tone == MfTone.primary ? null : BorderSide(color: t.border),
      ),
      child: _ButtonContent(label: label, icon: icon, loading: loading, color: fg),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: expanded ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Low-emphasis text action with a 48dp touch target.
class MfTextButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final MfTone tone;

  const MfTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tone = MfTone.primary,
  });

  @override
  Widget build(BuildContext context) {
    final fg = tone == MfTone.primary ? null : MfColors.tone(context, tone).foreground;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: fg),
      child: _ButtonContent(label: label, icon: icon, loading: false, color: fg),
    );
  }
}

/// Icon button that ALWAYS carries a tooltip / semantics label.
class MfIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool filled;

  const MfIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: cs.surface,
              side: BorderSide(color: cs.outlineVariant),
              minimumSize: const Size(MfSize.minTouch, MfSize.minTouch),
            )
          : null,
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final Color? color;
  const _ButtonContent({required this.label, required this.icon, required this.loading, this.color});

  @override
  Widget build(BuildContext context) {
    final text = Flexible(
      child: Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
    if (loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: MfSpace.sm),
          text,
        ],
      );
    }
    if (icon == null) return Row(mainAxisSize: MainAxisSize.min, children: [text]);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: MfSpace.xs),
        text,
      ],
    );
  }
}
