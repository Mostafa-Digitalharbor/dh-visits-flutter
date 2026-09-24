// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Visits';

  @override
  String get appTagline => 'Track your field visits with precision';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSearch => 'Search…';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonLogout => 'Sign out';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonNoValue => '—';

  @override
  String commonLabeledValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String commonCoordinates(String lat, String lng) {
    return '$lat, $lng';
  }

  @override
  String get commonListSeparator => ' · ';

  @override
  String commonRefreshFailedStale(String reason) {
    return '$reason Showing the last loaded data — pull down to try again.';
  }

  @override
  String commonTimeRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String commonDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes m';
  }

  @override
  String commonDurationHours(int hours) {
    return '$hours h';
  }

  @override
  String commonDurationMinutes(int minutes) {
    return '$minutes m';
  }

  @override
  String commonErrorReference(String code) {
    return 'Error code: $code';
  }

  @override
  String get commonGreetingMorning => 'Good morning';

  @override
  String get commonGreetingAfternoon => 'Good afternoon';

  @override
  String get commonGreetingEvening => 'Good evening';

  @override
  String get commonPageNotFoundTitle => 'Page not found';

  @override
  String get commonPageNotFoundMessage =>
      'This link doesn\'t open anything in the app. Go back to the home screen and try again from there.';

  @override
  String get commonGoHome => 'Go to home screen';

  @override
  String commonFraction(String done, String total) {
    return '$done/$total';
  }

  @override
  String badgeOverflow(int max) {
    return '$max+';
  }

  @override
  String visitFallbackTitle(int id) {
    return 'Visit #$id';
  }

  @override
  String unitMeters(String value) {
    return '$value m';
  }

  @override
  String unitMinutes(String value) {
    return '$value min';
  }

  @override
  String unitKm(String value) {
    return '$value km';
  }

  @override
  String unitKmh(String value) {
    return '$value km/h';
  }

  @override
  String unitPercentValue(String value) {
    return '$value%';
  }

  @override
  String get relativeNow => 'Now';

  @override
  String relativeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String relativeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String relativeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get themeMode => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageCodeShortArabic => 'ع';

  @override
  String get languageCodeShortEnglish => 'EN';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get serverSetupTitle => 'Connect your server';

  @override
  String get serverSetupSubtitle =>
      'Enter your organization\'s server address to get started';

  @override
  String get serverSetupUrlHint => 'https://your-company.odoo.com';

  @override
  String get serverSetupContinue => 'Continue';

  @override
  String get serverSetupInvalidUrl =>
      'Enter a valid server address (for example https://your-company.odoo.com).';

  @override
  String get serverSetupHelp =>
      'Ask your system administrator if you don\'t know your server address.';

  @override
  String get serverSetupDatabaseHint => 'e.g. company-main';

  @override
  String get serverSetupDatabasePrompt =>
      'This server doesn\'t list its databases, so the app can\'t detect yours. Enter your company\'s database name — your administrator can tell you.';

  @override
  String get serverSetupDetectDb => 'Detect database';

  @override
  String get serverSetupDetecting => 'Detecting…';

  @override
  String serverSetupDetected(String db) {
    return 'Database detected: $db';
  }

  @override
  String get serverSetupInsecureUrl =>
      'This address starts with http://, so your password would travel unencrypted. Enter your server\'s https:// address — ask your administrator if you don\'t know it.';

  @override
  String serverSetupUnreachable(String host) {
    return 'Couldn\'t reach $host. Check the address for typos and make sure you\'re connected to the internet, then try again.';
  }

  @override
  String serverSetupTimeout(String host) {
    return '$host took too long to answer. Check your connection and try again; if it keeps happening, the server may be down — contact your administrator.';
  }

  @override
  String serverSetupNotOdoo(String host) {
    return '$host answered, but it isn\'t an Odoo server. Enter the address you use to open Odoo in your browser. If you\'re on public Wi-Fi, sign in to the Wi-Fi first.';
  }

  @override
  String serverSetupUntrustedCertificate(String host) {
    return 'The security certificate of $host isn\'t trusted, so the app won\'t send your password there. Check the address with your administrator — the server needs a valid security certificate.';
  }

  @override
  String serverSetupServerDown(String host) {
    return '$host is having problems right now, possibly maintenance. Wait a few minutes and try again; if it persists, contact your administrator.';
  }

  @override
  String serverSetupSeveralDatabases(String databases) {
    return 'This server hosts several databases ($databases). Enter the one your company uses.';
  }

  @override
  String serverSetupDatabaseMissing(String db) {
    return 'This server has no database named “$db”. Check the spelling, or clear the field and tap “Detect database”.';
  }

  @override
  String get serverSetupSaveFailed =>
      'Couldn\'t save the server settings on this device. Try again; if it keeps failing, restart the app.';

  @override
  String get loginTitle => 'Visits';

  @override
  String get loginSubtitle => 'Sign in to start your field day';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginUsername => 'Email / Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authSwitchToDarkTheme => 'Switch to dark theme';

  @override
  String get authSwitchToLightTheme => 'Switch to light theme';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginRememberMe => 'Remember me';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginForgotPasswordTitle => 'Reset your password';

  @override
  String get loginForgotPasswordBody =>
      'Password resets are handled by your administrator. Please contact your system administrator to reset your password.';

  @override
  String get loginSecureFooter => 'Secure sign-in · Digital Harbor';

  @override
  String get loginInvalidCredentials =>
      'The username or password is incorrect. Check both and try again — your administrator can reset your password.';

  @override
  String get loginTwoFactorUnsupported =>
      'Your account uses two-step verification, which this app doesn\'t support yet. Ask your administrator to turn it off for your account, then sign in again.';

  @override
  String get loginNoVisitRole =>
      'Your account has no access to Visits. Ask your administrator to give you a Visits role (user or manager), then sign in again.';

  @override
  String get loginSessionEnded =>
      'You were signed out because your session ended on the server. Sign in again to continue.';

  @override
  String get errInvalidCredentials =>
      'The email/username or password is incorrect. Check them and try again.';

  @override
  String get errAuthRequired =>
      'Your session has ended. Sign in again to continue.';

  @override
  String get errPermissionDenied =>
      'You don\'t have permission to do this. If you need it, ask your manager or administrator.';

  @override
  String get errValidation =>
      'Some of the information you entered wasn\'t accepted. Review it and try again.';

  @override
  String get errNotVisitApprover =>
      'You aren\'t an approver for this visit. Only a manager in the owner\'s reporting line can approve or reject it.';

  @override
  String get errOnlyApprovedCanStart =>
      'This visit must be approved before you can start it. Submit it for approval if you haven\'t, then wait for your manager\'s decision.';

  @override
  String get errOnlyInProgressCanEnd =>
      'This visit isn\'t in progress, so it can\'t be ended. Refresh to check its status — it may not have started yet or may already be ended.';

  @override
  String get errOnlyDraftCanSubmit =>
      'This visit can\'t be submitted because it isn\'t a draft, a rejected visit or a rescheduled visit. Refresh to see its current status.';

  @override
  String get errCannotApproveInState =>
      'This visit can\'t be approved in its current state. Refresh to see where it stands.';

  @override
  String get errAttendeesPending =>
      'This visit can\'t be approved yet — every attendee has to be approved by their manager first. Try again once the attendee approvals are done.';

  @override
  String get errCannotRejectInState =>
      'This visit can\'t be rejected in its current state. Refresh to see where it stands.';

  @override
  String get errOutcomeRequired =>
      'Add the visit outcome before ending the visit.';

  @override
  String errMissingRequiredField(String field) {
    return 'Fill in the required field “$field”, then try again.';
  }

  @override
  String get errMissingRequiredFieldGeneric =>
      'A required field is empty. Fill in all required fields and try again.';

  @override
  String get errAttendeeAlreadyDecided =>
      'This participant request has already been approved or rejected. Refresh to see the latest decision.';

  @override
  String get errCannotRescheduleFinished =>
      'This visit is already finished, so it can\'t be rescheduled. Create a new visit instead.';

  @override
  String get errProjectRequired =>
      'Choose the project this visit is for, then try again.';

  @override
  String get errOpportunityRequired =>
      'Choose the opportunity this visit is for, then try again.';

  @override
  String get errTrailVisitNotStarted =>
      'Your route can\'t be recorded because this visit hasn\'t started. Start the visit first.';

  @override
  String get errTrailVisitEnded =>
      'This visit has already ended, so no more route points can be added to it. No action is needed.';

  @override
  String get errRecordInUse =>
      'This item is linked to other information, so it can\'t be changed or removed. Contact your administrator if it needs to change.';

  @override
  String get errNotFound =>
      'This item couldn\'t be found — it may have been deleted. Refresh and try again.';

  @override
  String get errLocationRequired =>
      'This customer has no saved location, so the visit can\'t be recorded. Ask your manager or administrator to add the customer\'s location.';

  @override
  String get errServerError =>
      'The server ran into a problem. Try again in a few minutes; if it keeps happening, contact your administrator.';

  @override
  String get errServerUnavailable =>
      'The server is temporarily unavailable, usually for maintenance. Wait a few minutes and try again.';

  @override
  String get errRateLimited =>
      'Too many requests in a short time. Wait a minute, then try again.';

  @override
  String get errPayloadTooLarge =>
      'This file is too large to upload. Choose a smaller file or a lower-resolution photo.';

  @override
  String get errInvalidResponse =>
      'The server sent a reply the app couldn\'t read. If you\'re on public Wi-Fi, sign in to it first; otherwise check the server address with your administrator.';

  @override
  String get errDatabaseNotFound =>
      'The company database wasn\'t found on this server. Check the database name in the server settings, or ask your administrator for the correct one.';

  @override
  String get errNetworkTimeout =>
      'The server took too long to respond. Check your internet connection and try again.';

  @override
  String get errNetworkUnreachable =>
      'Can\'t reach the server. Check your internet connection (Wi-Fi or mobile data) and try again.';

  @override
  String get errLocationPermission =>
      'The app can\'t access your location. Turn on location services, allow the app to use your location, then try again.';

  @override
  String get errLocationNeededForVisit =>
      'Your location is required to record this visit. Turn on location services, allow the app to use them, then try again.';

  @override
  String get errLocationUnavailable =>
      'Couldn\'t determine your location. Move somewhere with a clearer view of the sky and try again.';

  @override
  String get errUnknown =>
      'Something went wrong on our side. Please try again — if it keeps happening, send a screenshot to your administrator.';

  @override
  String get errSessionRestoreFailed =>
      'We couldn\'t reopen your saved session. Please sign in again to continue.';

  @override
  String get errProfileIncomplete =>
      'We couldn\'t load your permissions, so visit actions are hidden. Sign out and back in — if it persists, ask your administrator to check your visit role.';

  @override
  String get pushChannelName => 'Visit updates';

  @override
  String get pushChannelDescription =>
      'Approvals, reschedules and status changes for your visits.';

  @override
  String get pushEventSubmitted => 'A visit needs your approval';

  @override
  String get pushEventParticipationApproval =>
      'An attendee needs your approval';

  @override
  String get pushEventReadyForApproval => 'A visit is ready for your approval';

  @override
  String get pushEventApproved => 'Visit approved';

  @override
  String get pushEventRejected => 'Visit rejected';

  @override
  String get pushEventParticipantRejected => 'An attendee was declined';

  @override
  String get pushEventRescheduleRequested => 'A reschedule needs your approval';

  @override
  String get pushEventRescheduleApproved => 'Reschedule approved';

  @override
  String get pushEventEscalated => 'A visit was escalated to you';

  @override
  String get pushEventStarted => 'Visit started';

  @override
  String get pushEventCompleted => 'Visit completed';

  @override
  String get pushEventCancelled => 'Visit cancelled';

  @override
  String get pushEventUpdated => 'Visit updated';

  @override
  String unitBytes(String size) {
    return '$size B';
  }

  @override
  String unitKilobytes(String size) {
    return '$size KB';
  }

  @override
  String unitMegabytes(String size) {
    return '$size MB';
  }

  @override
  String offlineActionDropped(String reason) {
    return 'Your offline update wasn\'t saved. $reason Open the visit and record it again.';
  }

  @override
  String get errConflict =>
      'This visit was already updated somewhere else. Pull down to refresh and check its current status before trying again.';

  @override
  String get errInsecureConnection =>
      'Couldn\'t open a secure connection to the server. Its security certificate isn\'t trusted — check the server address with your administrator.';

  @override
  String get errCustomerLoadFailed =>
      'Couldn\'t load this customer\'s details. Check your internet connection and try again.';

  @override
  String get errAttachmentOpenFailed =>
      'Couldn\'t open this attachment. Make sure your phone has an app that can open this type of file, then try again.';

  @override
  String get errAttachmentUnavailable =>
      'This attachment is no longer available — pull down to refresh.';

  @override
  String get errAttachmentsLoadFailed =>
      'Couldn\'t load the attachments. Check your internet connection, then pull down to try again.';

  @override
  String get attachmentsEmpty => 'No attachments yet';

  @override
  String get errCannotLaunchApp =>
      'No app on your phone can handle this (for example a phone, email or maps app). Install or enable one, then try again.';

  @override
  String get errActionFailed =>
      'Couldn\'t complete this action because of an unexpected problem. Refresh and try again — if it keeps failing, contact your administrator.';

  @override
  String get errFeatureNotAvailable =>
      'This feature isn\'t enabled on your company\'s server yet. Ask your administrator to enable it.';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customersSearchHint => 'Search customers…';

  @override
  String get customersEmpty => 'No customers found';

  @override
  String get customersStatTotal => 'Total customers';

  @override
  String get customersStatActive => 'Active customers';

  @override
  String get customerDetailTitle => 'Customer details';

  @override
  String get customerLastVisit => 'Last visit';

  @override
  String get customerActionCall => 'Call';

  @override
  String get customerActionNavigate => 'Navigate';

  @override
  String get customerActionEmail => 'Email';

  @override
  String get customerTypeCompany => 'Company';

  @override
  String get customerTypeIndividual => 'Individual';

  @override
  String get customerSectionInfo => 'Contact details';

  @override
  String get customerFieldJob => 'Job position';

  @override
  String get customerFieldParent => 'Related company';

  @override
  String get customerFieldTags => 'Tags';

  @override
  String get customerFieldVat => 'Tax ID';

  @override
  String get customerFieldCoordinates => 'Coordinates';

  @override
  String get customerAddressSeparator => ', ';

  @override
  String get customerNotFound =>
      'This customer no longer exists, or you no longer have access to it. Go back and refresh the customer list.';

  @override
  String get mapOpenDirections => 'Open directions';

  @override
  String get employeesSearchHint => 'Search employees…';

  @override
  String get createVisitTooltip => 'New visit';

  @override
  String get pickerNoResults => 'No results';

  @override
  String get visitsListTitle => 'Visits';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleUser => 'Field rep';

  @override
  String get roleProjectManager => 'Project manager';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleManagerTitle => 'Team manager';

  @override
  String get roleEmployeeTitle => 'Field rep';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileTabTitle => 'Profile';

  @override
  String get visitsHistoryActiveBadge => 'In progress';

  @override
  String get dashboardTodayProgress => 'Today\'s progress';

  @override
  String get dashboardFieldTime => 'Field time';

  @override
  String dashboardFieldHoursValue(String hours) {
    return '$hours h';
  }

  @override
  String get analyticsTabTitle => 'Analytics';

  @override
  String get analyticsOnTime => 'On time';

  @override
  String get analyticsVisitsThisWeek => 'visits this week';

  @override
  String get analyticsKm => 'km in the field';

  @override
  String get analyticsAvgDuration => 'Avg. visit duration';

  @override
  String get analyticsWeeklyTitle => 'Visits this week';

  @override
  String get analyticsWeeklyCompare => 'vs. last week';

  @override
  String get analyticsByEmployee => 'By employee';

  @override
  String get reviewTitle => 'Review visits';

  @override
  String reviewPendingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n visits awaiting your approval',
      one: '1 visit awaiting your approval',
      zero: 'No visits awaiting your approval',
    );
    return '$_temp0';
  }

  @override
  String get reviewApprove => 'Approve';

  @override
  String get reviewReject => 'Reject';

  @override
  String get reviewEmpty => 'No visits awaiting review';

  @override
  String get reviewApproved => 'Visit approved';

  @override
  String get reviewRejected => 'Visit rejected';

  @override
  String get routeTabTitle => 'Today\'s route';

  @override
  String get routeStops => 'Stops';

  @override
  String routeStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String get routeTotalDistance => 'Total distance';

  @override
  String get routeNextStop => 'Next stop';

  @override
  String get routeStartPoint => 'Start point';

  @override
  String routeDriveMinutes(int n) {
    return '$n min drive';
  }

  @override
  String get routeStartNav => 'Start navigation';

  @override
  String get routeEmpty => 'No stops on today\'s route';

  @override
  String get createVisitSubmit => 'Create visit';

  @override
  String get visitsHistoryCompletedBadge => 'Completed';

  @override
  String get visitDetailInRange => 'You\'re within the customer\'s range';

  @override
  String get visitDetailOutRange => 'You\'re outside the customer\'s range';

  @override
  String get offlineNoQueue =>
      'You\'re offline — your actions will be saved on this device and sent when you reconnect.';

  @override
  String offlineWithQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Offline — $count actions waiting to sync',
      one: 'Offline — 1 action waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String offlineSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Syncing $count pending actions…',
      one: 'Syncing 1 pending action…',
    );
    return '$_temp0';
  }

  @override
  String offlinePendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count actions are still pending — check your connection and try again.',
      one: '1 action is still pending — check your connection and try again.',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTabTitle => 'Dashboard';

  @override
  String get dashboardKpiOverdue => 'Overdue';

  @override
  String get dashboardKpiPending => 'Pending review';

  @override
  String get dashboardKpiToday => 'Today';

  @override
  String get dashboardKpiActive => 'In progress';

  @override
  String get dashboardActiveOnMapTitle => 'Employees in the field';

  @override
  String get dashboardActiveEmpty => 'No employees are on a visit right now';

  @override
  String dashboardActiveMore(int count) {
    return '+$count more';
  }

  @override
  String get dashboardTopCustomers => 'Most-visited customers';

  @override
  String get dashboardTopEmployees => 'Top employees (completed visits)';

  @override
  String get dashboardNoData => 'Not enough data yet';

  @override
  String get visitsTabTitle => 'Visits';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsServer => 'Change server';

  @override
  String get settingsServerNone => 'Not set';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersionValue(String version) {
    return 'Version $version';
  }

  @override
  String profileBuildVersion(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSub => 'Visit alerts and reminders';

  @override
  String get settingsLastSync => 'Last sync';

  @override
  String get settingsSyncNow => 'Sync now';

  @override
  String get settingsSynced => 'Synced';

  @override
  String get settingsSyncNothingPending => 'Nothing pending';

  @override
  String settingsSyncPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions waiting to sync',
      one: '1 action waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get confirmLogoutTitle => 'Sign out';

  @override
  String get confirmLogoutMessage => 'Are you sure you want to sign out?';

  @override
  String get confirmExitTitle => 'Exit app';

  @override
  String get confirmExitMessage => 'Are you sure you want to exit the app?';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get aboutAppName => 'Customer Visits';

  @override
  String get aboutLegalese => '© 2026 Digital Harbor';

  @override
  String get aboutFooter => 'Customer Visits · Digital Harbor © 2026';

  @override
  String get wfStateDraft => 'Draft';

  @override
  String get wfStateSubmitted => 'Submitted';

  @override
  String get wfStateWaitingParticipant => 'Awaiting participants\' managers';

  @override
  String get wfStateWaitingManager => 'Awaiting manager approval';

  @override
  String get wfStateEscalated => 'Escalated';

  @override
  String get wfStateApproved => 'Approved';

  @override
  String get wfStateRejected => 'Rejected';

  @override
  String get wfStateCancelled => 'Cancelled';

  @override
  String get wfStateReschedule => 'Reschedule requested';

  @override
  String get wfStateInProgress => 'In progress';

  @override
  String get wfStateDone => 'Done';

  @override
  String get wfStateUnknown => '—';

  @override
  String get wfScopeMine => 'My visits';

  @override
  String get wfScopePending => 'Pending';

  @override
  String get wfScopeTeam => 'Team';

  @override
  String get wfScopeEscalated => 'Escalated';

  @override
  String get wfActionSubmit => 'Submit for approval';

  @override
  String get wfActionApprove => 'Approve';

  @override
  String get wfActionReject => 'Reject';

  @override
  String get wfActionReschedule => 'Request reschedule';

  @override
  String get wfActionStart => 'Start visit';

  @override
  String get wfApproveWaitsForAttendees =>
      'Approval opens once every attendee has been approved.';

  @override
  String get wfActionEnd => 'End visit';

  @override
  String get wfActionCancel => 'Cancel visit';

  @override
  String get wfActionAddParticipant => 'Add participant';

  @override
  String get wfActionAddAttachment => 'Add attachment';

  @override
  String wfActionAddAttachmentCount(int count) {
    return 'Add attachment ($count)';
  }

  @override
  String get wfTypeProject => 'Project';

  @override
  String get wfTypeOpportunity => 'Opportunity';

  @override
  String get wfFieldType => 'Visit type';

  @override
  String get wfFieldProject => 'Project';

  @override
  String get wfFieldOpportunity => 'Opportunity';

  @override
  String get wfFieldCustomer => 'Customer';

  @override
  String wfLinkedCustomer(String name) {
    return 'Customer: $name';
  }

  @override
  String wfOptionalField(String label) {
    return '$label (optional)';
  }

  @override
  String wfLabelColon(String label) {
    return '$label:';
  }

  @override
  String get wfFieldSchedule => 'Scheduled date & time';

  @override
  String get wfFieldPurpose => 'Purpose';

  @override
  String get wfFieldLocation => 'Location';

  @override
  String get wfFieldOutcome => 'Outcome';

  @override
  String get wfFieldResponsible => 'Responsible employee';

  @override
  String get wfFieldParticipants => 'Additional participants';

  @override
  String get wfFieldDirectManager => 'Direct manager';

  @override
  String get wfFieldHigherManager => 'Higher manager';

  @override
  String get wfPickProject => 'Select project';

  @override
  String get wfPickOpportunity => 'Select opportunity';

  @override
  String get wfPickEmployee => 'Select employee';

  @override
  String get wfSelfLabel => 'Myself';

  @override
  String get wfPlanForMyself => 'Plan it for myself';

  @override
  String get wfOutcomeRequired => 'Outcome is required to end the visit';

  @override
  String get wfRejectReason => 'Rejection reason';

  @override
  String get wfRejectReasonHint => 'Explain why this visit is rejected…';

  @override
  String get wfReasonRequired => 'A reason is required';

  @override
  String get wfCreateTitle => 'New visit';

  @override
  String get wfCreated => 'Visit created';

  @override
  String wfParticipantsNotAdded(String reason) {
    return 'The visit was created, but its participants weren\'t added. $reason Tap “Add participants again” to retry, or open the visit without them.';
  }

  @override
  String get wfRetryAddParticipants => 'Add participants again';

  @override
  String get wfOpenCreatedVisit => 'Open the visit';

  @override
  String get wfSubmitted => 'Submitted for approval';

  @override
  String get wfApproved => 'Visit approved';

  @override
  String get wfRejected => 'Visit rejected';

  @override
  String get wfStarted => 'Visit started';

  @override
  String get wfEnded => 'Visit completed';

  @override
  String get wfRescheduled => 'Reschedule requested';

  @override
  String get wfCancelled => 'Visit cancelled';

  @override
  String get wfAttachmentAdded => 'Attachment added';

  @override
  String wfAttachmentTooLarge(String size, String limit) {
    return 'This file is $size, which is over the $limit limit. Choose a smaller file or compress it, then try again.';
  }

  @override
  String get wfAttachmentUnreadable =>
      'Couldn\'t read the selected file. Choose it again or pick a different file.';

  @override
  String get wfCameraUnavailable =>
      'Couldn\'t open the camera. Close any other app that is using it, then try again.';

  @override
  String get wfFilePickerUnavailable =>
      'Couldn\'t open your files. Please try again; if it keeps failing, restart the app.';

  @override
  String get wfCameraAccessTitle => 'Camera access needed';

  @override
  String get wfCameraAccessMessage =>
      'Visits isn\'t allowed to use the camera. Allow camera access for the app in Settings, then try again.';

  @override
  String get wfFilesAccessTitle => 'Photo and file access needed';

  @override
  String get wfFilesAccessMessage =>
      'Visits isn\'t allowed to open your photos and files. Allow access for the app in Settings, then try again.';

  @override
  String get wfOpenSettings => 'Open settings';

  @override
  String get wfParticipantApproved => 'Participant approved';

  @override
  String get wfParticipantRejected => 'Participant rejected';

  @override
  String get wfParticipantsAdded => 'Participants added';

  @override
  String get wfApprovalHistory => 'Approval history';

  @override
  String get wfSubmittedOn => 'Submitted on';

  @override
  String get wfApprovedByOn => 'Approved by';

  @override
  String get wfRejectedByOn => 'Rejected by';

  @override
  String get wfReason => 'Reason';

  @override
  String get wfEscalatedBadge => 'Escalated';

  @override
  String get wfParticipantsSection => 'Participants';

  @override
  String get wfParticipantPending => 'Pending';

  @override
  String get wfParticipantApprovedState => 'Approved';

  @override
  String get wfParticipantRejectedState => 'Rejected';

  @override
  String get wfUnknownEmployee => 'Unknown employee';

  @override
  String get wfApproveParticipant => 'Approve';

  @override
  String get wfRejectParticipant => 'Reject';

  @override
  String get wfEmptyMine => 'You have no visits yet';

  @override
  String get wfEmptyPending => 'Nothing awaiting your approval';

  @override
  String get wfEmptyTeam => 'No team visits';

  @override
  String get wfEmptyEscalated => 'No escalated visits';

  @override
  String get wfSearchHint => 'Search by customer, reference or purpose…';

  @override
  String get wfSearchNoMatch =>
      'No visits in this list match your search. Try another list above, or pull down to refresh.';

  @override
  String get wfFilterNoMatch =>
      'No visits match this filter. Clear the filter to see all your visits.';

  @override
  String get wfClearFilter => 'Clear filter';

  @override
  String get wfRescheduleTitle => 'Request reschedule';

  @override
  String get wfRescheduleNoChanges =>
      'Nothing has changed. Change the date, purpose or location before sending the request.';

  @override
  String get wfDetailTitle => 'Visit';

  @override
  String get wfConfirmCancelTitle => 'Cancel visit';

  @override
  String get wfConfirmCancelMessage =>
      'Are you sure you want to cancel this visit?';

  @override
  String get wfStartedLabel => 'Started';

  @override
  String get wfEndedLabel => 'Ended';

  @override
  String get wfFieldStartLocation => 'Start location';

  @override
  String get wfFieldEndLocation => 'End location';

  @override
  String get wfDurationLabel => 'Duration';

  @override
  String get wfSectionVisitInfo => 'Visit details';

  @override
  String get wfSectionApproval => 'Team & approval';

  @override
  String get wfSectionExecution => 'Execution';

  @override
  String get wfSectionAttachments => 'Attachments';

  @override
  String get wfOpenInMaps => 'Open in Maps';

  @override
  String wfRangeDistance(String distance) {
    return '$distance away';
  }

  @override
  String wfRangeRadius(String radius) {
    return 'check-in range $radius';
  }

  @override
  String get wfShortVisitHint => 'Short visit';

  @override
  String get wfNotificationsTitle => 'Notifications';

  @override
  String get wfNotificationsEmpty => 'You\'re all caught up';

  @override
  String wfNotificationsDue(String date) {
    return 'Due $date';
  }

  @override
  String get wfActionTakePhoto => 'Take photo';

  @override
  String get wfMockLocationTitle => 'Fake location detected';

  @override
  String get wfMockLocationMessage =>
      'Your device is reporting a mock (fake) GPS location. This will be flagged for review. Continue anyway?';

  @override
  String get wfQueuedOffline =>
      'Saved offline — it\'ll sync when you\'re back online';

  @override
  String get wfMockFlagBannerTitle => 'Fake location recorded on this visit';

  @override
  String get wfMockFlagBannerBody =>
      'The device reported a mock (fake) GPS location when this visit was started or ended. Review it before approving.';

  @override
  String get trailSectionTitle => 'Route travelled';

  @override
  String get trailMapTitle => 'GPS trail';

  @override
  String get trailEmptyRunning =>
      'Recording your route — the path appears as you move';

  @override
  String get trailEmptyFinished => 'No points were recorded during this visit';

  @override
  String get trailLive => 'Recording';

  @override
  String trailPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
      zero: 'No points',
    );
    return '$_temp0';
  }

  @override
  String get trailDistance => 'Distance';

  @override
  String get trailAvgSpeed => 'Average speed';

  @override
  String get trailLastFix => 'Last position';

  @override
  String get trailOpenFull => 'View full route';

  @override
  String get trailPointStart => 'Start';

  @override
  String get trailPointEnd => 'End';

  @override
  String get trailPointTrack => 'On the way';

  @override
  String get trailPointManual => 'Added manually';

  @override
  String trailAccuracy(String meters) {
    return '±$meters m';
  }

  @override
  String trailPendingUploads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points waiting to upload',
      one: '1 point waiting to upload',
    );
    return '$_temp0';
  }

  @override
  String get trailUploadDone => 'Recorded points uploaded';

  @override
  String trailUploadStillPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count points are still waiting to upload. Check your internet connection; they will upload automatically once you\'re back online.',
      one:
          '1 point is still waiting to upload. Check your internet connection; it will upload automatically once you\'re back online.',
    );
    return '$_temp0';
  }

  @override
  String trailPointsDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count recorded points couldn\'t be saved, so your route has gaps. No action is needed — tell your manager if the route looks wrong.',
      one:
          '1 recorded point couldn\'t be saved, so your route has a gap. No action is needed — tell your manager if the route looks wrong.',
    );
    return '$_temp0';
  }

  @override
  String get trailPointsList => 'Points';

  @override
  String get trailFitRoute => 'Fit route to screen';

  @override
  String get visitTrackingRequired =>
      'A visit can only be started with its route recorded. Tap Start visit again and agree to route recording to continue.';

  @override
  String get visitTrackingNotificationTitle => 'Visit tracking active';

  @override
  String get visitTrackingNotificationText =>
      'Recording the route of your visit';

  @override
  String get visitTrackingDisclosureTitle => 'Visit route recording';

  @override
  String get visitTrackingDisclosureBody =>
      'While a customer visit is in progress, Visits collects this device\'s precise location — also when the app is in the background or not in use and while the screen is locked — to record the route of that visit for your employer.';

  @override
  String get visitTrackingDisclosureStops =>
      'Recording starts only after you tap Start visit and the visit has started, and stops as soon as you end the visit or sign out. No location is recorded before a visit starts, between visits or after a visit ends.';

  @override
  String get visitTrackingDisclosureStorage =>
      'Recorded points stay on this phone until they reach your company\'s server, including points recorded without a connection. To draw a visit\'s route along roads, its points may be sent to your company\'s map-matching service.';

  @override
  String get visitTrackingDisclosureAndroid =>
      'A notification stays visible for as long as a visit is being recorded.';

  @override
  String get visitTrackingDisclosureIos =>
      'iOS will ask for location access — \"While Using the App\" is enough. iOS shows its location indicator while a visit is being recorded.';

  @override
  String get visitTrackingDisclosureAgree => 'Agree and continue';

  @override
  String get visitTrackingDisclosureDecline => 'Not now';

  @override
  String get trailStatusRecording => 'Recording the visit route';

  @override
  String get trailStatusWaitingSync =>
      'Route recording starts once the visit reaches the server';

  @override
  String get trailStatusNoConsent =>
      'Route not recorded — your agreement is needed';

  @override
  String get trailStatusNoPermission =>
      'Route paused — allow location access to resume';

  @override
  String get trailStatusUnavailable =>
      'Route recording couldn\'t start — tap Resume';

  @override
  String get trailStatusResume => 'Resume';

  @override
  String get routeRecordedTrails => 'Routes recorded today';

  @override
  String routePointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String routeTrailsLoadFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The routes of $count visits couldn\'t be loaded.',
      one: 'The route of 1 visit couldn\'t be loaded.',
    );
    return '$_temp0 Check your connection, then tap Retry.';
  }

  @override
  String get routeLineRoads => 'Roads';

  @override
  String get routeLineGps => 'Raw GPS';

  @override
  String get routeLineMatching => 'Matching to roads…';

  @override
  String get routeLineUnmatched => 'No road match — showing raw GPS';

  @override
  String get workdayNotStarted => 'Work day not started';

  @override
  String get workdayStart => 'Start work day';

  @override
  String get workdayEnd => 'End work day';

  @override
  String workdayActiveSince(String time) {
    return 'Work day active since $time';
  }

  @override
  String workdayPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points waiting to upload',
      one: '1 point waiting to upload',
    );
    return '$_temp0';
  }

  @override
  String get workdayCaptureOff =>
      'Location tracking is paused — allow location access to resume';

  @override
  String get workdayEndConfirmTitle => 'End your work day?';

  @override
  String get workdayEndConfirmMessage =>
      'Location tracking stops and today\'s route is closed.';

  @override
  String get workdayNotificationTitle => 'Workday tracking active';

  @override
  String get workdayNotificationText =>
      'Location tracking is currently running';

  @override
  String get workdayStarted =>
      'Work day started — your route is being recorded';

  @override
  String get workdayEnded => 'Work day ended';

  @override
  String get workdayEndQueued =>
      'Work day ended — it will sync when you\'re back online';

  @override
  String get workdayUnsupported =>
      'Work-day tracking isn\'t available on this server';

  @override
  String get workdayLocationDenied =>
      'Location access is required to record your work day.';

  @override
  String get workdayLocationDeniedForever =>
      'Location access is blocked for this app. Allow it in Settings to start your work day.';

  @override
  String get workdayLocationServiceOff =>
      'Turn on location services to start your work day.';

  @override
  String get workdayOpenSettings => 'Open settings';

  @override
  String get workdayPreciseOff =>
      'Precise location is off for this app, so your route can\'t be recorded accurately. Turn on Precise Location in Settings to start your work day.';

  @override
  String get workdayDisclosureTitle => 'Work-day location tracking';

  @override
  String get workdayDisclosureBody =>
      'While your work day is active, Visits collects this device\'s precise location — also when the app is closed or in the background and while the screen is locked — to record your work-day route and your customer visits for your employer.';

  @override
  String get workdayDisclosureStops =>
      'Tracking starts only when you tap Start work day, and stops when you tap End work day or sign out.';

  @override
  String get workdayDisclosureStorage =>
      'Locations are kept on this phone until they reach your company\'s server. To draw routes along roads, recorded points may be sent to your company\'s map-matching service.';

  @override
  String get workdayDisclosureAndroid =>
      'A notification stays visible for as long as tracking runs.';

  @override
  String get workdayDisclosureIos =>
      'iOS will ask for location access. Choosing \"Always\" lets recording continue if iOS closes the app during your work day.';

  @override
  String get workdayDisclosureAgree => 'Agree and continue';

  @override
  String get workdayDisclosureDecline => 'Not now';
}
