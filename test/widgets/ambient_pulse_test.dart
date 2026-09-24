// Layout and behaviour cases for [AmbientPulse] that complement
// test/ambient_pulse_test.dart, which already locks down: settling between
// beats, resting at 1.0, beating again after the rest, cancelling the rest
// timer on dispose, and the repaint boundary. Nothing here repeats those.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/ambient_pulse.dart';

import 'widget_harness.dart';

const _period = Duration(milliseconds: 200);
const _rest = Duration(milliseconds: 400);
const _frame = Duration(milliseconds: 16);

/// The live-visit dot as callers build it: a fixed slot, with a halo that
/// grows and fades out as the beat completes.
Widget _halo(
  BuildContext context,
  Animation<double> beat, {
  void Function(double)? onBeat,
}) {
  final color = Theme.of(context).colorScheme.primary;
  return SizedBox.square(
    dimension: 40,
    child: AnimatedBuilder(
      animation: beat,
      builder: (_, __) {
        onBeat?.call(beat.value);
        return Center(
          child: Transform.scale(
            scale: 1 + beat.value,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 1 - beat.value),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _pulse({
  Duration period = _period,
  Duration rest = _rest,
  Curve curve = Curves.easeOut,
  void Function(double)? onBeat,
  void Function(Animation<double>)? onAnimation,
}) => AmbientPulse(
  period: period,
  rest: rest,
  curve: curve,
  builder: (context, beat) {
    onAnimation?.call(beat);
    return _halo(context, beat, onBeat: onBeat);
  },
);

/// Pumps [total] as a stream of ~60Hz frames, the way a device would.
Future<void> _frames(WidgetTester tester, Duration total) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(_frame);
    elapsed += _frame;
  }
}

/// How many times the beat restarted from the bottom of the ramp.
int _restarts(List<double> values) {
  var n = 0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] < values[i - 1]) n++;
  }
  return n;
}

void main() {
  setUpAll(initHarness);

  group('AmbientPulse layout', () {
    testOnEverySurface(
      'a pulsing dot beside a long status line never resizes its slot',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AmbientPulse(builder: (context, beat) => _halo(context, beat)),
            const SizedBox(width: 12),
            Expanded(child: Text('${LongText.of(s)} ${LongText.arabicPerson}')),
          ],
        ),
      ),
      verify: (tester, s) async {
        final pulse = find.byType(AmbientPulse);
        final origin = tester.getTopLeft(pulse);
        // Sample the whole cycle — mid-beat, end of beat, deep in the rest,
        // and into the next beat. The slot must not move or grow.
        for (final step in [0, 250, 250, 700, 1500, 300]) {
          await tester.pump(Duration(milliseconds: step));
          expect(tester.getSize(pulse), const Size(40, 40));
          expect(tester.getTopLeft(pulse), origin);
          expectCleanLayout(tester);
        }
      },
    );

    testWidgets('adds no size of its own around the builder', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: AmbientPulse(
            builder: (_, __) => const SizedBox(width: 17, height: 9),
          ),
        ),
        settle: Duration.zero,
      );
      expect(tester.getSize(find.byType(AmbientPulse)), const Size(17, 9));
    });
  });

  group('AmbientPulse behaviour', () {
    testWidgets('starts the first beat on mount, from the bottom of the ramp', (
      tester,
    ) async {
      final seen = <double>[];
      await pumpSurface(
        tester,
        phoneEn,
        _pulse(onBeat: seen.add),
        settle: Duration.zero,
      );
      expect(seen.first, 0);
      // No initial rest: the controller is already driving frames.
      expect(tester.binding.hasScheduledFrame, isTrue);
      await _frames(tester, const Duration(milliseconds: 100));
      expect(seen.last, inExclusiveRange(0, 1));
    });

    testWidgets('hands the builder the eased value, not the raw ramp', (
      tester,
    ) async {
      Future<double> halfway(Curve curve) async {
        late Animation<double> beat;
        await pumpSurface(
          tester,
          phoneEn,
          _pulse(
            curve: curve,
            period: const Duration(milliseconds: 1000),
            onAnimation: (a) => beat = a,
          ),
          settle: Duration.zero,
        );
        await tester.pump(const Duration(milliseconds: 500));
        final v = beat.value;
        // Drop the tree so the next pump starts a fresh controller.
        await tester.pumpWidget(const SizedBox.shrink());
        return v;
      }

      expect(await halfway(Curves.linear), closeTo(0.5, 0.001));
      expect(
        await halfway(Curves.easeOut),
        closeTo(Curves.easeOut.transform(0.5), 0.001),
      );
      expect(
        await halfway(Curves.easeIn),
        closeTo(Curves.easeIn.transform(0.5), 0.001),
      );
    });

    testWidgets('a beat reaches the top of the ramp exactly at its period', (
      tester,
    ) async {
      late Animation<double> beat;
      await pumpSurface(
        tester,
        phoneEn,
        _pulse(
          period: const Duration(milliseconds: 500),
          onAnimation: (a) => beat = a,
        ),
        settle: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 499));
      expect(beat.value, lessThan(1));
      expect(beat.status, AnimationStatus.forward);
      await tester.pump(const Duration(milliseconds: 1));
      expect(beat.value, 1);
      // A controller reports completion on the first frame *past* its
      // duration; that frame is the one that starts the rest.
      await tester.pump(const Duration(milliseconds: 1));
      expect(beat.status, AnimationStatus.completed);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('goes idle in every rest, not only the first', (tester) async {
      final seen = <double>[];
      await pumpSurface(
        tester,
        phoneEn,
        _pulse(onBeat: seen.add),
        settle: Duration.zero,
      );

      for (var beat = 1; beat <= 3; beat++) {
        await tester.pumpAndSettle(_frame);
        expect(seen.last, closeTo(1, 0.001), reason: 'beat $beat ended');
        expect(
          tester.binding.hasScheduledFrame,
          isFalse,
          reason: 'rest $beat is not idle',
        );

        final framesBefore = seen.length;
        await tester.pump(_rest - const Duration(milliseconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
        // `pump` draws one frame of its own; the builder must not have run
        // for it — nothing changed.
        expect(seen.length, framesBefore, reason: 'rebuilt during rest $beat');

        // The timer fires and the next beat starts driving frames again.
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.binding.hasScheduledFrame, isTrue);
      }
      expect(_restarts(seen), 3);
      await tester.pumpAndSettle(_frame);
    });

    testWidgets(
      'a parent rebuild mid-beat neither restarts nor re-creates it',
      (tester) async {
        final animations = <Animation<double>>{};
        final seen = <double>[];
        Widget host(String label) => Row(
          children: [
            _pulse(onBeat: seen.add, onAnimation: animations.add),
            Text(label),
          ],
        );

        await pumpSurface(tester, phoneEn, host('a'), settle: Duration.zero);
        await _frames(tester, const Duration(milliseconds: 96));
        final before = seen.last;
        expect(before, greaterThan(0));

        // A bloc emit rebuilds the bar with new text.
        await pumpSurface(tester, phoneEn, host('b'), settle: Duration.zero);
        await tester.pump(_frame);
        expect(find.text('b'), findsOneWidget);
        expect(seen.last, greaterThanOrEqualTo(before));
        expect(
          animations,
          hasLength(1),
          reason: 'the builder must keep receiving the same animation',
        );
        expect(_restarts(seen), 0);
        await tester.pumpAndSettle(_frame);
      },
    );

    testWidgets('a muted ticker (covered route) draws nothing, then resumes', (
      tester,
    ) async {
      final seen = <double>[];
      Widget host(bool enabled) => TickerMode(
        enabled: enabled,
        child: _pulse(onBeat: seen.add),
      );

      await pumpSurface(tester, phoneEn, host(false), settle: Duration.zero);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(
        seen.every((v) => v == 0),
        isTrue,
        reason: 'the beat advanced while its route was covered',
      );

      // Uncovered: a muted ticker keeps time, so the beat that was due while
      // hidden has already run out — it lands on the invisible resting value
      // at once instead of replaying a stale pulse…
      await pumpSurface(tester, phoneEn, host(true), settle: Duration.zero);
      await tester.pump(_frame);
      expect(seen.last, closeTo(1, 0.001));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // …and the normal rhythm picks up after one rest.
      await tester.pump(_rest + _frame);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle(_frame);
      expect(_restarts(seen), 1);
    });

    testWidgets('removed mid-beat, it leaves no ticker or timer behind', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _pulse(), settle: Duration.zero);
      await _frames(tester, const Duration(milliseconds: 64));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a zero rest beats back to back and still disposes cleanly', (
      tester,
    ) async {
      final seen = <double>[];
      await pumpSurface(
        tester,
        phoneEn,
        _pulse(rest: Duration.zero, onBeat: seen.add),
        settle: Duration.zero,
      );
      await _frames(tester, _period * 4);
      expect(_restarts(seen), greaterThanOrEqualTo(3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the default rhythm is 1.1s on, 1.9s off', (tester) async {
      late Animation<double> beat;
      await pumpSurface(
        tester,
        phoneEn,
        AmbientPulse(
          builder: (context, a) {
            beat = a;
            return _halo(context, a);
          },
        ),
        settle: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 1099));
      expect(beat.status, AnimationStatus.forward);
      await tester.pump(const Duration(milliseconds: 1));
      expect(beat.value, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(beat.status, AnimationStatus.completed);

      await tester.pump(const Duration(milliseconds: 1899));
      expect(beat.status, AnimationStatus.completed);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(beat.status, AnimationStatus.forward);
      expect(beat.value, 0);
    });
  });
}
