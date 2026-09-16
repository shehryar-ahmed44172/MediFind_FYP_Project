import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/design_system/design_system.dart';

/// Centered icon + title + description used at the top of auth steps.
class AuthStepIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? messageWidget;
  final MfTone tone;

  const AuthStepIntro({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.messageWidget,
    this.tone = MfTone.primary,
  });

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, tone);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: t.container,
            borderRadius: MfRadius.lgAll,
            border: Border.all(color: t.border),
          ),
          child: Icon(icon, size: 32, color: t.foreground),
        ),
        const SizedBox(height: MfSpace.md),
        Semantics(
          header: true,
          child: Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
        ),
        if (message != null) ...[
          const SizedBox(height: MfSpace.xs),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (messageWidget != null) ...[
          const SizedBox(height: MfSpace.xs),
          messageWidget!,
        ],
      ],
    );
  }
}

/// Single-action information dialog (success / error / notice).
Future<void> showAuthMessageDialog(
  BuildContext context, {
  required IconData icon,
  required MfTone tone,
  required String title,
  required String message,
  String buttonLabel = 'OK',
  VoidCallback? onConfirm,
  bool barrierDismissible = false,
  List<Widget> Function(BuildContext ctx)? extraActions,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final t = MfColors.tone(ctx, tone);
      return AlertDialog(
        icon: Icon(icon, size: 32, color: tone == MfTone.danger ? MfColors.sos(ctx) : t.foreground),
        title: Text(title, textAlign: TextAlign.center),
        content: SingleChildScrollView(child: Text(message)),
        actionsPadding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.md),
        actions: [
          if (extraActions != null) ...extraActions(ctx),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm?.call();
            },
            child: Text(buttonLabel),
          ),
        ],
      );
    },
  );
}

/// One digit box of a 6-digit code input. Behaviour (focus moves, auto
/// submit) is supplied by the screen through [onChanged] / [onTap].
class AuthOtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int index;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;

  const AuthOtpBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.index,
    required this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hc = MfColors.isHighContrast(context);

    return ListenableBuilder(
      listenable: Listenable.merge([focusNode, controller]),
      builder: (context, _) {
        final filled = controller.text.isNotEmpty;
        return Semantics(
          label: 'Digit ${index + 1} of 6',
          textField: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MfSize.primaryButton, maxWidth: 56),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 1,
              style: text.headlineSmall?.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: filled
                    ? Color.alphaBlend(cs.primaryContainer.withValues(alpha: 0.5), cs.surface)
                    : cs.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: MfSpace.sm),
                enabledBorder: OutlineInputBorder(
                  borderRadius: MfRadius.mdAll,
                  borderSide: BorderSide(
                    color: filled ? cs.primary : cs.outlineVariant,
                    width: hc ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: MfRadius.mdAll,
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
              ),
              onChanged: onChanged,
              onTap: onTap,
            ),
          ),
        );
      },
    );
  }
}

/// Row of six [AuthOtpBox]es with even spacing that adapts to width.
class AuthOtpRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int index, String value) onChanged;
  final void Function(int index)? onTap;

  const AuthOtpRow({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < controllers.length; i++) ...[
          if (i > 0) const SizedBox(width: MfSpace.xs),
          Flexible(
            child: AuthOtpBox(
              index: i,
              controller: controllers[i],
              focusNode: focusNodes[i],
              onChanged: (v) => onChanged(i, v),
              onTap: onTap == null ? null : () => onTap!(i),
            ),
          ),
        ],
      ],
    );
  }
}
