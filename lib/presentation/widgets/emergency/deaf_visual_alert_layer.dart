import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/router.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../design_system/design_system.dart';

/// App-wide full-screen visual alert for deaf / text-only patients.
///
/// Rendered from `MaterialApp.router(builder:)`, i.e. ABOVE the root
/// navigator, so it is visible on every screen — including full-screen
/// routes like the SOS countdown and live tracking that sit above the shell.
/// This is the ONLY deaf emergency overlay (screens must not add their own).
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
              onShowCard: () {
                ref.read(visualEmergencyAlertProvider.notifier).state = null;
                AppRouter.router.push('/home/show-card');
              },
            ),
          ),
      ],
    );
  }
}

class _DeafFullScreenAlert extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onShowCard;

  const _DeafFullScreenAlert({
    required this.message,
    required this.onDismiss,
    required this.onShowCard,
  });

  @override
  State<_DeafFullScreenAlert> createState() => _DeafFullScreenAlertState();
}

class _DeafFullScreenAlertState extends State<_DeafFullScreenAlert> with SingleTickerProviderStateMixin {
  // A slow (1 Hz, photosensitivity-safe) flash between two shades of the SOS
  // red for a few seconds, so the alert is noticed without sound.
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || MfMotion.reduced(context)) return;
      for (var i = 0; i < 6 && mounted; i++) {
        await _flash.forward();
        if (!mounted) return;
        await _flash.reverse();
      }
    });
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sos = cs.error;
    final darker = Color.lerp(sos, Colors.black, 0.35)!;

    return Semantics(
      liveRegion: true,
      label: widget.message,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _flash,
          builder: (context, child) => ColoredBox(
            color: Color.lerp(sos, darker, _flash.value)!,
            child: child,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: MfSpace.lg, vertical: MfSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 72),
                      const SizedBox(height: MfSpace.lg),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: MfSpace.xl),
                      FilledButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onDismiss();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: darker,
                          minimumSize: const Size.fromHeight(MfSize.primaryButton),
                        ),
                        child: const Text('OK, got it'),
                      ),
                      const SizedBox(height: MfSpace.sm),
                      OutlinedButton.icon(
                        onPressed: widget.onShowCard,
                        icon: const Icon(Icons.co_present_outlined),
                        label: const Text('Show card to people nearby'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          minimumSize: const Size.fromHeight(MfSize.primaryButton),
                        ),
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
