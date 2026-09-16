import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/connectivity_provider.dart';

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
        if (isConnected)
          const SizedBox.shrink()
        else
        Material(
          color: const Color(0xFFD32F2F), // app SOS red
          child: Padding(
            padding: EdgeInsets.only(top: mediaQuery.padding.top),
            child: Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No internet. For emergencies call 1122.',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _launch(context, Uri(scheme: 'tel', path: emergencyNumber)),
                      icon: const Icon(Icons.phone_rounded, size: 18, color: Colors.white),
                      label: const Text('Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    ),
                    TextButton.icon(
                      onPressed: () => _launch(context, Uri(scheme: 'sms', path: emergencyNumber)),
                      icon: const Icon(Icons.sms_rounded, size: 18, color: Colors.white),
                      label: const Text('SMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
