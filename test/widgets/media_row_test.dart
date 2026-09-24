// MediaRow is the layout seven screens used to hand-write, so what it
// guarantees has to hold on the surfaces those screens ship to: the text takes
// the width left over, a long value ellipsizes or wraps *inside* the row
// instead of pushing the trailing widget off the edge, and the row survives
// Arabic at the app's 1.25x text-scale ceiling on a 320dp phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/media_row.dart';

import 'widget_harness.dart';

/// A token with no break opportunities — the case that overflows a Row.
final _unbreakable = 'A' * 220;

/// A trailing widget wide enough to squeeze the text column on a 320dp phone
/// without being wide enough to leave it nothing.
const double _wideTrailing = 120.0;

Finder get _row => find.byType(MediaRow);

/// A fixed-size stand-in for the badge / avatar every caller passes.
Widget get _badge => const SizedBox.square(dimension: CompSz.badge);

Widget _sample(
  Surface s, {
  Widget? trailing,
  double? trailingGap,
  CrossAxisAlignment alignment = CrossAxisAlignment.center,
  String? primary,
}) =>
    Padding(
      padding: const EdgeInsets.all(Insets.x4),
      child: MediaRow(
        leading: _badge,
        trailing: trailing,
        trailingGap: trailingGap,
        alignment: alignment,
        lines: [
          Text(primary ?? LongText.of(s),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(LongText.arabicPerson,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );

void main() {
  setUpAll(initHarness);

  group('layout', () {
    testOnEverySurface(
      'long two-line text beside a badge fits',
      _sample,
    );

    testOnEverySurface(
      'an unbreakable token does not push the trailing widget off screen',
      (s) => _sample(s,
          primary: _unbreakable,
          trailing: const Icon(Icons.chevron_right)),
      verify: (tester, s) async {
        // The real assertion is expectCleanLayout, which testOnEverySurface
        // runs either side of this. This pins down *why* it holds: the
        // trailing icon is still inside the row's own box.
        final row = tester.getRect(_row);
        final icon = tester.getRect(find.byType(Icon));
        expect(icon.left, greaterThanOrEqualTo(row.left - _epsilon));
        expect(icon.right, lessThanOrEqualTo(row.right + _epsilon));
      },
    );

    testOnEverySurface(
      'a wide trailing widget still leaves the text a share of the row',
      (s) => _sample(s,
          trailing: const SizedBox(width: _wideTrailing, height: 1)),
      verify: (tester, s) async {
        // Expanded gives the text whatever is left; the point is that it is
        // never zero, which would render the row as badge + blank + trailing.
        expect(tester.getSize(find.text(LongText.arabicPerson)).width,
            greaterThan(0));
      },
    );

    testOnEverySurface(
      'start alignment keeps the badge level with the first line',
      (s) => _sample(s, alignment: CrossAxisAlignment.start),
      verify: (tester, s) async {
        // The badge's top meets the row's top instead of being centred
        // against two lines of text — which is what callers with a wrapping
        // title ask for by passing CrossAxisAlignment.start.
        expect(
          tester.getRect(find.byType(SizedBox).first).top,
          closeTo(tester.getRect(_row).top, _slack),
        );
      },
    );
  });

  group('trailing', () {
    testWidgets('is absent from the tree when null', (tester) async {
      await pumpSurface(tester, phoneEn, _sample(phoneEn));
      // Only the leading badge — no trailing slot, and no gap widget for one.
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders when given', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _sample(phoneEn, trailing: const Icon(Icons.chevron_right)),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('trailingGap of none adds no space before the trailing widget',
        (tester) async {
      const key = Key('trailing');
      await pumpSurface(
        tester,
        phoneEn,
        _sample(
          phoneEn,
          trailing: const SizedBox.square(dimension: IconSz.sm, key: key),
          trailingGap: Insets.none,
        ),
      );
      final text = tester.getRect(find.text(LongText.arabicPerson));
      final trailing = tester.getRect(find.byKey(key));
      // Directionality-agnostic: on an English screen the trailing sits to the
      // right of the text column, on Arabic to its left. Either way the two
      // touch, because the gap is zero.
      final gap = trailing.left >= text.right
          ? trailing.left - text.right
          : text.left - trailing.right;
      expect(gap, lessThan(Insets.x1));
    });
  });

  group('lines', () {
    testWidgets('an empty lines list still lays out', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        MediaRow(leading: _badge, lines: const []),
      );
      expectCleanLayout(tester);
    });

    testWidgets('a single line lays out', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        MediaRow(leading: _badge, lines: const [Text('one')]),
      );
      expectCleanLayout(tester);
      expect(find.text('one'), findsOneWidget);
    });
  });
}

/// Sub-pixel tolerance for a rect comparison after responsive scaling.
const double _epsilon = 0.5;
const double _slack = 1.0;
