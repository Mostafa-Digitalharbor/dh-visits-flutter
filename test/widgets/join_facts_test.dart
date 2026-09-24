import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/extensions/context_extensions.dart';

import 'widget_harness.dart';

const _fsi = '\u2068';
const _pdi = '\u2069';

Future<String> _join(
  WidgetTester tester,
  Surface surface,
  List<String?> parts,
) async {
  late String joined;
  await pumpSurface(
    tester,
    surface,
    Builder(builder: (context) {
      joined = context.joinFacts(parts);
      return const SizedBox.shrink();
    }),
  );
  return joined;
}

void main() {
  setUpAll(initHarness);

  group('bidiIsolateIfForeign', () {
    test('isolates Latin text on a right-to-left screen', () {
      expect(bidiIsolateIfForeign('Acme Rollout', rtl: true),
          '${_fsi}Acme Rollout$_pdi');
    });

    test('isolates Arabic text on a left-to-right screen', () {
      expect(bidiIsolateIfForeign('الرياض', rtl: false), '$_fsiالرياض$_pdi');
    });

    test('leaves same-script text and bare numbers alone', () {
      expect(bidiIsolateIfForeign('مشروع', rtl: true), 'مشروع');
      expect(bidiIsolateIfForeign('Project', rtl: false), 'Project');
      expect(bidiIsolateIfForeign('17:05', rtl: true), '17:05');
      expect(bidiIsolateIfForeign('17:05', rtl: false), '17:05');
    });
  });

  group('joinFacts', () {
    testWidgets('skips null and blank parts, trims the rest', (tester) async {
      final t = l10n(english);
      expect(
        await _join(tester, phoneEn, [null, '  Project ', '', '   ', 'VIS/7']),
        'Project${t.commonListSeparator}VIS/7',
      );
      expect(await _join(tester, phoneEn, [null, '']), '');
    });

    testWidgets('an English part on an Arabic screen is isolated',
        (tester) async {
      final t = l10n(arabic);
      expect(
        await _join(tester, phoneAr, [t.wfTypeProject, 'Acme Rollout']),
        '${t.wfTypeProject}${t.commonListSeparator}${_fsi}Acme Rollout$_pdi',
      );
    });

    testWidgets('an Arabic part on an English screen is isolated',
        (tester) async {
      final t = l10n(english);
      expect(
        await _join(tester, phoneEn, [t.wfTypeProject, 'مشروع البرج']),
        '${t.wfTypeProject}${t.commonListSeparator}$_fsiمشروع البرج$_pdi',
      );
    });

    testWidgets('the joined line renders in both languages', (tester) async {
      for (final s in [phoneEn, phoneAr]) {
        await pumpSurface(
          tester,
          s,
          Builder(
            builder: (context) => Text(
              context.joinFacts([
                LongText.english,
                LongText.arabicCompany,
                '12:30',
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
        expectCleanLayout(tester);
      }
    });
  });
}
