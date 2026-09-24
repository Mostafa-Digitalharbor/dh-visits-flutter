import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/auto_direction_text.dart';

import 'widget_harness.dart';

Text _text(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

void main() {
  setUpAll(initHarness);

  group('direction comes from the words', () {
    test('Latin text with leading punctuation reads left to right', () {
      expect(AutoDirectionText.directionOf('[QA-AUTO] E2E emulator GPS run'),
          TextDirection.ltr);
    });

    test('Arabic text with a plus code and digits reads right to left', () {
      expect(
        AutoDirectionText.directionOf(
            'PM7F+GW4، الورود، الرياض 12215، السعودية'),
        TextDirection.rtl,
      );
    });

    test('text without letters falls back to left to right', () {
      expect(AutoDirectionText.directionOf('24.71810, 46.67800'),
          TextDirection.ltr);
      expect(AutoDirectionText.directionOf(''), TextDirection.ltr);
    });
  });

  group('layout', () {
    testWidgets('an English purpose keeps its order on an Arabic screen',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        const AutoDirectionText('[QA-AUTO] E2E run'),
      );
      final text = _text(tester);
      expect(text.textDirection, TextDirection.ltr);
      // Still hugs the start edge of the Arabic layout.
      expect(text.textAlign, TextAlign.right);
    });

    testWidgets('an Arabic address keeps its order on an English screen',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AutoDirectionText('الورود، الرياض 12215، السعودية'),
      );
      final text = _text(tester);
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textAlign, TextAlign.left);
    });

    testWidgets('an explicit alignment wins', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        const AutoDirectionText('Acme', textAlign: TextAlign.center),
      );
      expect(_text(tester).textAlign, TextAlign.center);
    });

    testWidgets('style, lines and overflow are passed through', (tester) async {
      const style = TextStyle(fontSize: 13);
      await pumpSurface(
        tester,
        phoneEn,
        const AutoDirectionText(
          'Acme',
          style: style,
          maxLines: 2,
          overflow: TextOverflow.fade,
        ),
      );
      final text = _text(tester);
      expect(text.style, style);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.fade);
    });

    testOnEverySurface(
      'long mixed-language text ellipsizes inside a row',
      (s) => Row(
        children: [
          const Icon(Icons.flag_outlined),
          Expanded(
            child: AutoDirectionText(
              '${LongText.english} ${LongText.arabicCompany}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  });
}
