import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/initial_avatar.dart';

import 'widget_harness.dart';

const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

Finder get _avatar => find.byType(InitialAvatar);

BoxDecoration _decoration(WidgetTester tester, [int index = 0]) =>
    tester
        .widget<Container>(find
            .descendant(of: _avatar.at(index), matching: find.byType(Container))
            .first)
        .decoration! as BoxDecoration;

/// Avatars sit in rows with a fixed slot; a Center gives them loose room.
Widget _one(InitialAvatar avatar) => Center(child: avatar);

void main() {
  setUpAll(initHarness);

  group('InitialAvatar.initialOf', () {
    const cases = <(String?, String, String)>[
      ('mostafa', 'M', 'lowercase Latin is uppercased'),
      ('Mostafa Ali', 'M', 'only the first letter'),
      ('  ahmed  ', 'A', 'leading whitespace is skipped'),
      ('\n\tsara', 'S', 'tabs and newlines are whitespace too'),
      ('عبد الرحمن', 'ع', 'Arabic has no case and is kept'),
      ('أحمد', 'أ', 'alef with hamza is one letter'),
      ('إبراهيم', 'إ', 'alef with hamza below is one letter'),
      ('عَلي', 'عَ', 'a letter keeps its diacritic (one grapheme)'),
      ('  ليلى', 'ل', 'Arabic with leading spaces'),
      ('3M Company', '3', 'a leading digit is shown as is'),
      ('ölaf', 'Ö', 'precomposed accents are uppercased'),
      ('élodie', 'É', 'combining accents stay with the letter'),
      // A letter beats a decorative emoji: the circle is 28-72dp, and 'S'
      // identifies Sara where a briefcase does not.
      ('👩‍💼 Sara', 'S', 'a leading emoji is skipped for the name'),
      ('👩‍💼', '👩‍💼',
          'an emoji-only name keeps the emoji, as one grapheme'),
      ('istanbul', 'I', 'no locale-specific casing'),
      // The live server's own QA account. Character zero used to be taken as
      // the initial, so the avatar read '[' — and RTL bidi mirrored it to ']'.
      ('[QA-AUTO] Workday Tester', 'Q', 'a tag prefix does not become the initial'),
      ('(Acme) Ltd', 'A', 'a leading bracket is skipped'),
      ('-Ahmed', 'A', 'a leading dash is skipped'),
      ('"محمد"', 'م', 'quotes around an Arabic name are skipped'),
      ('...', '?', 'punctuation only has no initial'),
      ('', '?', 'empty'),
      ('   ', '?', 'whitespace only'),
      ('  ', '?', 'non-breaking and em spaces only'),
      (null, '?', 'null'),
    ];
    for (final (name, initial, why) in cases) {
      test('${name == null ? 'null' : '"$name"'} → "$initial" ($why)', () {
        expect(InitialAvatar.initialOf(name), initial);
      });
    }

    test('never throws on any single code unit', () {
      for (var unit = 0; unit < 0x3000; unit += 7) {
        expect(
          () => InitialAvatar.initialOf(String.fromCharCode(unit)),
          returnsNormally,
        );
      }
    });
  });

  group('InitialAvatar layout', () {
    testOnEverySurface(
      'a row of avatars from 16dp to 72dp with long and missing names',
      (s) => Row(
        children: [
          const InitialAvatar(name: LongText.arabicPerson, size: 16),
          const InitialAvatar(name: 'mostafa', size: 28),
          InitialAvatar(name: LongText.of(s)),
          const InitialAvatar(name: null, size: CompSz.avatarSm),
          const InitialAvatar(
              name: 'x', icon: Icons.business, size: CompSz.avatarHero),
          const InitialAvatar(
            name: '   ',
            size: CompSz.mapPin,
            borderColor: Colors.white,
            borderWidth: CompSz.mapPinRing,
          ),
        ],
      ),
      verify: (tester, s) async {
        const sizes = [16.0, 28.0, 44.0, 42.0, 72.0, 42.0];
        for (var i = 0; i < sizes.length; i++) {
          expect(tester.getSize(_avatar.at(i)), Size.square(sizes[i]));
        }
        expect(find.text('?'), findsNWidgets(2));
      },
    );
  });

  group('InitialAvatar content', () {
    for (final (s, name, initial) in [
      (phoneEn, 'Sara Hassan', 'S'),
      (phoneAr, 'سارة حسن', 'س'),
    ]) {
      testWidgets('shows the initial of "$name" — $s', (tester) async {
        await pumpSurface(tester, s, _one(InitialAvatar(name: name)));
        expect(find.text(initial), findsOneWidget);
        expect(find.text(name), findsNothing);
      });
    }

    testWidgets('the default is a 44dp circle', (tester) async {
      await pumpSurface(tester, phoneEn, _one(const InitialAvatar(name: 'a')));
      expect(tester.getSize(_avatar), const Size.square(CompSz.avatar));
      expect(_decoration(tester).shape, BoxShape.circle);
      expect(tester.getCenter(find.text('A')),
          offsetMoreOrLessEquals(tester.getCenter(_avatar)));
    });

    for (final size in [28.0, 44.0, 72.0]) {
      testWidgets('the letter is 38% of a ${size}dp avatar', (tester) async {
        await pumpSurface(
            tester, phoneEn, _one(InitialAvatar(name: 'a', size: size)));
        final style = tester.widget<Text>(find.text('A')).style!;
        expect(style.fontSize, moreOrLessEquals(size * 0.38));
        expect(style.fontWeight, FontWeight.w700);
      });
    }

    testWidgets('an icon replaces the letter at half the size',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _one(const InitialAvatar(
          name: 'Acme',
          icon: Icons.apartment,
          size: 60,
          foreground: Colors.amber,
        )),
      );
      expect(find.text('A'), findsNothing);
      final icon = tester.widget<Icon>(find.byIcon(Icons.apartment));
      expect(icon.size, 30);
      expect(icon.color, Colors.amber);
    });

    testWidgets('an icon needs no name', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _one(const InitialAvatar(name: null, icon: Icons.person)),
      );
      expect(find.text('?'), findsNothing);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('the foreground colours the letter', (tester) async {
      await pumpSurface(tester, phoneEn,
          _one(const InitialAvatar(name: 'a', foreground: Colors.black)));
      expect(tester.widget<Text>(find.text('A')).style!.color, Colors.black);
    });

    testWidgets('the default foreground is white', (tester) async {
      await pumpSurface(tester, phoneEn, _one(const InitialAvatar(name: 'a')));
      expect(tester.widget<Text>(find.text('A')).style!.color, Colors.white);
    });

    testWidgets('a name that changes updates the letter', (tester) async {
      await pumpSurface(tester, phoneEn, _one(const InitialAvatar(name: 'a')));
      await pumpSurface(tester, phoneEn, _one(const InitialAvatar(name: 'b')));
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('a tiny avatar at 1.25× text still lays out', (tester) async {
      await pumpSurface(
        tester,
        surfaces.first,
        _one(const InitialAvatar(name: 'ع', size: 12)),
      );
      expectCleanLayout(tester);
      expect(tester.getSize(_avatar), const Size.square(12));
    });
  });

  group('InitialAvatar fill and border', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('without a background it uses the theme gradient — $s',
          (tester) async {
        await pumpSurface(tester, s, _one(const InitialAvatar(name: 'a')));
        final context = tester.element(_avatar);
        expect(Theme.of(context).brightness, s.brightness);
        final d = _decoration(tester);
        expect(d.gradient, context.x.avatarGradient);
        expect(d.color, isNull);
      });
    }

    testWidgets('light and dark gradients differ', (tester) async {
      await pumpSurface(tester, phoneEn, _one(const InitialAvatar(name: 'a')));
      final light = _decoration(tester).gradient;
      await pumpSurface(
          tester, _phoneArDark, _one(const InitialAvatar(name: 'a')));
      expect(_decoration(tester).gradient, isNot(light));
    });

    testWidgets('a custom gradient replaces the theme one', (tester) async {
      const gradient = LinearGradient(colors: [Colors.red, Colors.blue]);
      await pumpSurface(tester, phoneEn,
          _one(const InitialAvatar(name: 'a', gradient: gradient)));
      expect(_decoration(tester).gradient, gradient);
    });

    testWidgets('a background wins over any gradient', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _one(const InitialAvatar(
          name: 'a',
          background: Colors.green,
          gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
        )),
      );
      final d = _decoration(tester);
      expect(d.color, Colors.green);
      expect(d.gradient, isNull);
    });

    testWidgets('no border by default', (tester) async {
      await pumpSurface(tester, phoneEn, _one(const InitialAvatar(name: 'a')));
      expect(_decoration(tester).border, isNull);
    });

    testWidgets('a border width draws a white ring by default',
        (tester) async {
      await pumpSurface(tester, phoneEn,
          _one(const InitialAvatar(name: 'a', borderWidth: 2.5)));
      final border = _decoration(tester).border! as Border;
      expect(border.top.color, Colors.white);
      expect(border.top.width, 2.5);
      // The ring is inside the size, not added to it.
      expect(tester.getSize(_avatar), const Size.square(CompSz.avatar));
    });

    testWidgets('a border colour is honoured', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _one(const InitialAvatar(
            name: 'a', borderWidth: 1, borderColor: Colors.black)),
      );
      expect((_decoration(tester).border! as Border).top.color, Colors.black);
    });

    testWidgets('a border colour without a width draws nothing',
        (tester) async {
      await pumpSurface(tester, phoneEn,
          _one(const InitialAvatar(name: 'a', borderColor: Colors.black)));
      expect(_decoration(tester).border, isNull);
    });

    testWidgets('the shadow is passed through', (tester) async {
      const shadow = [BoxShadow(blurRadius: 4, color: Colors.black26)];
      await pumpSurface(tester, phoneEn,
          _one(const InitialAvatar(name: 'a', shadow: shadow)));
      expect(_decoration(tester).boxShadow, shadow);
    });
  });
}
