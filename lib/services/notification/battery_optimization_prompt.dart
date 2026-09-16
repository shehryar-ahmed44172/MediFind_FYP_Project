import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'push_core.dart';

/// One-time explanation + request to exclude MediFind from Android battery
/// optimisation, so the background alert service is not killed while the app
/// is closed. Shown once per install, after login.
class BatteryOptimizationPrompt {
  BatteryOptimizationPrompt._();

  static bool _showing = false;

  static Future<void> maybeShow(GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb || !Platform.isAndroid || _showing) return;
    try {
      if (await PushSessionStore.wasBatteryPromptShown()) return;
      if (await Permission.ignoreBatteryOptimizations.isGranted) {
        await PushSessionStore.markBatteryPromptShown();
        return;
      }

      _showing = true;
      await PushSessionStore.markBatteryPromptShown();

      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.battery_saver_outlined, size: 40),
          title: const Text('Keep emergency alerts on', textAlign: TextAlign.center),
          content: const Text(
            'Allow MediFind to run in background so emergency alerts reach you when the app is closed.\n\n'
            'MediFind keeps a lightweight connection open and only uses it to deliver alerts.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );

      if (allow == true) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint('[Push] battery optimisation prompt failed: $e');
    } finally {
      _showing = false;
    }
  }
}
