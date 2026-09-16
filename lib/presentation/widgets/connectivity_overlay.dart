import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';
import 'design_system/design_system.dart';

/// App-wide NON-blocking offline banner.
///
/// Placed via `MaterialApp.router(builder:)`. When offline, a compact banner
/// is shown above the app (taking the status-bar inset) with direct
/// "Call 1122" / "SMS" actions. The app underneath stays fully usable, so the
/// offline SOS fallback on the emergency screen keeps working.
class ConnectivityOverlay extends ConsumerWidget {
  final Widget child;
  const ConnectivityOverlay({super.key, required this.child});

  static const String emergencyNumber = '1122';

  static Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final ok = await launchUrl(uri);
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the dialer. Please dial 1122 manually.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    final mediaQuery = MediaQuery.of(context);

    // IMPORTANT: the widget structure is identical online and offline (only
    // the banner's content/size changes). Returning `child` directly when
    // online would remount the navigator on every connectivity change and
    // reset open screens such as an in-progress SOS.
    return Column(
      children: [
        if (isConnected) const SizedBox.shrink() else _OfflineBanner(topInset: mediaQuery.padding.top),
        Expanded(
          // When offline the banner consumes the status-bar inset.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: !isConnected,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Restrained offline banner: neutral charcoal surface, white text, call /
/// SMS fallback actions. Static (no animation).
class _OfflineBanner extends StatelessWidget {
  final double topInset;
  const _OfflineBanner({required this.topInset});

  @override
  Widget build(BuildContext context) {
    // The overlay sits above the Navigator, so Theme may be the app theme but
    // no Scaffold exists — only use theme data, never Scaffold lookups.
    final theme = Theme.of(context);
    const fg = Colors.white;
    final text = theme.textTheme;
    final actionStyle = TextButton.styleFrom(
      foregroundColor: fg,
      minimumSize: const Size(MfSize.minTouch, MfSize.minTouch),
      padding: const EdgeInsets.symmetric(horizontal: MfSpace.xs),
      textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return Material(
      color: MfColors.isHighContrast(context) ? Colors.black : AppColors.charcoal,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(MfSpace.md, MfSpace.xxs, MfSpace.xs, MfSpace.xxs),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: fg, size: 20),
                const SizedBox(width: MfSpace.xs),
                Expanded(
                  child: Text(
                    'No internet. For emergencies call 1122.',
                    style: text.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ConnectivityOverlay._launch(
                    context,
                    Uri(scheme: 'tel', path: ConnectivityOverlay.emergencyNumber),
                  ),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Call'),
                  style: actionStyle,
                ),
                TextButton.icon(
                  onPressed: () => ConnectivityOverlay._launch(
                    context,
                    Uri(scheme: 'sms', path: ConnectivityOverlay.emergencyNumber),
                  ),
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: const Text('SMS'),
                  style: actionStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
