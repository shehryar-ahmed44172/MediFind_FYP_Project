import 'package:flutter/material.dart';

/// Global messenger so non-widget code (interceptors, providers, services)
/// can show a SnackBar. Wired into `MaterialApp.router(scaffoldMessengerKey:)`.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key = GlobalKey<ScaffoldMessengerState>();

  static void showError(String message) => _show(message, const Color(0xFFD32F2F));

  static void showInfo(String message) => _show(message, const Color(0xFF334155));

  static void _show(String message, Color color) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }
}
