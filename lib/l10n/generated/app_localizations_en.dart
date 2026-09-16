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
  String get commonLoading => 'Loading…';

  @override
  String get commonSearch => 'Search…';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOptional => '(optional)';

  @override
  String get commonLogout => 'Sign out';

  @override
  String get commonRefresh => 'Refresh';

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
  String get unitMinShort => 'min';

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
  String get commonOpenSettings => 'Open settings';

  @override
  String get serverSetupTitle => 'Connect your server';

  @override
  String get serverSetupSubtitle =>
      'Enter your organization\'s server address to get started';

  @override
  String get serverSetupUrlLabel => 'Server URL';

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
  String get serverSetupDatabaseLabel => 'Database name';

  @override
  String get serverSetupDatabaseHint => 'e.g. company-main';

  @override
  String get serverSetupDatabasePrompt =>
      'This server doesn\'t list its databases, so the app can\'t detect yours. Enter your company\'s database name — your administrator can tell you.';

  @override
  String get serverSetupChecking => 'Connecting…';

  @override
  String get serverSetupDetectDb => 'Detect database';

  @override
  String get serverSetupDetecting => 'Detecting…';

  @override
  String serverSetupDetected(String db) {
    return 'Database detected: $db';
  }

  @override
  String get serverSetupDetectFailed =>
      'Couldn\'t detect the database automatically — enter its name manually.';

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
  String get loginChangeServer => 'Change server';

  @override
  String get loginTitle => 'Visits';

  @override
  String get loginSubtitle => 'Sign in to start your field day';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginRoleLabel => 'Sign in as';

  @override
  String get loginUsername => 'Email / Username';

  @override
  String get loginPassword => 'Password';

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
  String get errNetworkUnknown =>
      'A connection problem occurred. Check your internet connection and try again.';

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
  String get unitPercent => '%';

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
  String get customerActionCheckIn => 'Start visit';

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
  String get customerFieldType => 'Type';

  @override
  String get customerFieldEmail => 'Email';

  @override
  String get customerFieldJob => 'Job position';

  @override
  String get customerFieldParent => 'Related company';

  @override
  String get customerFieldTags => 'Tags';

  @override
  String get customerFieldWebsite => 'Website';

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
  String get customerAlreadyCheckedIn => 'You have a visit in progress here';

  @override
  String get customerActiveVisitBadge => 'Visit in progress';

  @override
  String customerCheckInBlocked(String customer) {
    return 'You have a visit in progress at $customer. End it before starting another.';
  }

  @override
  String get customerCheckInBlockedShort => 'Visit in progress elsewhere';

  @override
  String get checkInSuccess => 'Checked-in successfully';

  @override
  String get visitActiveTitle => 'Visit in progress';

  @override
  String get visitActiveEmpty =>
      'No visit in progress.\nPick a customer and start a visit.';

  @override
  String visitStartedAt(String time) {
    return 'Started at $time';
  }

  @override
  String get visitLiveIndicator => 'Live';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapRecenter => 'Centre the map';

  @override
  String get mapOpenDirections => 'Open directions';

  @override
  String get visitNotesLabel => 'Notes (optional)';

  @override
  String get visitActionCheckOut => 'Check-out';

  @override
  String get checkOutSuccess => 'Checked-out successfully';

  @override
  String get employeesTitle => 'Employees';

  @override
  String get employeesEmpty => 'No employees set up yet';

  @override
  String get employeesSearchHint => 'Search employees…';

  @override
  String get createVisitCustomerLabel => 'Customer';

  @override
  String get createVisitEmployeeLabel => 'Employee';

  @override
  String get createVisitDateLabel => 'Visit date';

  @override
  String get createVisitTypeLabel => 'Visit type (optional)';

  @override
  String get createVisitNotesLabel => 'Notes (optional)';

  @override
  String get createVisitStateLabel => 'Initial state';

  @override
  String get visitStateDraft => 'Draft';

  @override
  String get visitStateSubmit => 'Submit';

  @override
  String get visitStateUnderReview => 'Under review';

  @override
  String get visitStateDone => 'Done';

  @override
  String get visitStateCancel => 'Cancelled';

  @override
  String get visitDetailVisitTypeLabel => 'Visit type';

  @override
  String get visitDetailEditVisitType => 'Change visit type';

  @override
  String get visitDetailMarkAsDone => 'Mark as reviewed';

  @override
  String get visitDetailMarkAsDoneSuccess => 'Visit marked as reviewed';

  @override
  String get visitDetailSendToEmployee => 'Send to employee';

  @override
  String get visitDetailSentToEmployeeSuccess => 'Visit sent to employee';

  @override
  String get visitDetailEditState => 'Change state';

  @override
  String get visitDetailPickState => 'Select a status';

  @override
  String get createVisitSuccess => 'Visit created';

  @override
  String get createVisitCustomerRequired => 'Pick a customer';

  @override
  String get createVisitEmployeeRequired => 'Pick an employee';

  @override
  String get createVisitDateRequired => 'Pick a visit date';

  @override
  String get createVisitTooltip => 'New visit';

  @override
  String get createVisitPickType => 'Pick visit type';

  @override
  String get createVisitPickCustomer => 'Pick customer';

  @override
  String get createVisitPickEmployee => 'Pick employee';

  @override
  String get visitsSearchHint => 'Search by customer name…';

  @override
  String get pickerSearchHint => 'Search…';

  @override
  String get pickerNoResults => 'No results';

  @override
  String get groupToday => 'Today';

  @override
  String get groupYesterday => 'Yesterday';

  @override
  String get groupEarlierThisWeek => 'Earlier this week';

  @override
  String get groupEarlier => 'Earlier';

  @override
  String get groupTomorrow => 'Tomorrow';

  @override
  String get groupLaterThisWeek => 'Later this week';

  @override
  String get groupUpcoming => 'Upcoming';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsActive => 'In progress';

  @override
  String get statsCompleted => 'Completed';

  @override
  String get statsPendingReview => 'Pending review';

  @override
  String get statsDone => 'Done';

  @override
  String get visitsHistoryTitle => 'History';

  @override
  String get visitsHistoryEmpty => 'No visits recorded yet';

  @override
  String get visitsListTitle => 'Visits';

  @override
  String get visitsFilterToday => 'Today';

  @override
  String get visitsFilterAll => 'All';

  @override
  String get filterStatusLabel => 'Status';

  @override
  String get filterStatusAll => 'All';

  @override
  String get filterStatusCompleted => 'Completed';

  @override
  String get filterStatusPendingReview => 'Pending review';

  @override
  String get filterStatusIncomplete => 'Incomplete';

  @override
  String get filterTimingLabel => 'Timing';

  @override
  String get filterTimingAll => 'All';

  @override
  String get filterTimingOnTime => 'On schedule';

  @override
  String get filterTimingEarly => 'Early';

  @override
  String get filterTimingOverdue => 'Overdue';

  @override
  String get visitsTodayEmpty => 'No visits scheduled for today';

  @override
  String get visitDetailTitle => 'Visit details';

  @override
  String get visitDetailNotesSection => 'Notes';

  @override
  String get visitDetailNoNotes => 'No notes added';

  @override
  String get visitDetailEditNotes => 'Edit notes';

  @override
  String get visitDetailMetaSection => 'Visit info';

  @override
  String get visitDetailTimelineSection => 'Timeline';

  @override
  String get visitDetailVisitDate => 'Visit date';

  @override
  String get visitDetailVisitType => 'Visit type';

  @override
  String get visitDetailSaveChanges => 'Save changes';

  @override
  String get visitDetailReadOnlyHint =>
      'Only your manager can edit these fields.';

  @override
  String get visitDetailNotesEditableHint =>
      'You can add notes while you are checked-in.';

  @override
  String get visitDetailSaved => 'Changes saved';

  @override
  String get visitDetailDelete => 'Delete visit';

  @override
  String get visitDetailNotStartedYet => 'Not started yet';

  @override
  String get visitDetailNotEndedYet => 'Not ended yet';

  @override
  String get visitDetailOpenCheckInLocation => 'Show check-in location';

  @override
  String get visitDetailOpenCheckOutLocation => 'Show check-out location';

  @override
  String get visitDetailTimelineLocationsSection => 'Timeline & locations';

  @override
  String get visitDetailEditCustomer => 'Change customer';

  @override
  String get visitDetailEditEmployee => 'Change employee';

  @override
  String get visitDetailCustomer => 'Customer';

  @override
  String get visitDetailEmployee => 'Employee';

  @override
  String get visitDetailStatusLabel => 'Status';

  @override
  String get visitDetailStateBadgeDraft => 'Draft';

  @override
  String get visitDetailStateBadgeSubmitted => 'Submitted';

  @override
  String get visitDetailStateBadgeUnderReview => 'Under review';

  @override
  String get visitDetailStateBadgeDone => 'Done';

  @override
  String get confirmDeleteVisitTitle => 'Delete visit';

  @override
  String get confirmDeleteVisitMessage =>
      'Are you sure you want to delete this visit? This action cannot be undone.';

  @override
  String get visitDeletedSuccess => 'Visit deleted';

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
  String get visitsScheduledLabel => 'Scheduled';

  @override
  String get dashboardGreeting => 'Good morning';

  @override
  String get dashboardTodayProgress => 'Today\'s progress';

  @override
  String get dashboardFieldTime => 'Field time';

  @override
  String dashboardFieldHoursValue(String hours) {
    return '$hours h';
  }

  @override
  String get dashboardDaySchedule => 'Your day\'s schedule';

  @override
  String get affordanceScheduled => 'Tap to start the visit';

  @override
  String get affordanceActive => 'Visit in progress';

  @override
  String get affordanceReview => 'Awaiting manager review';

  @override
  String get affordanceApproved => 'Approved';

  @override
  String get affordanceRejected => 'Rejected — redo the visit';

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
  String analyticsVisitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
    );
    return '$_temp0';
  }

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
  String get reviewOutOfRangeBanner =>
      'Out of range · recorded outside the approved location';

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
  String get reportTitle => 'Visit report';

  @override
  String get reportOutcome => 'Visit outcome';

  @override
  String get reportOutcomeDone => 'Successful';

  @override
  String get reportOutcomePostponed => 'Postponed';

  @override
  String get reportOutcomeAbsent => 'Customer absent';

  @override
  String get reportNotes => 'Notes';

  @override
  String get reportNotesHint => 'Write a summary of the visit and key notes...';

  @override
  String get reportPhoto => 'Proof photo';

  @override
  String get reportAddPhoto => 'Add photo';

  @override
  String get reportSignature => 'Customer signature';

  @override
  String get reportSignHere => 'Sign here';

  @override
  String get reportClear => 'Clear';

  @override
  String get reportSubmit => 'Finish and save report';

  @override
  String get createVisitTitle => 'Create a new visit';

  @override
  String get createVisitSectionCustomer => 'Customer';

  @override
  String get createVisitSectionEmployee => 'Field rep';

  @override
  String get createVisitSectionType => 'Visit type';

  @override
  String get createVisitSectionDate => 'Visit date';

  @override
  String get createVisitChange => 'Change';

  @override
  String get createVisitSubmit => 'Create visit';

  @override
  String get visitsHistoryCompletedBadge => 'Completed';

  @override
  String get visitsHistoryIncompleteBadge => 'Incomplete';

  @override
  String get visitsHistoryOverdueBadge => 'Overdue';

  @override
  String get visitDetailOverdueHint =>
      'The scheduled day has passed and the visit hasn\'t been completed yet. Reschedule or follow up.';

  @override
  String get visitExecutedOnTime => 'Completed on schedule';

  @override
  String visitExecutedEarly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Completed $days days earlier than scheduled',
      one: 'Completed 1 day earlier than scheduled',
    );
    return '$_temp0';
  }

  @override
  String visitExecutedLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Completed $days days later than scheduled',
      one: 'Completed 1 day later than scheduled',
    );
    return '$_temp0';
  }

  @override
  String get visitsHistoryRunning => 'Running';

  @override
  String get timelineCheckIn => 'Check-in';

  @override
  String get timelineCheckOut => 'Check-out';

  @override
  String timelineDuration(String value) {
    return '$value min';
  }

  @override
  String get visitRangeInRange => 'In range';

  @override
  String get visitRangeOutOfRange => 'Out of range';

  @override
  String get statusScheduled => 'Scheduled';

  @override
  String get statusActive => 'In progress';

  @override
  String get statusReview => 'Pending review';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get visitDetailScheduledTimeLabel => 'Visit time';

  @override
  String get visitDetailInRange => 'You\'re within the customer\'s range';

  @override
  String get visitDetailOutRange => 'You\'re outside the customer\'s range';

  @override
  String visitDetailRangeMeta(String distance, String radius) {
    return '$distance m away · check-in range $radius m';
  }

  @override
  String get visitDetailOutRangeHint =>
      'Move closer to the customer\'s location to start the visit.';

  @override
  String get visitDetailCheckInTitle => 'Start the visit';

  @override
  String get visitDetailCheckInInRangeSub => 'You\'re in range';

  @override
  String get visitDetailCheckInLocatingSub => 'Locating you…';

  @override
  String get visitDetailCheckInOverride => 'Check in out of range';

  @override
  String get visitDetailElapsedLabel => 'Elapsed time';

  @override
  String visitDetailStartedAt(String time) {
    return 'Started $time';
  }

  @override
  String get visitDetailCheckOutTitle => 'End the visit';

  @override
  String get visitDetailCheckOutSub => 'Your location will be captured';

  @override
  String get visitDetailOnTime => 'Completed on time';

  @override
  String get visitDetailDurationLabel => 'Visit duration';

  @override
  String get timelineCreated => 'Visit created';

  @override
  String get visitShowLocation => 'Show customer location';

  @override
  String get visitDetailCustomerLocationSection => 'Customer location';

  @override
  String get visitDetailNavigate => 'Show customer location on map';

  @override
  String get visitDetailNoCustomerLocation =>
      'This customer has no saved location. Ask your manager to add it.';

  @override
  String visitDetailCheckInStartedAt(String customer) {
    return 'Visit at $customer started — your location was recorded';
  }

  @override
  String get visitLocationDialogTitle => 'Check-in location';

  @override
  String get visitLocationCustomer => 'Customer office';

  @override
  String get visitLocationCheckIn => 'Check-in point';

  @override
  String get visitLocationCheckOut => 'Check-out point';

  @override
  String get visitLocationNotAvailable =>
      'This customer has no saved location. Ask your manager to add it.';

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
  String get offlineCheckInQueued =>
      'Saved locally — will sync when you\'re back online';

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
  String get homeTabCustomers => 'Customers';

  @override
  String get homeTabActive => 'In progress';

  @override
  String get homeTabHistory => 'History';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsServer => 'Change server';

  @override
  String get settingsServerNone => 'Not set';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String settingsVersionValue(String version) {
    return 'Version $version';
  }

  @override
  String profileBuildVersion(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get settingsEditProfile => 'Edit profile';

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
  String get settingsHelp => 'Help & support';

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
  String get wfPurposeRequired => 'Purpose is required';

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
  String get wfNoParticipants => 'No additional participants';

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
  String get wfSearchNoMatch => 'No visits match your search';

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
  String get wfListTitle => 'Visits';

  @override
  String get wfDetailTitle => 'Visit';

  @override
  String get wfStartLocationCaptured => 'Your GPS location will be recorded';

  @override
  String get wfConfirmCancelTitle => 'Cancel visit';

  @override
  String get wfConfirmCancelMessage =>
      'Are you sure you want to cancel this visit?';

  @override
  String get wfScheduledLabel => 'Scheduled';

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
  String get wfHoursShort => 'h';

  @override
  String get wfMinutesShort => 'm';

  @override
  String get wfDaysShort => 'd';

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
  String get trailEmpty => 'No points recorded yet';

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
  String trailDistanceKm(String value) {
    return '$value km';
  }

  @override
  String get trailAvgSpeed => 'Average speed';

  @override
  String trailSpeedKmh(String value) {
    return '$value km/h';
  }

  @override
  String get trailLastFix => 'Last position';

  @override
  String get trailFirstFix => 'First position';

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
  String get trailUploadNow => 'Upload now';

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
  String routeTrailSummary(int points, String km) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points points',
      one: '1 point',
    );
    return '$_temp0 · $km km';
  }

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
  String get routeTrailsPartial =>
      'Some visit routes couldn\'t be loaded. Pull down to try again.';

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
}
