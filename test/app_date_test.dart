// Guards the rule that dates follow the app's language, not the device's.
//
// `DateFormat` with no locale resolves via `Intl.defaultLocale`, which the
// app never sets — so symbolic patterns (MMM / EEE) rendered English month
// and weekday names inside an otherwise Arabic UI. [AppDate] threads the
// active Localizations locale through instead.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:location_gps/core/utils/app_date.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';

/// Runs [format] inside a Localizations scope for [locale], mirroring how a
/// widget would call it.
Future<String> formatIn(
  WidgetTester tester,
  Locale locale,
  String Function(BuildContext) format,
) async {
  late String result;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(builder: (context) {
      result = format(context);
      return const SizedBox();
    }),
  ));
  return result;
}

void main() {
  // main._bootstrap does this for the running app; tests need it too or
  // DateFormat(..., 'ar') throws on its missing symbol data.
  setUpAll(() async => initializeDateFormatting());

  const en = Locale('en');
  const ar = Locale('ar');
  // A Wednesday, deliberately — weekday and month both render symbolically.
  final when = DateTime(2026, 7, 15, 14, 30);

  testWidgets('month names follow the app locale', (t) async {
    final english = await formatIn(t, en, (c) => AppDate.dateTime(c, when));
    final arabic = await formatIn(t, ar, (c) => AppDate.dateTime(c, when));

    expect(english, contains('Jul'));
    // The regression: this used to be "Jul 15, 14:30" on an Arabic screen.
    expect(arabic, isNot(contains('Jul')));
    expect(arabic, contains('يوليو'));
  });

  testWidgets('weekday names follow the app locale', (t) async {
    final english =
        await formatIn(t, en, (c) => AppDate.weekdayDateTime(c, when));
    final arabic =
        await formatIn(t, ar, (c) => AppDate.weekdayDateTime(c, when));

    expect(english, contains('Wed'));
    expect(arabic, isNot(contains('Wed')));
    expect(arabic, contains('الأربعاء'));
  });

  testWidgets('dayMonth follows the app locale', (t) async {
    expect(await formatIn(t, en, (c) => AppDate.dayMonth(c, when)),
        contains('Jul'));
    expect(await formatIn(t, ar, (c) => AppDate.dayMonth(c, when)),
        contains('يوليو'));
  });

  testWidgets('the 24h clock stays stable across locales', (t) async {
    // Numeric-only patterns carry no month/weekday words, so both languages
    // should agree — no AM/PM creeping in from a locale default.
    expect(await formatIn(t, en, (c) => AppDate.time(c, when)), '14:30');
    expect(await formatIn(t, ar, (c) => AppDate.time(c, when)), '14:30');
  });

  testWidgets('Arabic keeps Latin digits, like the rest of the UI',
      (t) async {
    // Passing `ar` to intl also switches the numbering system, which would
    // render "١٥ يوليو، ١٤:٣٠" beside Latin-digit badges ("5 د") and
    // distances ("200 م") on the same card. Words localize; digits don't.
    final arabic = await formatIn(t, ar, (c) => AppDate.dateTime(c, when));
    expect(arabic, contains('يوليو'));
    expect(arabic, contains('15'));
    expect(arabic, contains('14:30'));
    expect(arabic, isNot(matches(RegExp('[٠-٩]'))));
  });

  testWidgets('a reused formatter normalizes digits too', (t) async {
    // The trap this guards: one-shot helpers normalizing while `.format()` on
    // a reused formatter silently doesn't.
    final arabic = await formatIn(
      t,
      ar,
      (c) => AppDate.weekdayDateTimeFormat(c).format(when),
    );
    expect(arabic, contains('الأربعاء'));
    expect(arabic, isNot(matches(RegExp('[٠-٩]'))));
  });

  test('toLatinDigits rewrites digits and leaves letters alone', () {
    expect(AppDate.toLatinDigits('١٥ يوليو، ١٤:٣٠'), '15 يوليو، 14:30');
    expect(AppDate.toLatinDigits('Jul 15, 14:30'), 'Jul 15, 14:30');
  });

  test('isoDate is locale-independent', () {
    expect(AppDate.isoDate(when), '2026-07-15');
  });
}
