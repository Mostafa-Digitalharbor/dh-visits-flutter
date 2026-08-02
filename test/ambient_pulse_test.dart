// Locks down the property that motivated [AmbientPulse]: between beats the
// widget must schedule **no frames at all**.
//
// The defect it replaced was invisible in code review — an
// `AnimationController..repeat()` looks like any other animation — but measured
// on the emulator it made the app render ~41 frames/second forever while a
// visit was active, versus zero with no visit on screen. A field rep keeps that
// screen open all day, so "forever" means an eight-hour hot GPU.
//
// `pumpAndSettle` is the assertion that matters here: it throws if frames never
// stop arriving, which is exactly what the old implementation did.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/ambient_pulse.dart';

void main() {
  Widget host({
    Duration period = const Duration(milliseconds: 200),
    Duration rest = const Duration(milliseconds: 400),
    required void Function(double) onBeat,
  }) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: AmbientPulse(
          period: period,
          rest: rest,
          builder: (_, beat) => AnimatedBuilder(
            animation: beat,
            builder: (_, __) {
              onBeat(beat.value);
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      );

  testWidgets('stops producing frames between beats', (tester) async {
    await tester.pumpWidget(host(onBeat: (_) {}));
    // Would time out against a `..repeat()` controller, which never settles.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('rests at the end of the ramp, not the start', (tester) async {
    // The resting value has to be the one that renders as "invisible" — every
    // caller fades its pulsing element out as the beat completes, so resting
    // at 0 would leave a halo lit through every gap.
    double last = -1;
    await tester.pumpWidget(host(onBeat: (v) => last = v));
    await tester.pumpAndSettle();
    expect(last, closeTo(1.0, 0.001));
  });

  testWidgets('beats again after the rest elapses', (tester) async {
    final seen = <double>[];
    await tester.pumpWidget(host(onBeat: seen.add));
    await tester.pumpAndSettle();
    seen.clear();

    // Nothing at all during the gap.
    await tester.pump(const Duration(milliseconds: 300));
    expect(seen, isEmpty, reason: 'a frame was drawn during the rest gap');

    // Then the next beat starts and runs to completion.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 50));
    expect(seen, isNotEmpty);
    expect(seen.first, lessThan(1.0));
    await tester.pumpAndSettle();
  });

  testWidgets('the pending rest timer is cancelled on dispose', (tester) async {
    // A leaked timer fires into a disposed controller and throws; the test
    // framework fails the test if any timer is still pending at teardown.
    await tester.pumpWidget(host(onBeat: (_) {}));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('isolates its repaints behind a boundary', (tester) async {
    // Without this the beat marks the whole surrounding subtree — the visit
    // bar's text, borders and elevation shadow — dirty on every frame.
    await tester.pumpWidget(host(onBeat: (_) {}));
    expect(
      find.descendant(
        of: find.byType(AmbientPulse),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });
}
