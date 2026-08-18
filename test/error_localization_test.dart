// Guards the rule that no raw Dart/Dio diagnostic ever reaches the user:
// the app is the only surface they have, so an unexpected failure must read
// as a sentence they can act on, in their language — while the diagnostic
// still has to survive into Sentry.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/extensions/context_extensions.dart';

/// Pumps a [Localizations] scope in [locale] and returns the localized text
/// for [error] exactly as a screen would render it.
Future<String> localize(
  WidgetTester tester,
  ApiException error,
  Locale locale,
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
      result = error.localize(context);
      return const SizedBox();
    }),
  ));
  return result;
}

void main() {
  const en = Locale('en');
  const ar = Locale('ar');

  group('ApiException.unexpected', () {
    // The regression this exists for: a null-cast during JSON parsing used to
    // be shown to the user verbatim, in English, on an Arabic screen.
    final crash = ApiException.unexpected(
      TypeError(),
    );

    testWidgets('shows a localized sentence, not the raw error', (t) async {
      // Asserted against the ARB values rather than literals: the point is
      // that each locale gets *its own* real sentence, not that the copy
      // never changes. Hard-coding the wording made a copy edit look like a
      // regression.
      final english = await localize(t, crash, en);
      final arabic = await localize(t, crash, ar);
      expect(english, lookupAppLocalizations(en).errUnknown);
      expect(arabic, lookupAppLocalizations(ar).errUnknown);
      expect(english, isNot(arabic));
      // A real sentence for the user, not a code or a bare word.
      expect(english.length, greaterThan(10));
      expect(arabic, matches(RegExp(r'[؀-ۿ]')));
    });

    testWidgets('never leaks Dart error text into the message', (t) async {
      final leaky = ApiException.unexpected(
        "type 'Null' is not a subtype of type 'String'",
      );
      for (final locale in [en, ar]) {
        final shown = await localize(t, leaky, locale);
        expect(shown, isNot(contains('Null')));
        expect(shown, isNot(contains('subtype')));
      }
    });

    test('keeps the diagnostic in details for Sentry', () {
      final e = ApiException.unexpected('Connection closed before full header');
      // Sentry serializes via toString(); the detail must survive even though
      // it's deliberately kept out of the user-facing message.
      expect(e.serverMessage, isNull);
      expect(e.toString(), contains('Connection closed before full header'));
    });
  });

  group('server-authored messages', () {
    testWidgets('a real server message is still shown verbatim', (t) async {
      // Odoo UserError / ValidationError text is written for the user and is
      // the most specific thing we have — localize() must not swallow it.
      final e = ApiException(
        code: ApiErrorCode.validation,
        serverMessage: 'You cannot approve your own visit',
      );
      expect(await localize(t, e, en), 'You cannot approve your own visit');
    });

    testWidgets('validation falls back to a localized message when bare',
        (t) async {
      final e = ApiException(code: ApiErrorCode.validation);
      expect(await localize(t, e, ar), isNotEmpty);
      expect(await localize(t, e, ar), isNot(contains('Exception')));
    });
  });

  group('ApiException.fromJson — server faults', () {
    /// The JSON-RPC envelope Odoo actually returns.
    Map<String, dynamic> fault(String name, String message) => {
          'error': {
            'code': 200,
            'message': 'Odoo Server Error',
            'data': {'name': name, 'message': message, 'debug': 'Traceback…'},
          }
        };

    // Captured verbatim from the live backend by calling the endpoint with no
    // arguments. Before the fix, `localize()` returned this string — English
    // Python, mid-sentence, as the only explanation an Arabic-speaking field
    // rep got for a failed "create visit".
    const pythonFault =
        "VisitApiController.create_visit() missing 1 required positional "
        "argument: 'vals'";

    testWidgets('an internal Python error never reaches the user', (t) async {
      final e = ApiException.fromJson(fault('builtins.TypeError', pythonFault));
      for (final locale in [en, ar]) {
        final shown = await localize(t, e, locale);
        expect(shown, isNot(contains('VisitApiController')));
        expect(shown, isNot(contains('positional')));
        expect(shown, isNot(contains('vals')));
      }
      expect(await localize(t, e, en), lookupAppLocalizations(en).errUnknown);
      expect(await localize(t, e, ar), lookupAppLocalizations(ar).errUnknown);
    });

    test('…but the diagnostic still survives for support', () {
      final e = ApiException.fromJson(fault('builtins.TypeError', pythonFault));
      expect(e.serverMessage, isNull);
      expect(e.toString(), contains('create_visit'));
    });

    testWidgets('a business rule from the server IS shown', (t) async {
      // UserError is what an Odoo developer raises to explain a rule, so it
      // stays the most specific thing the user can be told.
      final e = ApiException.fromJson(fault(
          'odoo.exceptions.UserError', 'A visit cannot start before it is approved'));
      expect(await localize(t, e, en),
          'A visit cannot start before it is approved');
    });

    testWidgets('MissingError falls back rather than leaking record ids',
        (t) async {
      final e = ApiException.fromJson(fault('odoo.exceptions.MissingError',
          'Record does not exist or has been deleted. (Records: dh.visit(999,), User: 2)'));
      final shown = await localize(t, e, ar);
      expect(shown, isNot(contains('dh.visit')));
      expect(shown, equals(lookupAppLocalizations(ar).errNotFound));
    });

    testWidgets('the bare JSON-RPC wrapper text is never shown', (t) async {
      // Every Odoo fault carries message: "Odoo Server Error" on the wrapper.
      final e = ApiException.fromJson({
        'error': {'code': 200, 'message': 'Odoo Server Error'}
      });
      for (final locale in [en, ar]) {
        expect(await localize(t, e, locale), isNot(contains('Odoo Server Error')));
      }
    });

    testWidgets('the module\'s own REST contract message is shown', (t) async {
      // No Odoo exception class => this came from dh_visit_management's own
      // error envelope, where the message is written for the app to display.
      // This one is not a rule ServerMessageL10n knows, so it passes through
      // to an English reader unchanged.
      final e = ApiException.fromJson({
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Territory quota exceeded for this week'
        }
      });
      expect(await localize(t, e, en), 'Territory quota exceeded for this week');
    });
  });

  // The backend enforces the visit workflow and explains each refusal in a
  // sentence — in English, because the server has only en_US installed
  // (`res.lang` returns exactly ["en_US"], and asking for ar_001 raises
  // "Invalid language code"). Every string below was captured verbatim from the
  // live server by `scratchpad/error_sweep.mjs` on 2026-08-17. They are the most
  // useful errors in the app, and until this group existed an Arabic-speaking
  // rep read all of them in English.
  group('the backend speaks English; the user must not have to', () {
    final rules = <String, String Function(AppLocalizations)>{
      "You are not authorized to approve or reject this visit. Only a manager "
          "in Kareem Saleh's management hierarchy can do that.":
          (s) => s.errNotVisitApprover,
      'Only an approved visit can be started.': (s) => s.errOnlyApprovedCanStart,
      'Only a visit in progress can be ended.': (s) => s.errOnlyInProgressCanEnd,
      'Only draft or rescheduled visits can be submitted.':
          (s) => s.errOnlyDraftCanSubmit,
      'This visit cannot be approved in its current state.':
          (s) => s.errCannotApproveInState,
      'This visit cannot be rejected in its current state.':
          (s) => s.errCannotRejectInState,
      'The visit outcome is required before ending the visit.':
          (s) => s.errOutcomeRequired,
      'The operation cannot be completed: Another model is using the record '
          'you are trying to delete. The troublemaker is: '
          "'Visit Attendee' (dh.visit.participant)": (s) => s.errRecordInUse,
    };

    rules.forEach((serverText, expected) {
      final label = serverText.length > 46
          ? '${serverText.substring(0, 46)}…'
          : serverText;

      testWidgets('"$label" reaches an Arabic user in Arabic', (t) async {
        final e = ApiException(
            code: ApiErrorCode.validation, serverMessage: serverText);
        final shown = await localize(t, e, ar);
        expect(shown, expected(lookupAppLocalizations(ar)));
        expect(shown, matches(RegExp(r'[؀-ۿ]')),
            reason: 'still rendered in English');
        // Not the generic fallback: the whole point is keeping the specifics.
        expect(shown, isNot(lookupAppLocalizations(ar).errValidation));
      });

      testWidgets('"$label" reads as our own English, not Odoo\'s', (t) async {
        final e = ApiException(
            code: ApiErrorCode.validation, serverMessage: serverText);
        expect(await localize(t, e, en), expected(lookupAppLocalizations(en)));
      });
    });

    testWidgets('a missing required field keeps the field name', (t) async {
      final e = ApiException(
        code: ApiErrorCode.validation,
        serverMessage: "The operation cannot be completed: Missing required "
            "value for the field 'Purpose' (purpose). Model: 'Visit' (dh.visit)",
      );
      for (final locale in [en, ar]) {
        final shown = await localize(t, e, locale);
        expect(shown, contains('Purpose'));
        // The internal technical name and model are not for the user.
        expect(shown, isNot(contains('dh.visit')));
        expect(shown, isNot(contains('(purpose)')));
      }
      expect(await localize(t, e, ar), matches(RegExp(r'[؀-ۿ]')));
    });
  });

  // The backstop for sentences the map above has never seen — a rule added to
  // the module after this build shipped. Passing those through is right when
  // the reader can read them and wrong when they cannot, and the two languages
  // this app ships use disjoint scripts, so the script decides.
  group('an unrecognised message is shown only in the reader\'s language', () {
    ApiException msg(String m) =>
        ApiException(code: ApiErrorCode.validation, serverMessage: m);

    const english = 'Territory quota exceeded for this week';
    const arabic = 'تم تجاوز الحد الأسبوعي المسموح به لهذه المنطقة';

    testWidgets('English message, English UI → shown', (t) async {
      expect(await localize(t, msg(english), en), english);
    });

    testWidgets('English message, Arabic UI → localized fallback', (t) async {
      final shown = await localize(t, msg(english), ar);
      expect(shown, lookupAppLocalizations(ar).errValidation);
      expect(shown, isNot(contains('Territory')));
    });

    testWidgets('Arabic message, Arabic UI → shown', (t) async {
      expect(await localize(t, msg(arabic), ar), arabic);
    });

    testWidgets('Arabic message, English UI → localized fallback', (t) async {
      final shown = await localize(t, msg(arabic), en);
      expect(shown, lookupAppLocalizations(en).errValidation);
      expect(shown, isNot(matches(RegExp(r'[؀-ۿ]'))));
    });

    testWidgets('a mixed sentence follows its script, not its punctuation',
        (t) async {
      // Arabic text carrying a Latin reference — common, and still Arabic.
      const mixed = 'تعذّر تنفيذ الإجراء على الزيارة VIS/2026/00164';
      expect(await localize(t, msg(mixed), ar), mixed);
      expect(await localize(t, msg(mixed), en),
          lookupAppLocalizations(en).errValidation);
    });
  });

  group('every error code is localized in both languages', () {
    // An unlocalized code would surface as an English string (or throw) on an
    // Arabic screen; the exhaustive switch in localize() is only useful if
    // every arm actually resolves in both ARBs.
    testWidgets('no code renders empty or leaks a Dart type name', (t) async {
      for (final code in ApiErrorCode.values) {
        for (final locale in [en, ar]) {
          final shown = await localize(t, ApiException(code: code), locale);
          expect(shown, isNotEmpty, reason: '$code in $locale');
          expect(shown, isNot(contains('Exception')), reason: '$code in $locale');
          expect(shown, isNot(contains('Instance of')), reason: '$code in $locale');
        }
      }
    });
  });
}
