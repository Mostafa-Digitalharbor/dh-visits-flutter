import '../../l10n/generated/app_localizations.dart';
import '../constants/app_locales.dart';

/// Turns the backend's own English sentences into the app's language.
///
/// Why this has to exist on the client: the Odoo server this app talks to has
/// **only `en_US` installed** — asking it for Arabic returns
/// `UserError: Invalid language code: ar_001` — so every business rule it
/// enforces comes back in English no matter what the request asks for. Those
/// sentences are the most useful errors in the app ("Only an approved visit can
/// be started" tells a rep exactly what to do next), and they were being
/// rendered verbatim into the middle of an Arabic screen.
///
/// The alternative — dropping them for a generic "validation error" — is worse:
/// it is translated but says nothing. So the small, enumerable set of rules the
/// module actually raises is translated here, and anything unrecognised falls
/// back to the language check in `ApiExceptionL10n.localize`.
///
/// **The matching is on English text on purpose, and it is a stopgap.** The
/// durable fix is a machine-readable code on the error payload (see
/// docs/BACKEND_OPEN_ASKS.md); until the module sends one, the sentence is the
/// only thing that identifies the rule. Fragments were chosen from what the
/// live server actually returns (measured by `scratchpad/error_sweep.mjs`) and
/// kept to the part of each sentence least likely to be reworded — never the
/// whole string, which would break on a full stop.
class ServerMessageL10n {
  ServerMessageL10n._();

  /// Odoo prefixes ORM-constraint failures with this before the real sentence.
  static final _odooPrefix = RegExp(
    r'^the operation cannot be completed:?\s*',
    caseSensitive: false,
  );

  /// `Missing required value for the field 'Purpose' (purpose)` — group 1 is
  /// the field's label in the server's language, group 2 its technical name.
  static final _missingField = RegExp(
    r"missing required value for the field '([^']+)'(?:\s*\(([a-z0-9_]+)\))?",
    caseSensitive: false,
  );

  /// The localized label of a `dh.visit` field, by technical name. The
  /// server's own label is English-only (see the class doc), so it is shown
  /// only when nothing here matches *and* it is already in the UI's language.
  static String? _fieldLabel(AppLocalizations s, String? technicalName) =>
      switch (technicalName) {
        'purpose' => s.wfFieldPurpose,
        'scheduled_datetime' => s.wfFieldSchedule,
        'project_id' => s.wfFieldProject,
        'opportunity_id' => s.wfFieldOpportunity,
        'visit_type' => s.wfFieldType,
        'location' => s.wfFieldLocation,
        'outcome' => s.wfFieldOutcome,
        'employee_id' => s.wfFieldResponsible,
        'partner_id' => s.wfFieldCustomer,
        _ => null,
      };

  /// The localized equivalent of [message], or `null` if it is not a rule this
  /// app knows about.
  static String? translate(AppLocalizations s, String message) {
    final text = message.trim().replaceFirst(_odooPrefix, '').toLowerCase();
    if (text.isEmpty) return null;

    final missing = _missingField.firstMatch(message);
    if (missing != null) {
      final label = _fieldLabel(s, missing.group(2)) ??
          (readableIn(s, missing.group(1)!) ? missing.group(1) : null);
      return label == null
          ? s.errMissingRequiredFieldGeneric
          : s.errMissingRequiredField(label);
    }

    // Ordered: the approver rule mentions "approve" too, so it has to be tested
    // before the state-of-the-visit rules that share the word.
    if (text.contains('not authorized to approve') ||
        text.contains('not allowed to approve')) {
      return s.errNotVisitApprover;
    }
    if (text.contains('attendee approval has already been decided')) {
      return s.errAttendeeAlreadyDecided;
    }
    if (text.contains('only an approved visit can be started')) {
      return s.errOnlyApprovedCanStart;
    }
    if (text.contains('only a visit in progress can be ended')) {
      return s.errOnlyInProgressCanEnd;
    }
    if (text.contains('can be submitted')) return s.errOnlyDraftCanSubmit;
    // Checked before the generic "cannot be approved": the attendee gate's
    // sentence ("cannot be approved yet: all attendees must be approved
    // first") contains it too, and is not about the visit's state.
    if (text.contains('all attendees must be approved')) {
      return s.errAttendeesPending;
    }
    if (text.contains('cannot be approved')) return s.errCannotApproveInState;
    if (text.contains('cannot be rejected')) return s.errCannotRejectInState;
    if (text.contains('finished visit cannot be rescheduled')) {
      return s.errCannotRescheduleFinished;
    }
    if (text.contains('outcome is required')) return s.errOutcomeRequired;
    if (text.contains('project is required')) return s.errProjectRequired;
    if (text.contains('opportunity is required')) {
      return s.errOpportunityRequired;
    }
    // GPS-trail rules: a fix for a visit that isn't running.
    if (text.contains('has not been started, so no position')) {
      return s.errTrailVisitNotStarted;
    }
    if (text.contains('a later position cannot be added')) {
      return s.errTrailVisitEnded;
    }
    // Odoo's referential-integrity message, which names the internal model and
    // calls the record "the troublemaker". Never fit to show, translated or not.
    if (text.contains('another model is using the record')) {
      return s.errRecordInUse;
    }
    return null;
  }

  /// Any Arabic letter. The two languages this app ships use disjoint
  /// scripts, so script presence tells which one a server sentence is in.
  static final _arabicScript = RegExp(r'[؀-ۿ]');

  /// Whether [text] is written in Arabic script.
  static bool isArabicText(String text) => _arabicScript.hasMatch(text);

  /// Whether [text] reads naturally in the language [s] renders — the test
  /// for passing an untranslated server sentence through as-is.
  static bool readableIn(AppLocalizations s, String text) =>
      isArabicText(text) == AppLocales.isArabicTag(s.localeName);
}
