import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Track your field visits with precision'**
  String get appTagline;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get commonSearch;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonLogout;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// Shown in place of a value that is not available (a time not yet recorded, an unknown version).
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get commonNoValue;

  /// A field label followed by its value, e.g. 'Tax ID: 3000123'.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String commonLabeledValue(String label, String value);

  /// A latitude/longitude pair. Digits stay Latin in both languages.
  ///
  /// In en, this message translates to:
  /// **'{lat}, {lng}'**
  String commonCoordinates(String lat, String lng);

  /// Joins short facts on one line, e.g. 'VIS/0012 · Project Alpha'.
  ///
  /// In en, this message translates to:
  /// **' · '**
  String get commonListSeparator;

  /// Snackbar when a refresh fails over data already on screen. {reason } is the localized failure sentence.
  ///
  /// In en, this message translates to:
  /// **'{reason} Showing the last loaded data — pull down to try again.'**
  String commonRefreshFailedStale(String reason);

  /// A span between two clock times, e.g. '09:00 – 10:30'.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String commonTimeRange(String from, String to);

  /// A duration of whole hours and minutes, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} m'**
  String commonDurationHoursMinutes(int hours, int minutes);

  /// A duration of whole hours, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String commonDurationHours(int hours);

  /// A duration of whole minutes, abbreviated.
  ///
  /// In en, this message translates to:
  /// **'{minutes} m'**
  String commonDurationMinutes(int minutes);

  /// Small print under an error, so a screenshot tells support what failed.
  ///
  /// In en, this message translates to:
  /// **'Error code: {code}'**
  String commonErrorReference(String code);

  /// No description provided for @commonGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get commonGreetingMorning;

  /// No description provided for @commonGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get commonGreetingAfternoon;

  /// No description provided for @commonGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get commonGreetingEvening;

  /// No description provided for @commonPageNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get commonPageNotFoundTitle;

  /// No description provided for @commonPageNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t open anything in the app. Go back to the home screen and try again from there.'**
  String get commonPageNotFoundMessage;

  /// No description provided for @commonGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to home screen'**
  String get commonGoHome;

  /// Progress as a count out of a total, e.g. 3/10.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total}'**
  String commonFraction(String done, String total);

  /// No description provided for @badgeOverflow.
  ///
  /// In en, this message translates to:
  /// **'{max}+'**
  String badgeOverflow(int max);

  /// Title for a visit whose reference and customer are both unknown.
  ///
  /// In en, this message translates to:
  /// **'Visit #{id}'**
  String visitFallbackTitle(int id);

  /// No description provided for @unitMeters.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String unitMeters(String value);

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String unitMinutes(String value);

  /// No description provided for @unitKm.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String unitKm(String value);

  /// No description provided for @unitKmh.
  ///
  /// In en, this message translates to:
  /// **'{value} km/h'**
  String unitKmh(String value);

  /// No description provided for @unitPercentValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String unitPercentValue(String value);

  /// No description provided for @relativeNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get relativeNow;

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String relativeMinutesAgo(int count);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String relativeHoursAgo(int count);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String relativeDaysAgo(int count);

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Two-character label on the auth screen's language chip, shown when the app is in English so the chip advertises the language it switches TO. Written in Arabic in every locale — a language chip names itself, it is not translated.
  ///
  /// In en, this message translates to:
  /// **'ع'**
  String get languageCodeShortArabic;

  /// Counterpart of languageCodeShortArabic, shown when the app is in Arabic. Written in Latin script in every locale.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageCodeShortEnglish;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @serverSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your server'**
  String get serverSetupTitle;

  /// No description provided for @serverSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your organization\'s server address to get started'**
  String get serverSetupSubtitle;

  /// No description provided for @serverSetupUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://your-company.odoo.com'**
  String get serverSetupUrlHint;

  /// No description provided for @serverSetupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get serverSetupContinue;

  /// No description provided for @serverSetupInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server address (for example https://your-company.odoo.com).'**
  String get serverSetupInvalidUrl;

  /// No description provided for @serverSetupHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask your system administrator if you don\'t know your server address.'**
  String get serverSetupHelp;

  /// No description provided for @serverSetupDatabaseHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. company-main'**
  String get serverSetupDatabaseHint;

  /// No description provided for @serverSetupDatabasePrompt.
  ///
  /// In en, this message translates to:
  /// **'This server doesn\'t list its databases, so the app can\'t detect yours. Enter your company\'s database name — your administrator can tell you.'**
  String get serverSetupDatabasePrompt;

  /// No description provided for @serverSetupDetectDb.
  ///
  /// In en, this message translates to:
  /// **'Detect database'**
  String get serverSetupDetectDb;

  /// No description provided for @serverSetupDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get serverSetupDetecting;

  /// No description provided for @serverSetupDetected.
  ///
  /// In en, this message translates to:
  /// **'Database detected: {db}'**
  String serverSetupDetected(String db);

  /// No description provided for @serverSetupInsecureUrl.
  ///
  /// In en, this message translates to:
  /// **'This address starts with http://, so your password would travel unencrypted. Enter your server\'s https:// address — ask your administrator if you don\'t know it.'**
  String get serverSetupInsecureUrl;

  /// No description provided for @serverSetupUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {host}. Check the address for typos and make sure you\'re connected to the internet, then try again.'**
  String serverSetupUnreachable(String host);

  /// No description provided for @serverSetupTimeout.
  ///
  /// In en, this message translates to:
  /// **'{host} took too long to answer. Check your connection and try again; if it keeps happening, the server may be down — contact your administrator.'**
  String serverSetupTimeout(String host);

  /// No description provided for @serverSetupNotOdoo.
  ///
  /// In en, this message translates to:
  /// **'{host} answered, but it isn\'t an Odoo server. Enter the address you use to open Odoo in your browser. If you\'re on public Wi-Fi, sign in to the Wi-Fi first.'**
  String serverSetupNotOdoo(String host);

  /// No description provided for @serverSetupUntrustedCertificate.
  ///
  /// In en, this message translates to:
  /// **'The security certificate of {host} isn\'t trusted, so the app won\'t send your password there. Check the address with your administrator — the server needs a valid security certificate.'**
  String serverSetupUntrustedCertificate(String host);

  /// No description provided for @serverSetupServerDown.
  ///
  /// In en, this message translates to:
  /// **'{host} is having problems right now, possibly maintenance. Wait a few minutes and try again; if it persists, contact your administrator.'**
  String serverSetupServerDown(String host);

  /// No description provided for @serverSetupSeveralDatabases.
  ///
  /// In en, this message translates to:
  /// **'This server hosts several databases ({databases}). Enter the one your company uses.'**
  String serverSetupSeveralDatabases(String databases);

  /// No description provided for @serverSetupDatabaseMissing.
  ///
  /// In en, this message translates to:
  /// **'This server has no database named “{db}”. Check the spelling, or clear the field and tap “Detect database”.'**
  String serverSetupDatabaseMissing(String db);

  /// No description provided for @serverSetupSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the server settings on this device. Try again; if it keeps failing, restart the app.'**
  String get serverSetupSaveFailed;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to start your field day'**
  String get loginSubtitle;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginUsername.
  ///
  /// In en, this message translates to:
  /// **'Email / Username'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// Tooltip / screen-reader label of the eye button that reveals the password on the sign-in form.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Tooltip / screen-reader label of the eye button that masks the password again.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Tooltip / screen-reader label of the icon-only theme chip on the sign-in and server-setup screens, shown while the light theme is on.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark theme'**
  String get authSwitchToDarkTheme;

  /// Counterpart of authSwitchToDarkTheme, shown while the dark theme is on.
  ///
  /// In en, this message translates to:
  /// **'Switch to light theme'**
  String get authSwitchToLightTheme;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// No description provided for @loginRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get loginRememberMe;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginForgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get loginForgotPasswordTitle;

  /// No description provided for @loginForgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Password resets are handled by your administrator. Please contact your system administrator to reset your password.'**
  String get loginForgotPasswordBody;

  /// No description provided for @loginSecureFooter.
  ///
  /// In en, this message translates to:
  /// **'Secure sign-in · Digital Harbor'**
  String get loginSecureFooter;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The username or password is incorrect. Check both and try again — your administrator can reset your password.'**
  String get loginInvalidCredentials;

  /// No description provided for @loginTwoFactorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Your account uses two-step verification, which this app doesn\'t support yet. Ask your administrator to turn it off for your account, then sign in again.'**
  String get loginTwoFactorUnsupported;

  /// No description provided for @loginNoVisitRole.
  ///
  /// In en, this message translates to:
  /// **'Your account has no access to Visits. Ask your administrator to give you a Visits role (user or manager), then sign in again.'**
  String get loginNoVisitRole;

  /// No description provided for @loginSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'You were signed out because your session ended on the server. Sign in again to continue.'**
  String get loginSessionEnded;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The email/username or password is incorrect. Check them and try again.'**
  String get errInvalidCredentials;

  /// No description provided for @errAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again to continue.'**
  String get errAuthRequired;

  /// No description provided for @errPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this. If you need it, ask your manager or administrator.'**
  String get errPermissionDenied;

  /// No description provided for @errValidation.
  ///
  /// In en, this message translates to:
  /// **'Some of the information you entered wasn\'t accepted. Review it and try again.'**
  String get errValidation;

  /// Localized replacement for the backend's English 'You are not authorized to approve or reject this visit…'. See ServerMessageL10n.
  ///
  /// In en, this message translates to:
  /// **'You aren\'t an approver for this visit. Only a manager in the owner\'s reporting line can approve or reject it.'**
  String get errNotVisitApprover;

  /// Replaces the backend's 'Only an approved visit can be started.'
  ///
  /// In en, this message translates to:
  /// **'This visit must be approved before you can start it. Submit it for approval if you haven\'t, then wait for your manager\'s decision.'**
  String get errOnlyApprovedCanStart;

  /// Replaces the backend's 'Only a visit in progress can be ended.'
  ///
  /// In en, this message translates to:
  /// **'This visit isn\'t in progress, so it can\'t be ended. Refresh to check its status — it may not have started yet or may already be ended.'**
  String get errOnlyInProgressCanEnd;

  /// Replaces the backend's 'Only draft or rescheduled visits can be submitted.'
  ///
  /// In en, this message translates to:
  /// **'This visit can\'t be submitted because it isn\'t a draft, a rejected visit or a rescheduled visit. Refresh to see its current status.'**
  String get errOnlyDraftCanSubmit;

  /// Replaces the backend's 'This visit cannot be approved in its current state.' — usually means someone else already acted on it.
  ///
  /// In en, this message translates to:
  /// **'This visit can\'t be approved in its current state. Refresh to see where it stands.'**
  String get errCannotApproveInState;

  /// Replaces the backend's 'The visit cannot be approved yet: all attendees must be approved first.'
  ///
  /// In en, this message translates to:
  /// **'This visit can\'t be approved yet — every attendee has to be approved by their manager first. Try again once the attendee approvals are done.'**
  String get errAttendeesPending;

  /// Replaces the backend's 'This visit cannot be rejected in its current state.'
  ///
  /// In en, this message translates to:
  /// **'This visit can\'t be rejected in its current state. Refresh to see where it stands.'**
  String get errCannotRejectInState;

  /// Replaces the backend's 'The visit outcome is required before ending the visit.'
  ///
  /// In en, this message translates to:
  /// **'Add the visit outcome before ending the visit.'**
  String get errOutcomeRequired;

  /// Replaces Odoo's 'Missing required value for the field ...'. The field label comes from the server and is already translated there when a translation exists.
  ///
  /// In en, this message translates to:
  /// **'Fill in the required field “{field}”, then try again.'**
  String errMissingRequiredField(String field);

  /// No description provided for @errMissingRequiredFieldGeneric.
  ///
  /// In en, this message translates to:
  /// **'A required field is empty. Fill in all required fields and try again.'**
  String get errMissingRequiredFieldGeneric;

  /// No description provided for @errAttendeeAlreadyDecided.
  ///
  /// In en, this message translates to:
  /// **'This participant request has already been approved or rejected. Refresh to see the latest decision.'**
  String get errAttendeeAlreadyDecided;

  /// No description provided for @errCannotRescheduleFinished.
  ///
  /// In en, this message translates to:
  /// **'This visit is already finished, so it can\'t be rescheduled. Create a new visit instead.'**
  String get errCannotRescheduleFinished;

  /// No description provided for @errProjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the project this visit is for, then try again.'**
  String get errProjectRequired;

  /// No description provided for @errOpportunityRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the opportunity this visit is for, then try again.'**
  String get errOpportunityRequired;

  /// No description provided for @errTrailVisitNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Your route can\'t be recorded because this visit hasn\'t started. Start the visit first.'**
  String get errTrailVisitNotStarted;

  /// No description provided for @errTrailVisitEnded.
  ///
  /// In en, this message translates to:
  /// **'This visit has already ended, so no more route points can be added to it. No action is needed.'**
  String get errTrailVisitEnded;

  /// Replaces Odoo's referential-integrity message, which names internal model ids and calls the record 'the troublemaker'.
  ///
  /// In en, this message translates to:
  /// **'This item is linked to other information, so it can\'t be changed or removed. Contact your administrator if it needs to change.'**
  String get errRecordInUse;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item couldn\'t be found — it may have been deleted. Refresh and try again.'**
  String get errNotFound;

  /// No description provided for @errLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'This customer has no saved location, so the visit can\'t be recorded. Ask your manager or administrator to add the customer\'s location.'**
  String get errLocationRequired;

  /// No description provided for @errServerError.
  ///
  /// In en, this message translates to:
  /// **'The server ran into a problem. Try again in a few minutes; if it keeps happening, contact your administrator.'**
  String get errServerError;

  /// No description provided for @errServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable, usually for maintenance. Wait a few minutes and try again.'**
  String get errServerUnavailable;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests in a short time. Wait a minute, then try again.'**
  String get errRateLimited;

  /// No description provided for @errPayloadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to upload. Choose a smaller file or a lower-resolution photo.'**
  String get errPayloadTooLarge;

  /// No description provided for @errInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The server sent a reply the app couldn\'t read. If you\'re on public Wi-Fi, sign in to it first; otherwise check the server address with your administrator.'**
  String get errInvalidResponse;

  /// No description provided for @errDatabaseNotFound.
  ///
  /// In en, this message translates to:
  /// **'The company database wasn\'t found on this server. Check the database name in the server settings, or ask your administrator for the correct one.'**
  String get errDatabaseNotFound;

  /// No description provided for @errNetworkTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond. Check your internet connection and try again.'**
  String get errNetworkTimeout;

  /// No description provided for @errNetworkUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your internet connection (Wi-Fi or mobile data) and try again.'**
  String get errNetworkUnreachable;

  /// No description provided for @errLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'The app can\'t access your location. Turn on location services, allow the app to use your location, then try again.'**
  String get errLocationPermission;

  /// No description provided for @errLocationNeededForVisit.
  ///
  /// In en, this message translates to:
  /// **'Your location is required to record this visit. Turn on location services, allow the app to use them, then try again.'**
  String get errLocationNeededForVisit;

  /// No description provided for @errLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t determine your location. Move somewhere with a clearer view of the sky and try again.'**
  String get errLocationUnavailable;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again — if it keeps happening, send a screenshot to your administrator.'**
  String get errUnknown;

  /// No description provided for @errSessionRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reopen your saved session. Please sign in again to continue.'**
  String get errSessionRestoreFailed;

  /// No description provided for @errProfileIncomplete.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your permissions, so visit actions are hidden. Sign out and back in — if it persists, ask your administrator to check your visit role.'**
  String get errProfileIncomplete;

  /// No description provided for @pushChannelName.
  ///
  /// In en, this message translates to:
  /// **'Visit updates'**
  String get pushChannelName;

  /// No description provided for @pushChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Approvals, reschedules and status changes for your visits.'**
  String get pushChannelDescription;

  /// No description provided for @pushEventSubmitted.
  ///
  /// In en, this message translates to:
  /// **'A visit needs your approval'**
  String get pushEventSubmitted;

  /// No description provided for @pushEventParticipationApproval.
  ///
  /// In en, this message translates to:
  /// **'An attendee needs your approval'**
  String get pushEventParticipationApproval;

  /// No description provided for @pushEventReadyForApproval.
  ///
  /// In en, this message translates to:
  /// **'A visit is ready for your approval'**
  String get pushEventReadyForApproval;

  /// No description provided for @pushEventApproved.
  ///
  /// In en, this message translates to:
  /// **'Visit approved'**
  String get pushEventApproved;

  /// No description provided for @pushEventRejected.
  ///
  /// In en, this message translates to:
  /// **'Visit rejected'**
  String get pushEventRejected;

  /// No description provided for @pushEventParticipantRejected.
  ///
  /// In en, this message translates to:
  /// **'An attendee was declined'**
  String get pushEventParticipantRejected;

  /// No description provided for @pushEventRescheduleRequested.
  ///
  /// In en, this message translates to:
  /// **'A reschedule needs your approval'**
  String get pushEventRescheduleRequested;

  /// No description provided for @pushEventRescheduleApproved.
  ///
  /// In en, this message translates to:
  /// **'Reschedule approved'**
  String get pushEventRescheduleApproved;

  /// No description provided for @pushEventEscalated.
  ///
  /// In en, this message translates to:
  /// **'A visit was escalated to you'**
  String get pushEventEscalated;

  /// No description provided for @pushEventStarted.
  ///
  /// In en, this message translates to:
  /// **'Visit started'**
  String get pushEventStarted;

  /// No description provided for @pushEventCompleted.
  ///
  /// In en, this message translates to:
  /// **'Visit completed'**
  String get pushEventCompleted;

  /// No description provided for @pushEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'Visit cancelled'**
  String get pushEventCancelled;

  /// No description provided for @pushEventUpdated.
  ///
  /// In en, this message translates to:
  /// **'Visit updated'**
  String get pushEventUpdated;

  /// No description provided for @unitBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String unitBytes(String size);

  /// No description provided for @unitKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String unitKilobytes(String size);

  /// No description provided for @unitMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String unitMegabytes(String size);

  /// No description provided for @offlineActionDropped.
  ///
  /// In en, this message translates to:
  /// **'Your offline update wasn\'t saved. {reason} Open the visit and record it again.'**
  String offlineActionDropped(String reason);

  /// No description provided for @errConflict.
  ///
  /// In en, this message translates to:
  /// **'This visit was already updated somewhere else. Pull down to refresh and check its current status before trying again.'**
  String get errConflict;

  /// No description provided for @errInsecureConnection.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open a secure connection to the server. Its security certificate isn\'t trusted — check the server address with your administrator.'**
  String get errInsecureConnection;

  /// No description provided for @errCustomerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this customer\'s details. Check your internet connection and try again.'**
  String get errCustomerLoadFailed;

  /// No description provided for @errAttachmentOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this attachment. Make sure your phone has an app that can open this type of file, then try again.'**
  String get errAttachmentOpenFailed;

  /// No description provided for @errAttachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This attachment is no longer available — pull down to refresh.'**
  String get errAttachmentUnavailable;

  /// No description provided for @errAttachmentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the attachments. Check your internet connection, then pull down to try again.'**
  String get errAttachmentsLoadFailed;

  /// No description provided for @attachmentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attachments yet'**
  String get attachmentsEmpty;

  /// No description provided for @errCannotLaunchApp.
  ///
  /// In en, this message translates to:
  /// **'No app on your phone can handle this (for example a phone, email or maps app). Install or enable one, then try again.'**
  String get errCannotLaunchApp;

  /// No description provided for @errActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete this action because of an unexpected problem. Refresh and try again — if it keeps failing, contact your administrator.'**
  String get errActionFailed;

  /// No description provided for @errFeatureNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This feature isn\'t enabled on your company\'s server yet. Ask your administrator to enable it.'**
  String get errFeatureNotAvailable;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @customersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customers…'**
  String get customersSearchHint;

  /// No description provided for @customersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get customersEmpty;

  /// No description provided for @customersStatTotal.
  ///
  /// In en, this message translates to:
  /// **'Total customers'**
  String get customersStatTotal;

  /// No description provided for @customersStatActive.
  ///
  /// In en, this message translates to:
  /// **'Active customers'**
  String get customersStatActive;

  /// No description provided for @customerDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer details'**
  String get customerDetailTitle;

  /// No description provided for @customerLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get customerLastVisit;

  /// No description provided for @customerActionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get customerActionCall;

  /// No description provided for @customerActionNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get customerActionNavigate;

  /// No description provided for @customerActionEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get customerActionEmail;

  /// No description provided for @customerTypeCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get customerTypeCompany;

  /// No description provided for @customerTypeIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get customerTypeIndividual;

  /// No description provided for @customerSectionInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact details'**
  String get customerSectionInfo;

  /// No description provided for @customerFieldJob.
  ///
  /// In en, this message translates to:
  /// **'Job position'**
  String get customerFieldJob;

  /// No description provided for @customerFieldParent.
  ///
  /// In en, this message translates to:
  /// **'Related company'**
  String get customerFieldParent;

  /// No description provided for @customerFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get customerFieldTags;

  /// No description provided for @customerFieldVat.
  ///
  /// In en, this message translates to:
  /// **'Tax ID'**
  String get customerFieldVat;

  /// No description provided for @customerFieldCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get customerFieldCoordinates;

  /// Joins the parts of a postal address (street, city, country).
  ///
  /// In en, this message translates to:
  /// **', '**
  String get customerAddressSeparator;

  /// No description provided for @customerNotFound.
  ///
  /// In en, this message translates to:
  /// **'This customer no longer exists, or you no longer have access to it. Go back and refresh the customer list.'**
  String get customerNotFound;

  /// No description provided for @mapOpenDirections.
  ///
  /// In en, this message translates to:
  /// **'Open directions'**
  String get mapOpenDirections;

  /// No description provided for @employeesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search employees…'**
  String get employeesSearchHint;

  /// No description provided for @createVisitTooltip.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get createVisitTooltip;

  /// No description provided for @pickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get pickerNoResults;

  /// No description provided for @visitsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsListTitle;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleUser.
  ///
  /// In en, this message translates to:
  /// **'Field rep'**
  String get roleUser;

  /// Visit role badge on the profile screen — group_visit_project_manager. Also sees escalated visits.
  ///
  /// In en, this message translates to:
  /// **'Project manager'**
  String get roleProjectManager;

  /// Visit role badge on the profile screen — group_visit_admin, or an Odoo database admin on a server whose visit groups were never seeded.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @roleManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Team manager'**
  String get roleManagerTitle;

  /// No description provided for @roleEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Field rep'**
  String get roleEmployeeTitle;

  /// Title of the account screen: identity, then the settings scoped to that account, then sign out.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Bottom-navigation label for the profile tab. Sits under an icon next to three other labels, so it must stay short.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTabTitle;

  /// No description provided for @visitsHistoryActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get visitsHistoryActiveBadge;

  /// No description provided for @dashboardTodayProgress.
  ///
  /// In en, this message translates to:
  /// **'Today\'s progress'**
  String get dashboardTodayProgress;

  /// No description provided for @dashboardFieldTime.
  ///
  /// In en, this message translates to:
  /// **'Field time'**
  String get dashboardFieldTime;

  /// Field time in hours on the dashboard greeting, e.g. '12.5 h'.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String dashboardFieldHoursValue(String hours);

  /// No description provided for @analyticsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTabTitle;

  /// No description provided for @analyticsOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get analyticsOnTime;

  /// No description provided for @analyticsVisitsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'visits this week'**
  String get analyticsVisitsThisWeek;

  /// No description provided for @analyticsKm.
  ///
  /// In en, this message translates to:
  /// **'km in the field'**
  String get analyticsKm;

  /// No description provided for @analyticsAvgDuration.
  ///
  /// In en, this message translates to:
  /// **'Avg. visit duration'**
  String get analyticsAvgDuration;

  /// No description provided for @analyticsWeeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits this week'**
  String get analyticsWeeklyTitle;

  /// No description provided for @analyticsWeeklyCompare.
  ///
  /// In en, this message translates to:
  /// **'vs. last week'**
  String get analyticsWeeklyCompare;

  /// No description provided for @analyticsByEmployee.
  ///
  /// In en, this message translates to:
  /// **'By employee'**
  String get analyticsByEmployee;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review visits'**
  String get reviewTitle;

  /// No description provided for @reviewPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No visits awaiting your approval} =1{1 visit awaiting your approval} other{{n} visits awaiting your approval}}'**
  String reviewPendingCount(int n);

  /// No description provided for @reviewApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get reviewApprove;

  /// No description provided for @reviewReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reviewReject;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No visits awaiting review'**
  String get reviewEmpty;

  /// No description provided for @reviewApproved.
  ///
  /// In en, this message translates to:
  /// **'Visit approved'**
  String get reviewApproved;

  /// No description provided for @reviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Visit rejected'**
  String get reviewRejected;

  /// No description provided for @routeTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s route'**
  String get routeTabTitle;

  /// No description provided for @routeStops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get routeStops;

  /// Number of planned stops on today's route, on the map chip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}}'**
  String routeStopsCount(int count);

  /// No description provided for @routeTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get routeTotalDistance;

  /// No description provided for @routeNextStop.
  ///
  /// In en, this message translates to:
  /// **'Next stop'**
  String get routeNextStop;

  /// No description provided for @routeStartPoint.
  ///
  /// In en, this message translates to:
  /// **'Start point'**
  String get routeStartPoint;

  /// No description provided for @routeDriveMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min drive'**
  String routeDriveMinutes(int n);

  /// No description provided for @routeStartNav.
  ///
  /// In en, this message translates to:
  /// **'Start navigation'**
  String get routeStartNav;

  /// No description provided for @routeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stops on today\'s route'**
  String get routeEmpty;

  /// No description provided for @createVisitSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create visit'**
  String get createVisitSubmit;

  /// No description provided for @visitsHistoryCompletedBadge.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get visitsHistoryCompletedBadge;

  /// No description provided for @visitDetailInRange.
  ///
  /// In en, this message translates to:
  /// **'You\'re within the customer\'s range'**
  String get visitDetailInRange;

  /// No description provided for @visitDetailOutRange.
  ///
  /// In en, this message translates to:
  /// **'You\'re outside the customer\'s range'**
  String get visitDetailOutRange;

  /// No description provided for @offlineNoQueue.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — your actions will be saved on this device and sent when you reconnect.'**
  String get offlineNoQueue;

  /// No description provided for @offlineWithQueue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Offline — 1 action waiting to sync} other{Offline — {count} actions waiting to sync}}'**
  String offlineWithQueue(int count);

  /// No description provided for @offlineSyncing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Syncing 1 pending action…} other{Syncing {count} pending actions…}}'**
  String offlineSyncing(int count);

  /// No description provided for @offlinePendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 action is still pending — check your connection and try again.} other{{count} actions are still pending — check your connection and try again.}}'**
  String offlinePendingCount(int count);

  /// No description provided for @dashboardTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTabTitle;

  /// No description provided for @dashboardKpiOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dashboardKpiOverdue;

  /// No description provided for @dashboardKpiPending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get dashboardKpiPending;

  /// No description provided for @dashboardKpiToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardKpiToday;

  /// No description provided for @dashboardKpiActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get dashboardKpiActive;

  /// No description provided for @dashboardActiveOnMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Employees in the field'**
  String get dashboardActiveOnMapTitle;

  /// No description provided for @dashboardActiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No employees are on a visit right now'**
  String get dashboardActiveEmpty;

  /// No description provided for @dashboardActiveMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String dashboardActiveMore(int count);

  /// No description provided for @dashboardTopCustomers.
  ///
  /// In en, this message translates to:
  /// **'Most-visited customers'**
  String get dashboardTopCustomers;

  /// No description provided for @dashboardTopEmployees.
  ///
  /// In en, this message translates to:
  /// **'Top employees (completed visits)'**
  String get dashboardTopEmployees;

  /// No description provided for @dashboardNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get dashboardNoData;

  /// No description provided for @visitsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsTabTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsServer.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get settingsServer;

  /// No description provided for @settingsServerNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsServerNone;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersionValue.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersionValue(String version);

  /// The app version with its build number, e.g. '1.0.0 (5)'.
  ///
  /// In en, this message translates to:
  /// **'{version} ({build})'**
  String profileBuildVersion(String version, String build);

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSub.
  ///
  /// In en, this message translates to:
  /// **'Visit alerts and reminders'**
  String get settingsNotificationsSub;

  /// No description provided for @settingsLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get settingsLastSync;

  /// No description provided for @settingsSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get settingsSyncNow;

  /// No description provided for @settingsSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get settingsSynced;

  /// No description provided for @settingsSyncNothingPending.
  ///
  /// In en, this message translates to:
  /// **'Nothing pending'**
  String get settingsSyncNothingPending;

  /// No description provided for @settingsSyncPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 action waiting to sync} other{{count} actions waiting to sync}}'**
  String settingsSyncPendingCount(int count);

  /// No description provided for @confirmLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get confirmLogoutTitle;

  /// No description provided for @confirmLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get confirmLogoutMessage;

  /// No description provided for @confirmExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit app'**
  String get confirmExitTitle;

  /// No description provided for @confirmExitMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get confirmExitMessage;

  /// No description provided for @weekdayShortSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSun;

  /// No description provided for @weekdayShortMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSat;

  /// No description provided for @aboutAppName.
  ///
  /// In en, this message translates to:
  /// **'Customer Visits'**
  String get aboutAppName;

  /// No description provided for @aboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Digital Harbor'**
  String get aboutLegalese;

  /// No description provided for @aboutFooter.
  ///
  /// In en, this message translates to:
  /// **'Customer Visits · Digital Harbor © 2026'**
  String get aboutFooter;

  /// No description provided for @wfStateDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get wfStateDraft;

  /// No description provided for @wfStateSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get wfStateSubmitted;

  /// No description provided for @wfStateWaitingParticipant.
  ///
  /// In en, this message translates to:
  /// **'Awaiting participants\' managers'**
  String get wfStateWaitingParticipant;

  /// No description provided for @wfStateWaitingManager.
  ///
  /// In en, this message translates to:
  /// **'Awaiting manager approval'**
  String get wfStateWaitingManager;

  /// No description provided for @wfStateEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get wfStateEscalated;

  /// No description provided for @wfStateApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get wfStateApproved;

  /// No description provided for @wfStateRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get wfStateRejected;

  /// No description provided for @wfStateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get wfStateCancelled;

  /// No description provided for @wfStateReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule requested'**
  String get wfStateReschedule;

  /// No description provided for @wfStateInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get wfStateInProgress;

  /// No description provided for @wfStateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get wfStateDone;

  /// No description provided for @wfStateUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get wfStateUnknown;

  /// No description provided for @wfScopeMine.
  ///
  /// In en, this message translates to:
  /// **'My visits'**
  String get wfScopeMine;

  /// No description provided for @wfScopePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get wfScopePending;

  /// No description provided for @wfScopeTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get wfScopeTeam;

  /// No description provided for @wfScopeEscalated.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get wfScopeEscalated;

  /// No description provided for @wfActionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit for approval'**
  String get wfActionSubmit;

  /// No description provided for @wfActionApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get wfActionApprove;

  /// No description provided for @wfActionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get wfActionReject;

  /// No description provided for @wfActionReschedule.
  ///
  /// In en, this message translates to:
  /// **'Request reschedule'**
  String get wfActionReschedule;

  /// No description provided for @wfActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start visit'**
  String get wfActionStart;

  /// No description provided for @wfApproveWaitsForAttendees.
  ///
  /// In en, this message translates to:
  /// **'Approval opens once every attendee has been approved.'**
  String get wfApproveWaitsForAttendees;

  /// No description provided for @wfActionEnd.
  ///
  /// In en, this message translates to:
  /// **'End visit'**
  String get wfActionEnd;

  /// No description provided for @wfActionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel visit'**
  String get wfActionCancel;

  /// No description provided for @wfActionAddParticipant.
  ///
  /// In en, this message translates to:
  /// **'Add participant'**
  String get wfActionAddParticipant;

  /// No description provided for @wfActionAddAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get wfActionAddAttachment;

  /// No description provided for @wfActionAddAttachmentCount.
  ///
  /// In en, this message translates to:
  /// **'Add attachment ({count})'**
  String wfActionAddAttachmentCount(int count);

  /// No description provided for @wfTypeProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get wfTypeProject;

  /// No description provided for @wfTypeOpportunity.
  ///
  /// In en, this message translates to:
  /// **'Opportunity'**
  String get wfTypeOpportunity;

  /// No description provided for @wfFieldType.
  ///
  /// In en, this message translates to:
  /// **'Visit type'**
  String get wfFieldType;

  /// No description provided for @wfFieldProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get wfFieldProject;

  /// No description provided for @wfFieldOpportunity.
  ///
  /// In en, this message translates to:
  /// **'Opportunity'**
  String get wfFieldOpportunity;

  /// No description provided for @wfFieldCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get wfFieldCustomer;

  /// No description provided for @wfLinkedCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer: {name}'**
  String wfLinkedCustomer(String name);

  /// No description provided for @wfOptionalField.
  ///
  /// In en, this message translates to:
  /// **'{label} (optional)'**
  String wfOptionalField(String label);

  /// No description provided for @wfLabelColon.
  ///
  /// In en, this message translates to:
  /// **'{label}:'**
  String wfLabelColon(String label);

  /// No description provided for @wfFieldSchedule.
  ///
  /// In en, this message translates to:
  /// **'Scheduled date & time'**
  String get wfFieldSchedule;

  /// No description provided for @wfFieldPurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get wfFieldPurpose;

  /// No description provided for @wfFieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get wfFieldLocation;

  /// No description provided for @wfFieldOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get wfFieldOutcome;

  /// No description provided for @wfFieldResponsible.
  ///
  /// In en, this message translates to:
  /// **'Responsible employee'**
  String get wfFieldResponsible;

  /// No description provided for @wfFieldParticipants.
  ///
  /// In en, this message translates to:
  /// **'Additional participants'**
  String get wfFieldParticipants;

  /// No description provided for @wfFieldDirectManager.
  ///
  /// In en, this message translates to:
  /// **'Direct manager'**
  String get wfFieldDirectManager;

  /// No description provided for @wfFieldHigherManager.
  ///
  /// In en, this message translates to:
  /// **'Higher manager'**
  String get wfFieldHigherManager;

  /// No description provided for @wfPickProject.
  ///
  /// In en, this message translates to:
  /// **'Select project'**
  String get wfPickProject;

  /// No description provided for @wfPickOpportunity.
  ///
  /// In en, this message translates to:
  /// **'Select opportunity'**
  String get wfPickOpportunity;

  /// No description provided for @wfPickEmployee.
  ///
  /// In en, this message translates to:
  /// **'Select employee'**
  String get wfPickEmployee;

  /// No description provided for @wfSelfLabel.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get wfSelfLabel;

  /// No description provided for @wfPlanForMyself.
  ///
  /// In en, this message translates to:
  /// **'Plan it for myself'**
  String get wfPlanForMyself;

  /// No description provided for @wfOutcomeRequired.
  ///
  /// In en, this message translates to:
  /// **'Outcome is required to end the visit'**
  String get wfOutcomeRequired;

  /// No description provided for @wfRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get wfRejectReason;

  /// No description provided for @wfRejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Explain why this visit is rejected…'**
  String get wfRejectReasonHint;

  /// No description provided for @wfReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'A reason is required'**
  String get wfReasonRequired;

  /// No description provided for @wfCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get wfCreateTitle;

  /// No description provided for @wfCreated.
  ///
  /// In en, this message translates to:
  /// **'Visit created'**
  String get wfCreated;

  /// No description provided for @wfParticipantsNotAdded.
  ///
  /// In en, this message translates to:
  /// **'The visit was created, but its participants weren\'t added. {reason} Tap “Add participants again” to retry, or open the visit without them.'**
  String wfParticipantsNotAdded(String reason);

  /// No description provided for @wfRetryAddParticipants.
  ///
  /// In en, this message translates to:
  /// **'Add participants again'**
  String get wfRetryAddParticipants;

  /// No description provided for @wfOpenCreatedVisit.
  ///
  /// In en, this message translates to:
  /// **'Open the visit'**
  String get wfOpenCreatedVisit;

  /// No description provided for @wfSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted for approval'**
  String get wfSubmitted;

  /// No description provided for @wfApproved.
  ///
  /// In en, this message translates to:
  /// **'Visit approved'**
  String get wfApproved;

  /// No description provided for @wfRejected.
  ///
  /// In en, this message translates to:
  /// **'Visit rejected'**
  String get wfRejected;

  /// No description provided for @wfStarted.
  ///
  /// In en, this message translates to:
  /// **'Visit started'**
  String get wfStarted;

  /// No description provided for @wfEnded.
  ///
  /// In en, this message translates to:
  /// **'Visit completed'**
  String get wfEnded;

  /// No description provided for @wfRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Reschedule requested'**
  String get wfRescheduled;

  /// No description provided for @wfCancelled.
  ///
  /// In en, this message translates to:
  /// **'Visit cancelled'**
  String get wfCancelled;

  /// No description provided for @wfAttachmentAdded.
  ///
  /// In en, this message translates to:
  /// **'Attachment added'**
  String get wfAttachmentAdded;

  /// No description provided for @wfAttachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is {size}, which is over the {limit} limit. Choose a smaller file or compress it, then try again.'**
  String wfAttachmentTooLarge(String size, String limit);

  /// No description provided for @wfAttachmentUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the selected file. Choose it again or pick a different file.'**
  String get wfAttachmentUnreadable;

  /// No description provided for @wfCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera. Close any other app that is using it, then try again.'**
  String get wfCameraUnavailable;

  /// No description provided for @wfFilePickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your files. Please try again; if it keeps failing, restart the app.'**
  String get wfFilePickerUnavailable;

  /// No description provided for @wfCameraAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access needed'**
  String get wfCameraAccessTitle;

  /// No description provided for @wfCameraAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Visits isn\'t allowed to use the camera. Allow camera access for the app in Settings, then try again.'**
  String get wfCameraAccessMessage;

  /// No description provided for @wfFilesAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo and file access needed'**
  String get wfFilesAccessTitle;

  /// No description provided for @wfFilesAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Visits isn\'t allowed to open your photos and files. Allow access for the app in Settings, then try again.'**
  String get wfFilesAccessMessage;

  /// No description provided for @wfOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get wfOpenSettings;

  /// No description provided for @wfParticipantApproved.
  ///
  /// In en, this message translates to:
  /// **'Participant approved'**
  String get wfParticipantApproved;

  /// No description provided for @wfParticipantRejected.
  ///
  /// In en, this message translates to:
  /// **'Participant rejected'**
  String get wfParticipantRejected;

  /// No description provided for @wfParticipantsAdded.
  ///
  /// In en, this message translates to:
  /// **'Participants added'**
  String get wfParticipantsAdded;

  /// No description provided for @wfApprovalHistory.
  ///
  /// In en, this message translates to:
  /// **'Approval history'**
  String get wfApprovalHistory;

  /// No description provided for @wfSubmittedOn.
  ///
  /// In en, this message translates to:
  /// **'Submitted on'**
  String get wfSubmittedOn;

  /// No description provided for @wfApprovedByOn.
  ///
  /// In en, this message translates to:
  /// **'Approved by'**
  String get wfApprovedByOn;

  /// No description provided for @wfRejectedByOn.
  ///
  /// In en, this message translates to:
  /// **'Rejected by'**
  String get wfRejectedByOn;

  /// No description provided for @wfReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get wfReason;

  /// No description provided for @wfEscalatedBadge.
  ///
  /// In en, this message translates to:
  /// **'Escalated'**
  String get wfEscalatedBadge;

  /// No description provided for @wfParticipantsSection.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get wfParticipantsSection;

  /// No description provided for @wfParticipantPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get wfParticipantPending;

  /// No description provided for @wfParticipantApprovedState.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get wfParticipantApprovedState;

  /// No description provided for @wfParticipantRejectedState.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get wfParticipantRejectedState;

  /// No description provided for @wfUnknownEmployee.
  ///
  /// In en, this message translates to:
  /// **'Unknown employee'**
  String get wfUnknownEmployee;

  /// No description provided for @wfApproveParticipant.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get wfApproveParticipant;

  /// No description provided for @wfRejectParticipant.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get wfRejectParticipant;

  /// No description provided for @wfEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'You have no visits yet'**
  String get wfEmptyMine;

  /// No description provided for @wfEmptyPending.
  ///
  /// In en, this message translates to:
  /// **'Nothing awaiting your approval'**
  String get wfEmptyPending;

  /// No description provided for @wfEmptyTeam.
  ///
  /// In en, this message translates to:
  /// **'No team visits'**
  String get wfEmptyTeam;

  /// No description provided for @wfEmptyEscalated.
  ///
  /// In en, this message translates to:
  /// **'No escalated visits'**
  String get wfEmptyEscalated;

  /// No description provided for @wfSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by customer, reference or purpose…'**
  String get wfSearchHint;

  /// No description provided for @wfSearchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No visits in this list match your search. Try another list above, or pull down to refresh.'**
  String get wfSearchNoMatch;

  /// No description provided for @wfFilterNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No visits match this filter. Clear the filter to see all your visits.'**
  String get wfFilterNoMatch;

  /// No description provided for @wfClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get wfClearFilter;

  /// No description provided for @wfRescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Request reschedule'**
  String get wfRescheduleTitle;

  /// No description provided for @wfRescheduleNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Nothing has changed. Change the date, purpose or location before sending the request.'**
  String get wfRescheduleNoChanges;

  /// No description provided for @wfDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get wfDetailTitle;

  /// No description provided for @wfConfirmCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel visit'**
  String get wfConfirmCancelTitle;

  /// No description provided for @wfConfirmCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this visit?'**
  String get wfConfirmCancelMessage;

  /// No description provided for @wfStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get wfStartedLabel;

  /// No description provided for @wfEndedLabel.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get wfEndedLabel;

  /// No description provided for @wfFieldStartLocation.
  ///
  /// In en, this message translates to:
  /// **'Start location'**
  String get wfFieldStartLocation;

  /// No description provided for @wfFieldEndLocation.
  ///
  /// In en, this message translates to:
  /// **'End location'**
  String get wfFieldEndLocation;

  /// No description provided for @wfDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get wfDurationLabel;

  /// No description provided for @wfSectionVisitInfo.
  ///
  /// In en, this message translates to:
  /// **'Visit details'**
  String get wfSectionVisitInfo;

  /// No description provided for @wfSectionApproval.
  ///
  /// In en, this message translates to:
  /// **'Team & approval'**
  String get wfSectionApproval;

  /// No description provided for @wfSectionExecution.
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get wfSectionExecution;

  /// No description provided for @wfSectionAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get wfSectionAttachments;

  /// No description provided for @wfOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get wfOpenInMaps;

  /// No description provided for @wfRangeDistance.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String wfRangeDistance(String distance);

  /// No description provided for @wfRangeRadius.
  ///
  /// In en, this message translates to:
  /// **'check-in range {radius}'**
  String wfRangeRadius(String radius);

  /// No description provided for @wfShortVisitHint.
  ///
  /// In en, this message translates to:
  /// **'Short visit'**
  String get wfShortVisitHint;

  /// No description provided for @wfNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get wfNotificationsTitle;

  /// No description provided for @wfNotificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get wfNotificationsEmpty;

  /// No description provided for @wfNotificationsDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String wfNotificationsDue(String date);

  /// No description provided for @wfActionTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get wfActionTakePhoto;

  /// No description provided for @wfMockLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Fake location detected'**
  String get wfMockLocationTitle;

  /// No description provided for @wfMockLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'Your device is reporting a mock (fake) GPS location. This will be flagged for review. Continue anyway?'**
  String get wfMockLocationMessage;

  /// No description provided for @wfQueuedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved offline — it\'ll sync when you\'re back online'**
  String get wfQueuedOffline;

  /// No description provided for @wfMockFlagBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Fake location recorded on this visit'**
  String get wfMockFlagBannerTitle;

  /// No description provided for @wfMockFlagBannerBody.
  ///
  /// In en, this message translates to:
  /// **'The device reported a mock (fake) GPS location when this visit was started or ended. Review it before approving.'**
  String get wfMockFlagBannerBody;

  /// No description provided for @trailSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Route travelled'**
  String get trailSectionTitle;

  /// No description provided for @trailMapTitle.
  ///
  /// In en, this message translates to:
  /// **'GPS trail'**
  String get trailMapTitle;

  /// No description provided for @trailEmptyRunning.
  ///
  /// In en, this message translates to:
  /// **'Recording your route — the path appears as you move'**
  String get trailEmptyRunning;

  /// No description provided for @trailEmptyFinished.
  ///
  /// In en, this message translates to:
  /// **'No points were recorded during this visit'**
  String get trailEmptyFinished;

  /// No description provided for @trailLive.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get trailLive;

  /// No description provided for @trailPoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No points} =1{1 point} other{{count} points}}'**
  String trailPoints(int count);

  /// No description provided for @trailDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get trailDistance;

  /// No description provided for @trailAvgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get trailAvgSpeed;

  /// No description provided for @trailLastFix.
  ///
  /// In en, this message translates to:
  /// **'Last position'**
  String get trailLastFix;

  /// No description provided for @trailOpenFull.
  ///
  /// In en, this message translates to:
  /// **'View full route'**
  String get trailOpenFull;

  /// No description provided for @trailPointStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get trailPointStart;

  /// No description provided for @trailPointEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get trailPointEnd;

  /// No description provided for @trailPointTrack.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get trailPointTrack;

  /// No description provided for @trailPointManual.
  ///
  /// In en, this message translates to:
  /// **'Added manually'**
  String get trailPointManual;

  /// No description provided for @trailAccuracy.
  ///
  /// In en, this message translates to:
  /// **'±{meters} m'**
  String trailAccuracy(String meters);

  /// No description provided for @trailPendingUploads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point waiting to upload} other{{count} points waiting to upload}}'**
  String trailPendingUploads(int count);

  /// No description provided for @trailUploadDone.
  ///
  /// In en, this message translates to:
  /// **'Recorded points uploaded'**
  String get trailUploadDone;

  /// No description provided for @trailUploadStillPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point is still waiting to upload. Check your internet connection; it will upload automatically once you\'re back online.} other{{count} points are still waiting to upload. Check your internet connection; they will upload automatically once you\'re back online.}}'**
  String trailUploadStillPending(int count);

  /// No description provided for @trailPointsDropped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recorded point couldn\'t be saved, so your route has a gap. No action is needed — tell your manager if the route looks wrong.} other{{count} recorded points couldn\'t be saved, so your route has gaps. No action is needed — tell your manager if the route looks wrong.}}'**
  String trailPointsDropped(int count);

  /// No description provided for @trailPointsList.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get trailPointsList;

  /// No description provided for @trailFitRoute.
  ///
  /// In en, this message translates to:
  /// **'Fit route to screen'**
  String get trailFitRoute;

  /// No description provided for @visitTrackingRequired.
  ///
  /// In en, this message translates to:
  /// **'A visit can only be started with its route recorded. Tap Start visit again and agree to route recording to continue.'**
  String get visitTrackingRequired;

  /// No description provided for @visitTrackingNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit tracking active'**
  String get visitTrackingNotificationTitle;

  /// No description provided for @visitTrackingNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Recording the route of your visit'**
  String get visitTrackingNotificationText;

  /// No description provided for @visitTrackingDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit route recording'**
  String get visitTrackingDisclosureTitle;

  /// No description provided for @visitTrackingDisclosureBody.
  ///
  /// In en, this message translates to:
  /// **'While a customer visit is in progress, Visits collects this device\'s precise location — also when the app is in the background or not in use and while the screen is locked — to record the route of that visit for your employer.'**
  String get visitTrackingDisclosureBody;

  /// No description provided for @visitTrackingDisclosureStops.
  ///
  /// In en, this message translates to:
  /// **'Recording starts only after you tap Start visit and the visit has started, and stops as soon as you end the visit or sign out. No location is recorded before a visit starts, between visits or after a visit ends.'**
  String get visitTrackingDisclosureStops;

  /// No description provided for @visitTrackingDisclosureStorage.
  ///
  /// In en, this message translates to:
  /// **'Recorded points stay on this phone until they reach your company\'s server, including points recorded without a connection. To draw a visit\'s route along roads, its points may be sent to your company\'s map-matching service.'**
  String get visitTrackingDisclosureStorage;

  /// No description provided for @visitTrackingDisclosureAndroid.
  ///
  /// In en, this message translates to:
  /// **'A notification stays visible for as long as a visit is being recorded.'**
  String get visitTrackingDisclosureAndroid;

  /// No description provided for @visitTrackingDisclosureIos.
  ///
  /// In en, this message translates to:
  /// **'iOS will ask for location access — \"While Using the App\" is enough. iOS shows its location indicator while a visit is being recorded.'**
  String get visitTrackingDisclosureIos;

  /// No description provided for @visitTrackingDisclosureAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get visitTrackingDisclosureAgree;

  /// No description provided for @visitTrackingDisclosureDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get visitTrackingDisclosureDecline;

  /// No description provided for @trailStatusRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording the visit route'**
  String get trailStatusRecording;

  /// No description provided for @trailStatusWaitingSync.
  ///
  /// In en, this message translates to:
  /// **'Route recording starts once the visit reaches the server'**
  String get trailStatusWaitingSync;

  /// No description provided for @trailStatusNoConsent.
  ///
  /// In en, this message translates to:
  /// **'Route not recorded — your agreement is needed'**
  String get trailStatusNoConsent;

  /// No description provided for @trailStatusNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Route paused — allow location access to resume'**
  String get trailStatusNoPermission;

  /// No description provided for @trailStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Route recording couldn\'t start — tap Resume'**
  String get trailStatusUnavailable;

  /// No description provided for @trailStatusResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get trailStatusResume;

  /// No description provided for @routeRecordedTrails.
  ///
  /// In en, this message translates to:
  /// **'Routes recorded today'**
  String get routeRecordedTrails;

  /// Number of recorded GPS points on a route row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String routePointsCount(int count);

  /// No description provided for @routeTrailsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The route of 1 visit couldn\'t be loaded.} other{The routes of {count} visits couldn\'t be loaded.}} Check your connection, then tap Retry.'**
  String routeTrailsLoadFailed(int count);

  /// No description provided for @routeLineRoads.
  ///
  /// In en, this message translates to:
  /// **'Roads'**
  String get routeLineRoads;

  /// No description provided for @routeLineGps.
  ///
  /// In en, this message translates to:
  /// **'Raw GPS'**
  String get routeLineGps;

  /// No description provided for @routeLineMatching.
  ///
  /// In en, this message translates to:
  /// **'Matching to roads…'**
  String get routeLineMatching;

  /// No description provided for @routeLineUnmatched.
  ///
  /// In en, this message translates to:
  /// **'No road match — showing raw GPS'**
  String get routeLineUnmatched;

  /// No description provided for @workdayNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Work day not started'**
  String get workdayNotStarted;

  /// No description provided for @workdayStart.
  ///
  /// In en, this message translates to:
  /// **'Start work day'**
  String get workdayStart;

  /// No description provided for @workdayEnd.
  ///
  /// In en, this message translates to:
  /// **'End work day'**
  String get workdayEnd;

  /// No description provided for @workdayActiveSince.
  ///
  /// In en, this message translates to:
  /// **'Work day active since {time}'**
  String workdayActiveSince(String time);

  /// No description provided for @workdayPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point waiting to upload} other{{count} points waiting to upload}}'**
  String workdayPending(int count);

  /// No description provided for @workdayCaptureOff.
  ///
  /// In en, this message translates to:
  /// **'Location tracking is paused — allow location access to resume'**
  String get workdayCaptureOff;

  /// No description provided for @workdayEndConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End your work day?'**
  String get workdayEndConfirmTitle;

  /// No description provided for @workdayEndConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Location tracking stops and today\'s route is closed.'**
  String get workdayEndConfirmMessage;

  /// No description provided for @workdayNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Workday tracking active'**
  String get workdayNotificationTitle;

  /// No description provided for @workdayNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Location tracking is currently running'**
  String get workdayNotificationText;

  /// No description provided for @workdayStarted.
  ///
  /// In en, this message translates to:
  /// **'Work day started — your route is being recorded'**
  String get workdayStarted;

  /// No description provided for @workdayEnded.
  ///
  /// In en, this message translates to:
  /// **'Work day ended'**
  String get workdayEnded;

  /// No description provided for @workdayEndQueued.
  ///
  /// In en, this message translates to:
  /// **'Work day ended — it will sync when you\'re back online'**
  String get workdayEndQueued;

  /// No description provided for @workdayUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Work-day tracking isn\'t available on this server'**
  String get workdayUnsupported;

  /// No description provided for @workdayLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access is required to record your work day.'**
  String get workdayLocationDenied;

  /// No description provided for @workdayLocationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location access is blocked for this app. Allow it in Settings to start your work day.'**
  String get workdayLocationDeniedForever;

  /// No description provided for @workdayLocationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to start your work day.'**
  String get workdayLocationServiceOff;

  /// No description provided for @workdayOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get workdayOpenSettings;

  /// No description provided for @workdayPreciseOff.
  ///
  /// In en, this message translates to:
  /// **'Precise location is off for this app, so your route can\'t be recorded accurately. Turn on Precise Location in Settings to start your work day.'**
  String get workdayPreciseOff;

  /// No description provided for @workdayDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Work-day location tracking'**
  String get workdayDisclosureTitle;

  /// No description provided for @workdayDisclosureBody.
  ///
  /// In en, this message translates to:
  /// **'While your work day is active, Visits collects this device\'s precise location — also when the app is closed or in the background and while the screen is locked — to record your work-day route and your customer visits for your employer.'**
  String get workdayDisclosureBody;

  /// No description provided for @workdayDisclosureStops.
  ///
  /// In en, this message translates to:
  /// **'Tracking starts only when you tap Start work day, and stops when you tap End work day or sign out.'**
  String get workdayDisclosureStops;

  /// No description provided for @workdayDisclosureStorage.
  ///
  /// In en, this message translates to:
  /// **'Locations are kept on this phone until they reach your company\'s server. To draw routes along roads, recorded points may be sent to your company\'s map-matching service.'**
  String get workdayDisclosureStorage;

  /// No description provided for @workdayDisclosureAndroid.
  ///
  /// In en, this message translates to:
  /// **'A notification stays visible for as long as tracking runs.'**
  String get workdayDisclosureAndroid;

  /// No description provided for @workdayDisclosureIos.
  ///
  /// In en, this message translates to:
  /// **'iOS will ask for location access. Choosing \"Always\" lets recording continue if iOS closes the app during your work day.'**
  String get workdayDisclosureIos;

  /// No description provided for @workdayDisclosureAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get workdayDisclosureAgree;

  /// No description provided for @workdayDisclosureDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get workdayDisclosureDecline;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
