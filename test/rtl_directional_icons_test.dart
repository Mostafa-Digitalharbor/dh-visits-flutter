// Directional icons on an Arabic screen.
//
// Some of Flutter's directional glyphs are declared
// `matchTextDirection: true`, so the *framework* mirrors them under RTL.
// Anything that also picks the mirrored name by hand —
// `isRtl ? chevron_left : chevron_right` — flips such an icon twice, and it
// ends up pointing back out of the screen it opens.
//
// This shipped on the create-visit pickers: the chevron pointed right on an
// Arabic screen while every other row in the app pointed left. Nothing failed,
// no exception was thrown, and it is invisible in an English build — which is
// why this is a test rather than a thing to remember.
//
// Crucially, the rule only applies to the icons Flutter actually mirrors.
// `Icons.keyboard_arrow_right` is *not* one of them, and neither is anything
// from material_symbols_icons — for those a hand-written conditional is the
// correct answer. So the list is derived from each icon's real
// `matchTextDirection` at run time rather than written out here, and cannot
// drift from the SDK.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every Dart file under `lib/`, excluding generated output.
List<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.replaceAll(r'\', '/').contains('/l10n/generated/'))
    .toList();

/// The directional `Icons.*` a screen might plausibly reach for, paired with
/// the constant itself so the test can ask whether Flutter mirrors it.
const _directional = <String, IconData>{
  'chevron_right': Icons.chevron_right,
  'chevron_left': Icons.chevron_left,
  'arrow_back': Icons.arrow_back,
  'arrow_forward': Icons.arrow_forward,
  'arrow_back_ios': Icons.arrow_back_ios,
  'arrow_forward_ios': Icons.arrow_forward_ios,
  'arrow_back_ios_new': Icons.arrow_back_ios_new,
  'arrow_right': Icons.arrow_right,
  'arrow_left': Icons.arrow_left,
  'keyboard_arrow_right': Icons.keyboard_arrow_right,
  'keyboard_arrow_left': Icons.keyboard_arrow_left,
  'keyboard_double_arrow_right': Icons.keyboard_double_arrow_right,
  'keyboard_double_arrow_left': Icons.keyboard_double_arrow_left,
  'navigate_next': Icons.navigate_next,
  'navigate_before': Icons.navigate_before,
};

/// The subset this SDK mirrors for us — the only ones the rule covers.
Iterable<String> get _selfMirroring => _directional.entries
    .where((e) => e.value.matchTextDirection)
    .map((e) => e.key);

void main() {
  test('the SDK still mirrors some directional icons', () {
    // If a Flutter upgrade stopped mirroring all of them the rule below would
    // silently cover nothing, and pass forever while the bug came back.
    expect(_selfMirroring, isNotEmpty,
        reason: 'No Icons.* reports matchTextDirection any more. Either the '
            'names in _directional are stale, or Flutter changed its policy '
            'and this whole rule needs re-deriving.');
  });

  test('no screen picks a self-mirroring icon by hand', () {
    final names = _selfMirroring.join('|');
    // A direction test whose branches name one of the mirrored icons.
    final doubleFlip = RegExp(
      r'(isRtl|isRTL|TextDirection\.rtl)[^;]{0,160}?\bIcons\.(' + names + r')\b',
    );
    final offenders = <String>[];
    for (final f in _libSources()) {
      // Flattened, so a conditional that dart format broke across lines is
      // still seen as one expression. Comment lines discuss this very rule, so
      // they are dropped rather than scanned.
      final flat = f
          .readAsStringSync()
          .split('\n')
          .map((l) {
            final t = l.trimLeft();
            return (t.startsWith('//') || t.startsWith('*')) ? '' : l.trim();
          })
          .join(' ');
      if (doubleFlip.hasMatch(flat)) {
        offenders.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Drop the conditional and name the forward-pointing icon alone '
          '(Icons.chevron_right, Icons.arrow_back): the framework mirrors it '
          'under RTL, so naming the mirrored one for Arabic flips it twice.\n'
          'Mirrored in this SDK: $names.\n'
          'Icons.keyboard_arrow_* and every material_symbols_icons glyph do '
          'NOT mirror themselves — a conditional is right for those.',
    );
  });
}
