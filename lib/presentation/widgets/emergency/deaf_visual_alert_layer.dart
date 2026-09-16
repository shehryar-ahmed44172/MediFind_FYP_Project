import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';

/// App-wide full-screen visual alert for deaf / text-only patients.
///
/// Rendered from `MaterialApp.router(builder:)`, i.e. ABOVE the root
/// navigator, so it is visible on every screen — including full-screen
/// routes like the SOS countdown and live tracking that sit above the shell.
class DeafVisualAlertLayer extends ConsumerWidget {
  final Widget child;
  const DeafVisualAlertLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(visualEmergencyAlertProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final textOnly = ref.watch(accessibilityProvider.select((s) => s.textOnlyMode));
    final isDeafPatient = user?.role == 'PATIENT' &&
        (user?.patientType?.toUpperCase() == 'DEAF' || textOnly);
    final show = message != null && isDeafPatient;

    // IMPORTANT: keep the widget structure constant (always a Stack with the
    // app as the first child). Switching between `child` and `Stack(child)`
    // would remount the whole navigator and reset every open screen — e.g.
    // restart an in-progress SOS countdown.
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (show)
          Positioned.fill(
            child: _DeafFullScreenAlert(
              message: message,
              onDismiss: () => ref.read(visualEmergencyAlertProvider.notifier).state = null,
            ),
          ),
      ],
    );
  }
}

class _DeafFullScreenAlert extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _DeafFullScreenAlert({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: Container(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.97),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 96),
                      const SizedBox(height: 32),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 48),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onDismiss();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFD32F2F),
                          minimumSize: const Size(200, 56),
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          elevation: 8,
                        ),
                        child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
