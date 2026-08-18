// Locks in the conventions the codebase was just swept for, so they hold by
// default instead of by vigilance.
//
// These are source-scanning tests, which is unusual — but each one guards a
// rule that is invisible at runtime until it has already shipped:
//
//   * A missing Arabic string renders the *English* one to an Arabic user. No
//     test fails, no exception is thrown; it just looks like a translation
//     nobody got round to.
//   * A hard-coded `assets/...` path fails as a blank image at runtime, on the
//     one screen nobody reopened after the rename.
//   * A raw `SizedBox(height: 12)` is invisible until it meets a 320dp screen
//     at 1.25× text scale — and overflow only asserts in debug, so release
//     builds clip it silently.
//
// Each failure message names the fix, so a contributor who trips one does not
// have to reverse-engineer the intent from the assertion.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file under `lib/`, excluding generated output.
List<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.replaceAll(r'\', '/').contains('/l10n/generated/'))
    .toList();

String _rel(File f) => f.path.replaceAll(r'\', '/');

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Message keys only — `@`-prefixed entries are translator metadata and live
/// in the template file alone.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  group('localization', () {
    final en = _arb('lib/l10n/app_en.arb');
    final ar = _arb('lib/l10n/app_ar.arb');

    test('every English string has an Arabic counterpart', () {
      final missing = _messageKeys(en).difference(_messageKeys(ar)).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason: 'Add these keys to lib/l10n/app_ar.arb. Until then an Arabic '
            'user sees the English text with no visible sign anything is '
            'wrong.',
      );
    });

    test('Arabic carries no keys English has dropped', () {
      final orphaned = _messageKeys(ar).difference(_messageKeys(en)).toList()
        ..sort();
      expect(
        orphaned,
        isEmpty,
        reason: 'These exist only in app_ar.arb. app_en.arb is the template, '
            'so they generate no getter and are dead weight — delete them, or '
            'add the English side if the string is still used.',
      );
    });

    test('no message is left as an empty string', () {
      final blank = <String>[];
      for (final arb in [en, ar]) {
        for (final k in _messageKeys(arb)) {
          if ((arb[k] as String).trim().isEmpty) blank.add(k);
        }
      }
      expect(blank, isEmpty,
          reason: 'An empty ARB value renders as nothing at all, which reads '
              'as a broken screen rather than a missing translation.');
    });
  });

  group('design tokens', () {
    test('asset paths are only written in AppAssets', () {
      final offenders = [
        for (final f in _libSources())
          if (!_rel(f).endsWith('app_assets.dart') &&
              f.readAsStringSync().contains("'assets/"))
            _rel(f),
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'Reference AppAssets instead. A literal path survives a file '
            'rename and fails as a blank image at runtime, where the constant '
            'would have failed at compile time.',
      );
    });

    test('gaps use the responsive Insets scale, not raw dp', () {
      // Matches `SizedBox(height: 12)` / `SizedBox(width: 8)` — a bare number.
      // `SizedBox(height: Insets.x3)` and `SizedBox.shrink()` both pass.
      final rawGap = RegExp(r'SizedBox\(\s*(width|height):\s*[0-9]');
      final offenders = <String>[];
      for (final f in _libSources()) {
        final lines = f.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (rawGap.hasMatch(lines[i])) {
            offenders.add('${_rel(f)}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Use context.gapH(Insets.x3) / context.gapW(Insets.x2) so the '
            'gap scales with the device, or a named const if it is a component '
            'size rather than a gap. See lib/app/design/app_dimens.dart.',
      );
    });

    test('user-facing text comes from the ARBs, never a literal', () {
      // A quoted string handed straight to Text(). Interpolations are excluded
      // — `Text('$count')` is a formatted value, not a phrase to translate.
      final literal =
          RegExp('''Text\\(\\s*(const\\s*)?['"][A-Za-z\\u0600-\\u06FF][^'"\\\$]{2,}['"]''');
      final offenders = <String>[];
      for (final f in _libSources()) {
        final lines = f.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) {
            offenders.add('${_rel(f)}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Add the string to lib/l10n/app_en.arb + app_ar.arb and read '
            'it via context.s. A literal here ships untranslated to half the '
            'users and never shows up as a failure.',
      );
    });
  });
}
