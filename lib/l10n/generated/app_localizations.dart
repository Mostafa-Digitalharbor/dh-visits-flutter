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
  /// **'Customer Visits'**
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

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

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

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get commonOptional;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonLogout;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

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

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Visits'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to start your field day'**
  String get loginSubtitle;

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

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get errInvalidCredentials;

  /// No description provided for @errAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'You must sign in'**
  String get errAuthRequired;

  /// No description provided for @errPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission for this action'**
  String get errPermissionDenied;

  /// No description provided for @errValidation.
  ///
  /// In en, this message translates to:
  /// **'Invalid data — please review and try again'**
  String get errValidation;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Item not found'**
  String get errNotFound;

  /// No description provided for @errLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Customer has no coordinates set'**
  String get errLocationRequired;

  /// No description provided for @errServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error — please try again later'**
  String get errServerError;

  /// No description provided for @errNetworkTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get errNetworkTimeout;

  /// No description provided for @errNetworkUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server'**
  String get errNetworkUnreachable;

  /// No description provided for @errNetworkUnknown.
  ///
  /// In en, this message translates to:
  /// **'A network error occurred'**
  String get errNetworkUnknown;

  /// No description provided for @errLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Enable location services and grant the app permission'**
  String get errLocationPermission;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get errUnknown;

  /// No description provided for @errCustomerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load customer'**
  String get errCustomerLoadFailed;

  /// No description provided for @errLocationSharingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location sharing permission is disabled'**
  String get errLocationSharingDisabled;

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

  /// No description provided for @customerActionCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Start visit'**
  String get customerActionCheckIn;

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

  /// No description provided for @customerActionNearby.
  ///
  /// In en, this message translates to:
  /// **'Show nearby employees ({radius} m)'**
  String customerActionNearby(String radius);

  /// No description provided for @customerAlreadyCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re currently checked in here'**
  String get customerAlreadyCheckedIn;

  /// No description provided for @customerActiveVisitBadge.
  ///
  /// In en, this message translates to:
  /// **'Active visit'**
  String get customerActiveVisitBadge;

  /// No description provided for @customerCheckInBlocked.
  ///
  /// In en, this message translates to:
  /// **'Finish your active visit at {customer} first'**
  String customerCheckInBlocked(String customer);

  /// No description provided for @customerCheckInBlockedShort.
  ///
  /// In en, this message translates to:
  /// **'Visit in progress elsewhere'**
  String get customerCheckInBlockedShort;

  /// No description provided for @checkInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Checked-in successfully'**
  String get checkInSuccess;

  /// No description provided for @visitActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active visit'**
  String get visitActiveTitle;

  /// No description provided for @visitActiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active visit.\nPick a customer and start check-in.'**
  String get visitActiveEmpty;

  /// No description provided for @visitStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started at {time}'**
  String visitStartedAt(String time);

  /// No description provided for @visitLiveIndicator.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get visitLiveIndicator;

  /// No description provided for @visitNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get visitNotesLabel;

  /// No description provided for @visitActionCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get visitActionCheckOut;

  /// No description provided for @checkOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Checked-out successfully'**
  String get checkOutSuccess;

  /// No description provided for @employeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeesTitle;

  /// No description provided for @employeesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No employees set up yet'**
  String get employeesEmpty;

  /// No description provided for @employeesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search employees…'**
  String get employeesSearchHint;

  /// No description provided for @createVisitTitle.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get createVisitTitle;

  /// No description provided for @createVisitCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get createVisitCustomerLabel;

  /// No description provided for @createVisitEmployeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get createVisitEmployeeLabel;

  /// No description provided for @createVisitDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get createVisitDateLabel;

  /// No description provided for @createVisitTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit type (optional)'**
  String get createVisitTypeLabel;

  /// No description provided for @createVisitNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get createVisitNotesLabel;

  /// No description provided for @createVisitSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create visit'**
  String get createVisitSubmit;

  /// No description provided for @createVisitSuccess.
  ///
  /// In en, this message translates to:
  /// **'Visit created'**
  String get createVisitSuccess;

  /// No description provided for @createVisitCustomerRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a customer'**
  String get createVisitCustomerRequired;

  /// No description provided for @createVisitEmployeeRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick an employee'**
  String get createVisitEmployeeRequired;

  /// No description provided for @createVisitDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a visit date'**
  String get createVisitDateRequired;

  /// No description provided for @createVisitTooltip.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get createVisitTooltip;

  /// No description provided for @createVisitPickType.
  ///
  /// In en, this message translates to:
  /// **'Pick visit type'**
  String get createVisitPickType;

  /// No description provided for @createVisitPickCustomer.
  ///
  /// In en, this message translates to:
  /// **'Pick customer'**
  String get createVisitPickCustomer;

  /// No description provided for @createVisitPickEmployee.
  ///
  /// In en, this message translates to:
  /// **'Pick employee'**
  String get createVisitPickEmployee;

  /// No description provided for @visitsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by customer name…'**
  String get visitsSearchHint;

  /// No description provided for @pickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get pickerSearchHint;

  /// No description provided for @pickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get pickerNoResults;

  /// No description provided for @visitsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get visitsHistoryTitle;

  /// No description provided for @visitsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No visits recorded yet'**
  String get visitsHistoryEmpty;

  /// No description provided for @visitsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsListTitle;

  /// No description provided for @visitsFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get visitsFilterToday;

  /// No description provided for @visitsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get visitsFilterAll;

  /// No description provided for @visitsTodayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No visits scheduled for today'**
  String get visitsTodayEmpty;

  /// No description provided for @visitDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit details'**
  String get visitDetailTitle;

  /// No description provided for @visitDetailNotesSection.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get visitDetailNotesSection;

  /// No description provided for @visitDetailNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes added'**
  String get visitDetailNoNotes;

  /// No description provided for @visitDetailEditNotes.
  ///
  /// In en, this message translates to:
  /// **'Edit notes'**
  String get visitDetailEditNotes;

  /// No description provided for @visitDetailMetaSection.
  ///
  /// In en, this message translates to:
  /// **'Visit info'**
  String get visitDetailMetaSection;

  /// No description provided for @visitDetailTimelineSection.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get visitDetailTimelineSection;

  /// No description provided for @visitDetailVisitDate.
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get visitDetailVisitDate;

  /// No description provided for @visitDetailVisitType.
  ///
  /// In en, this message translates to:
  /// **'Visit type'**
  String get visitDetailVisitType;

  /// No description provided for @visitDetailSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get visitDetailSaveChanges;

  /// No description provided for @visitDetailReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Only your manager can edit these fields.'**
  String get visitDetailReadOnlyHint;

  /// No description provided for @visitDetailNotesEditableHint.
  ///
  /// In en, this message translates to:
  /// **'You can add notes while you are checked-in.'**
  String get visitDetailNotesEditableHint;

  /// No description provided for @visitDetailSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get visitDetailSaved;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleUser.
  ///
  /// In en, this message translates to:
  /// **'Field employee'**
  String get roleUser;

  /// No description provided for @visitsHistoryActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get visitsHistoryActiveBadge;

  /// No description provided for @visitsHistoryCompletedBadge.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get visitsHistoryCompletedBadge;

  /// No description provided for @visitsHistoryIncompleteBadge.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get visitsHistoryIncompleteBadge;

  /// No description provided for @visitsHistoryRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get visitsHistoryRunning;

  /// No description provided for @timelineCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get timelineCheckIn;

  /// No description provided for @timelineCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get timelineCheckOut;

  /// No description provided for @timelineDuration.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String timelineDuration(String value);

  /// No description provided for @visitRangeInRange.
  ///
  /// In en, this message translates to:
  /// **'In range'**
  String get visitRangeInRange;

  /// No description provided for @visitRangeOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Out of range'**
  String get visitRangeOutOfRange;

  /// No description provided for @visitShowLocation.
  ///
  /// In en, this message translates to:
  /// **'Show customer location'**
  String get visitShowLocation;

  /// No description provided for @visitDetailCustomerLocationSection.
  ///
  /// In en, this message translates to:
  /// **'Customer location'**
  String get visitDetailCustomerLocationSection;

  /// No description provided for @visitDetailNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get visitDetailNavigate;

  /// No description provided for @visitDetailNoCustomerLocation.
  ///
  /// In en, this message translates to:
  /// **'Customer location not available'**
  String get visitDetailNoCustomerLocation;

  /// No description provided for @visitDetailCheckInStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Visit at {customer} started — your location was recorded'**
  String visitDetailCheckInStartedAt(String customer);

  /// No description provided for @visitLocationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in location'**
  String get visitLocationDialogTitle;

  /// No description provided for @visitLocationCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer office'**
  String get visitLocationCustomer;

  /// No description provided for @visitLocationCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in point'**
  String get visitLocationCheckIn;

  /// No description provided for @visitLocationCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out point'**
  String get visitLocationCheckOut;

  /// No description provided for @visitLocationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Customer location not available'**
  String get visitLocationNotAvailable;

  /// No description provided for @homeTabCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get homeTabCustomers;

  /// No description provided for @homeTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get homeTabActive;

  /// No description provided for @homeTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get homeTabHistory;

  /// No description provided for @homeLocationSharingOn.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is on'**
  String get homeLocationSharingOn;

  /// No description provided for @homeLocationSharingOff.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is off'**
  String get homeLocationSharingOff;

  /// No description provided for @nearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby employees'**
  String get nearbyTitle;

  /// No description provided for @nearbyRadiusLabel.
  ///
  /// In en, this message translates to:
  /// **'Radius: {radius} meters'**
  String nearbyRadiusLabel(String radius);

  /// No description provided for @nearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No employees within range'**
  String get nearbyEmpty;

  /// No description provided for @nearbyLastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update: {time}'**
  String nearbyLastUpdate(String time);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

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
