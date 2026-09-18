import 'package:flutter/material.dart';

/// Tells a [MapLoadingCover] that its map is ready. Call [markReady] from the
/// map's `onMapCreated`.
class MapCoverController extends ValueNotifier<bool> {
  MapCoverController() : super(false);

  /// Tiles keep drawing for a moment after the map is created, so the cover
  /// fades out shortly after.
  void markReady() {
    if (value) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () => value = true);
  }
}

/// Shows "Loading map…" over a map until it is ready, instead of a blank grey box.
class MapLoadingCover extends StatelessWidget {
  const MapLoadingCover({super.key, required this.controller, required this.child});

  final MapCoverController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: controller,
            builder: (context, ready, _) => IgnorePointer(
              ignoring: ready,
              child: AnimatedOpacity(
                opacity: ready ? 0 : 1,
                duration: const Duration(milliseconds: 350),
                child: ColoredBox(
                  color: cs.surfaceContainerHigh,
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      label: 'Loading map',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 36, color: cs.primary),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 120,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(2),
                              color: cs.primary,
                              backgroundColor: cs.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ExcludeSemantics(
                            child: Text('Loading map…', style: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
