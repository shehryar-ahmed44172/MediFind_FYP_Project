import 'package:flutter/material.dart';
import '../../../widgets/design_system/design_system.dart';

/// Full-width offline notice shown at the top of a dashboard.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = MfColors.tone(context, MfTone.warning);
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.xs),
        decoration: BoxDecoration(
          color: Color.alphaBlend(t.container, cs.surface),
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: t.foreground, size: 20),
            const SizedBox(width: MfSpace.xs),
            Expanded(
              child: Text(
                'No internet connection. SOS will fall back to SMS or a phone call.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
