import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'mf_scaffold.dart';
import 'mf_tokens.dart';

/// Standard confirmation dialog. Returns true when confirmed.
///
/// Set [destructive] for delete / cancel-SOS / sign-out style actions.
Future<bool> showMfConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        icon: icon == null ? null : Icon(icon, color: destructive ? cs.error : cs.primary, size: 28),
        title: Text(title),
        content: content ?? (message == null ? null : Text(message)),
        actionsPadding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.md),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Standard modal bottom sheet with handle and optional title.
Future<T?> showMfBottomSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      final cs = Theme.of(ctx).colorScheme;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MfSheetHandle(),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(title, style: text.titleLarge)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.md),
                child: builder(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Consistent snackbar. Uses the nearest ScaffoldMessenger.
void showMfSnackBar(
  BuildContext context,
  String message, {
  MfTone tone = MfTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(mfSnackBar(context, message, tone: tone, actionLabel: actionLabel, onAction: onAction, duration: duration));
}

SnackBar mfSnackBar(
  BuildContext context,
  String message, {
  MfTone tone = MfTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final cs = Theme.of(context).colorScheme;
  Color? bg;
  IconData? icon;
  switch (tone) {
    case MfTone.danger:
      bg = cs.error;
      icon = Icons.error_outline_rounded;
      break;
    case MfTone.success:
      icon = Icons.check_circle_outline_rounded;
      break;
    case MfTone.warning:
      icon = Icons.warning_amber_rounded;
      break;
    default:
      icon = null;
  }
  return SnackBar(
    backgroundColor: bg,
    duration: duration,
    content: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: tone == MfTone.success ? AppColors.success : Colors.white, size: 20),
          const SizedBox(width: MfSpace.sm),
        ],
        Expanded(child: Text(message)),
      ],
    ),
    action: actionLabel == null
        ? null
        : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}, textColor: Colors.white),
  );
}
