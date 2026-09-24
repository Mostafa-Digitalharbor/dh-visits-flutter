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

    test('every message is read somewhere in lib/', () {
      final code = _libSources().map((f) => f.readAsStringSync()).join('\n');
      final dead = [
        for (final k in _messageKeys(en))
          if (!RegExp('\\.$k\\b').hasMatch(code)) k,
      ]..sort();
      expect(
        dead,
        isEmpty,
        reason: 'Nothing reads these keys any more — delete them from both ARB '
            'files with tool/arb_edit.mjs. Dead strings still get translated '
            'and reviewed, and 214 of them had piled up before this check.',
      );
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

    test('responsive sizes are tokens, not raw numbers', () {
      // `context.r(130)` scales, but nobody can tell what 130 is or find the
      // other places that must match it. `context.r(CompSz.emptyHalo)` can.
      final rawSize = RegExp(
        r'context\.(r|rh|fixedH|gapH|gapW|padAll)\(\s*[0-9]',
      );
      final offenders = <String>[];
      for (final f in _libSources()) {
        final lines = f.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (rawSize.hasMatch(lines[i])) {
            offenders.add('${_rel(f)}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Name the size in lib/app/design/app_dimens.dart (Insets, '
            'IconSz, CompSz) and pass the token.',
      );
    });

    test('user-facing text comes from the ARBs, never a literal', () {
      // A quoted string handed straight to Text(). Interpolations are excluded
      // — `Text('$count')` is a formatted value, not a phrase to translate.
      final literal =
          RegExp('''Text\\(\\s*(const\\s*)?['"][A-Za-z\\u0600-\\u06FF][^'"\\\$]{2,}['"]''');
      expect(
        _scan(literal),
        isEmpty,
        reason: 'Add the string to lib/l10n/app_en.arb + app_ar.arb and read '
            'it via context.s. A literal here ships untranslated to half the '
            'users and never shows up as a failure.',
      );
    });

    // The check above only sees `Text('...')` written on one line. dart format
    // moves a long argument onto its own line, at which point the same
    // untranslated literal walks straight past it.
    test('a literal on its own line is caught too', () {
      final offenders = <String>[];
      final opensText = RegExp(r'\bText\(\s*$');
      final bareLiteral = RegExp(
        r'''^(const\s*)?['"][A-Za-z\u0600-\u06FF][^'"$]{2,}['"],?$''',
      );
      for (final f in _libSources()) {
        final lines = f.readAsStringSync().split('\n');
        for (var i = 0; i + 1 < lines.length; i++) {
          if (opensText.hasMatch(lines[i]) &&
              bareLiteral.hasMatch(lines[i + 1].trim())) {
            offenders.add('${_rel(f)}:${i + 2}  ${lines[i + 1].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'Same rule as above: this string reaches the screen '
              'untranslated. Move it to the ARBs and read it via context.s.');
    });

    // Text() is not the only way a phrase reaches a user. A hint, a tooltip or
    // a validation message is shown on screen — and read aloud by TalkBack —
    // just the same, and none are covered by the Text() checks.
    test('hints, labels and tooltips come from the ARBs too', () {
      final uiString = RegExp(
        r'(hintText|labelText|helperText|errorText|tooltip|semanticsLabel|'
        r'counterText|prefixText|suffixText):\s*'
        r'''(const\s*)?['"][A-Za-z\u0600-\u06FF][^'"$]{2,}['"]''',
      );
      expect(
        _scan(uiString),
        isEmpty,
        reason: 'These render on screen (or to a screen reader) exactly like '
            'Text does. Read them from context.s.',
      );
    });

    // The Insets check only matches SizedBox. Padding, margins and radii are
    // the other half of the spacing system, and a raw number there is the same
    // bug: fixed at 390dp, clipped at 320dp and 1.25x text.
    test('padding and radii use the design tokens, not raw dp', () {
      final rawInset = RegExp(
        r'(EdgeInsets|EdgeInsetsDirectional)'
        r'\.(all|symmetric|only|fromLTRB|fromSTEB)\([^)]*?\b\d',
      );
      final rawRadius =
          RegExp(r'(BorderRadius\.circular|Radius\.circular)\(\s*\d');
      expect(
        [
          for (final o in [..._scan(rawInset), ..._scan(rawRadius)])
            // A `static const _badgePadding = EdgeInsets...` is the fix this
            // rule asks for, not a violation of it: the number is named, in
            // one place, next to the comment explaining it. The sibling
            // SizedBox rule says the same in its own failure message. Only
            // numbers inlined at a call site are flagged.
            if (!_declaresAConst(o)) o,
        ],
        isEmpty,
        reason: 'Name the value in lib/app/design/app_dimens.dart (Insets, '
            'Radii) and pass the token — context.padAll(Insets.x4), '
            'BorderRadius.circular(Radii.sm). A component-specific value may '
            'instead be a named const beside the widget that uses it.',
      );
    });

    // An icon's size is spacing too: a raw 22 next to a 1.25x-scaled label is
    // how a row ends up with a glyph that no longer matches its text.
    test('icon sizes are IconSz tokens, not raw numbers', () {
      final rawIcon = RegExp(r'\bIcon\((?:[^()]|\([^()]*\))*\bsize:\s*\d');
      expect(
        [
          for (final o in _scan(rawIcon))
            if (!_declaresAConst(o)) o,
        ],
        isEmpty,
        reason: 'Use context.r(IconSz.label) and friends — see '
            'lib/app/design/app_dimens.dart for the ladder.',
      );
    });

    // A URL is configuration, not code. One written inline is invisible to
    // whoever has to repoint the app at a different tile server or licence
    // page, and cannot be varied per build flavor.
    test('URLs live in the constants / config layer', () {
      final offenders = [
        for (final o in _scan(RegExp(r"'https?://")))
          if (!o.startsWith('lib/core/constants') &&
              !o.startsWith('lib/core/config') &&
              !o.startsWith('lib/firebase_options.dart') &&
              // Completes a user-typed host into a URL; not an address.
              !o.startsWith('lib/core/utils/communications.dart'))
            o,
      ];
      expect(offenders, isEmpty,
          reason: 'Add it to lib/core/constants.dart (or the config layer) so '
              'it can be found and changed in one place.');
    });

    // Odoo model and route names are the wire contract with the backend. A
    // literal copy drifts when the module renames one, and the failure lands
    // at runtime on whichever screen nobody reopened.
    test('Odoo model and route names are named constants', () {
      final model = RegExp(
        r"'(res\.partner|res\.users|res\.groups|res\.partner\.category"
        r"|dh\.visit|dh\.visit\.participant|project\.project|crm\.lead"
        r"|ir\.attachment|mail\.activity|mail\.message|x_dh_work_\w+)'",
      );
      final route = RegExp(r"'/(api|web)/[a-z_/]+'");
      final offenders = [
        for (final o in [..._scan(model), ..._scan(route)])
          if (!o.startsWith('lib/core/constants') &&
              !o.startsWith('lib/core/api/endpoints.dart'))
            o,
      ];
      expect(offenders, isEmpty,
          reason: 'Add the model to AppConstants and the route to Endpoints. '
              'Both are the backend contract and belong in one place.');
    });
  });
}

/// Whether [offender] (a `path:line  source` row from [_scan]) is a named
/// constant *declaration* rather than a value inlined at a call site.
bool _declaresAConst(String offender) =>
    RegExp(r'\b(static\s+)?const\s+\w+\s*=').hasMatch(offender);

/// Every `lib/` line matching [pattern], as `path:line  source`.
///
/// Line-by-line rather than whole-file so a failure names the place to fix
/// instead of only the file — the difference between a check someone acts on
/// and one they suppress.
List<String> _scan(RegExp pattern) {
  final offenders = <String>[];
  for (final f in _libSources()) {
    final lines = f.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      // Comments and doc comments talk *about* these names; only code counts.
      final trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
      if (pattern.hasMatch(lines[i])) {
        offenders.add('${_rel(f)}:${i + 1}  ${lines[i].trim()}');
      }
    }
  }
  return offenders;
}
