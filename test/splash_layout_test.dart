// The splash mark and wordmark must stay centred on the screen, before and
// after the intro animation — the native Android splash draws the mark dead
// centre, so anything else looks like a jump.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same layout as SplashScreen's centred column, without the auth work that
/// the real screen does in initState.
class _SplashVisual extends StatelessWidget {
  final double markBox;
  final double reveal;
  const _SplashVisual({required this.markBox, required this.reveal});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      key: const Key('mark'),
                      width: markBox,
                      height: markBox,
                      child: const ColoredBox(color: Colors.teal),
                    ),
                    ClipRect(
                      key: const Key('words-clip'),
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: reveal,
                        child: Opacity(
                          opacity: reveal,
                          child: const Column(
                            key: Key('words'),
                            children: [
                              Text('MEDIFIND', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                              SizedBox(height: 6),
                              Text('Emergency help, without hearing or speaking', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  const screen = Size(411, 891); // a normal phone in logical pixels

  Future<Rect> groupRect(WidgetTester tester, {required double markBox, required double reveal}) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_SplashVisual(markBox: markBox, reveal: reveal));
    await tester.pump();

    final mark = tester.getRect(find.byKey(const Key('mark')));
    if (reveal == 0) return mark;
    // The clip box is what is actually visible — the child inside it extends
    // below while it is still revealing.
    final words = tester.getRect(find.byKey(const Key('words-clip')));
    return Rect.fromLTRB(
      mark.left < words.left ? mark.left : words.left,
      mark.top,
      mark.right > words.right ? mark.right : words.right,
      words.bottom,
    );
  }

  testWidgets('mark is dead centre before the wordmark appears', (tester) async {
    final rect = await groupRect(tester, markBox: 288, reveal: 0);
    expect((rect.center.dy - screen.height / 2).abs(), lessThan(1.0));
    expect((rect.center.dx - screen.width / 2).abs(), lessThan(1.0));
  });

  testWidgets('mark and wordmark stay centred as a group once revealed', (tester) async {
    final rect = await groupRect(tester, markBox: 200, reveal: 1);
    expect((rect.center.dy - screen.height / 2).abs(), lessThan(2.0),
        reason: 'the settled group drifted off centre by ${rect.center.dy - screen.height / 2} px');
    expect((rect.center.dx - screen.width / 2).abs(), lessThan(1.0));
  });

  testWidgets('group stays centred midway through the animation', (tester) async {
    final rect = await groupRect(tester, markBox: 244, reveal: 0.5);
    expect((rect.center.dy - screen.height / 2).abs(), lessThan(2.0));
  });
}
