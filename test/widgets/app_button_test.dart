import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/app_button.dart';

import 'widget_harness.dart';

void main() {
  setUpAll(initHarness);

  group('AppButton layout', () {
    for (final variant in AppButtonVariant.values) {
      testOnEverySurface(
        '${variant.name} with a long label and an icon fits',
        (s) => Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: LongText.of(s),
            icon: Icons.play_arrow_rounded,
            variant: variant,
            onPressed: () {},
          ),
        ),
        verify: (tester, _) async {
          // Two lines at most, then an ellipsis — never clipped mid-glyph.
          final text = tester.widget<Text>(find.byType(Text));
          expect(text.maxLines, 2);
          expect(text.overflow, TextOverflow.ellipsis);
        },
      );
    }

    testOnEverySurface(
      'side-by-side buttons that are not full width fit a row',
      (s) => Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              label: l10n(s.locale).commonCancel,
              onPressed: () {},
            ),
          ),
          Expanded(
            child: AppButton(
              label: l10n(s.locale).wfActionSubmit,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  });

  group('AppButton behaviour', () {
    testWidgets('fires onPressed once per tap', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        AppButton(label: 'Go', onPressed: () => taps++),
      );
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('loading shows a spinner, hides the label and ignores taps',
        (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        AppButton(label: 'Go', loading: true, onPressed: () => taps++),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('a null onPressed renders disabled', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AppButton(label: 'Go', onPressed: null),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('destructive uses the error colour', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        AppButton.destructive(label: 'Delete', onPressed: () {}),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final context = tester.element(find.byType(FilledButton));
      expect(
        button.style?.backgroundColor?.resolve({}),
        Theme.of(context).colorScheme.error,
      );
    });

    testWidgets('secondary is an outlined button', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        AppButton.secondary(label: 'Back', onPressed: () {}),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('fullWidth stretches to the available width', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: SizedBox(
            width: 300,
            child: Column(
              children: [
                AppButton(key: const Key('wide'), label: 'A', onPressed: () {}),
                AppButton(
                  key: const Key('narrow'),
                  label: 'A',
                  fullWidth: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('wide'))).width, 300);
      expect(
        tester.getSize(find.byKey(const Key('narrow'))).width,
        lessThan(300),
      );
    });
  });
}
