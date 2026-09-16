import 'package:flutter/material.dart';
import '../../presentation/theme/app_theme.dart';

/// Global messenger so non-widget code (interceptors, providers, services)
/// can show a SnackBar. Wired into `MaterialApp.router(scaffoldMessengerKey:)`.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key = GlobalKey<ScaffoldMessengerState>();

  /// Error snackbar in the SOS / critical red token.
  static void showError(String message) => _show(message, AppColors.sos, isError: true);

  /// Neutral snackbar using the theme's default snackbar styling.
  static void showInfo(String message) => _show(message, null);

  static void _show(String message, Color? color, {bool isError = false}) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (isError) ...[
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }
}
