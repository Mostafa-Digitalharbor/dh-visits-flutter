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
  String unitMeters(String value) {
    return '$value m';
  }

  @override
  String unitMinutes(String value) {
    return '$value min';
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
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

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
      'Enter a valid URL (e.g. https://your-company.odoo.com)';

  @override
  String get serverSetupHelp =>
      'Ask your system administrator if you don\'t know your server address.';

  @override
  String get serverSetupDatabaseLabel => 'Database name';

  @override
  String get serverSetupDatabaseHint => 'e.g. company-main';

  @override
  String get serverSetupDatabasePrompt =>
      'We couldn\'t detect the database automatically. Please enter its name (ask your administrator).';

  @override
  String get serverSetupChecking => 'Connecting…';

  @override
  String get loginChangeServer => 'Change server';

  @override
  String get loginTitle => 'Visits';

  @override
  String get loginSubtitle => 'Sign in to start your field day';

  @override
  String get loginUsername => 'Email / Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get errInvalidCredentials => 'Invalid credentials';

  @override
  String get errAuthRequired => 'You must sign in';

  @override
  String get errPermissionDenied =>
      'You don\'t have permission for this action';

  @override
  String get errValidation => 'Invalid data — please review and try again';

  @override
  String get errNotFound => 'Item not found';

  @override
  String get errLocationRequired => 'Customer has no coordinates set';

  @override
  String get errServerError => 'Server error — please try again later';

  @override
  String get errNetworkTimeout => 'Connection timed out';

  @override
  String get errNetworkUnreachable => 'Cannot reach the server';

  @override
  String get errNetworkUnknown => 'A network error occurred';

  @override
  String get errLocationPermission =>
      'Enable location services and grant the app permission';

  @override
  String get errUnknown => 'An unknown error occurred';

  @override
  String get errCustomerLoadFailed => 'Failed to load customer';

  @override
  String get errLocationSharingDisabled =>
      'Location sharing permission is disabled';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customersSearchHint => 'Search customers…';

  @override
  String get customersEmpty => 'No customers found';

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
  String customerActionNearby(String radius) {
    return 'Show nearby employees ($radius m)';
  }

  @override
  String get customerAlreadyCheckedIn => 'You\'re currently checked in here';

  @override
  String get customerActiveVisitBadge => 'Active visit';

  @override
  String customerCheckInBlocked(String customer) {
    return 'Finish your active visit at $customer first';
  }

  @override
  String get customerCheckInBlockedShort => 'Visit in progress elsewhere';

  @override
  String get checkInSuccess => 'Checked-in successfully';

  @override
  String get visitActiveTitle => 'Active visit';

  @override
  String get visitActiveEmpty =>
      'No active visit.\nPick a customer and start check-in.';

  @override
  String visitStartedAt(String time) {
    return 'Started at $time';
  }

  @override
  String get visitLiveIndicator => 'Live';

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
  String get createVisitTitle => 'New visit';

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
  String get visitDetailMarkAsDoneSuccess => 'Visit marked as done';

  @override
  String get visitDetailSendToEmployee => 'Send to employee';

  @override
  String get visitDetailSentToEmployeeSuccess => 'Visit sent to employee';

  @override
  String get visitDetailEditState => 'Change state';

  @override
  String get visitDetailPickState => 'Pick state';

  @override
  String get createVisitSubmit => 'Create visit';

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
  String get statsActive => 'Active';

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
  String get filterTimingEarly => 'Earlier';

  @override
  String get filterTimingOverdue => 'Past due';

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
  String get visitDetailStateBadgeSubmitted => 'In progress';

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
  String get nearbyAdjustRadius => 'Adjust radius';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleUser => 'Field employee';

  @override
  String get visitsHistoryActiveBadge => 'Active now';

  @override
  String get visitsHistoryCompletedBadge => 'Completed';

  @override
  String get visitsHistoryIncompleteBadge => 'Incomplete';

  @override
  String get visitsHistoryOverdueBadge => 'Past due';

  @override
  String get visitDetailOverdueHint =>
      'The scheduled day has passed and the visit hasn\'t been completed yet. Reschedule or follow up.';

  @override
  String get visitExecutedOnTime => 'Completed on schedule';

  @override
  String visitExecutedEarly(int days) {
    return 'Completed $days day(s) earlier than scheduled';
  }

  @override
  String visitExecutedLate(int days) {
    return 'Completed $days day(s) later than scheduled';
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
  String get visitShowLocation => 'Show customer location';

  @override
  String get visitDetailCustomerLocationSection => 'Customer location';

  @override
  String get visitDetailNavigate => 'Show customer location on map';

  @override
  String get visitDetailNoCustomerLocation => 'Customer location not available';

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
  String get visitLocationNotAvailable => 'Customer location not available';

  @override
  String get offlineNoQueue =>
      'You\'re offline — actions will be saved locally';

  @override
  String offlineWithQueue(int count) {
    return 'Offline — $count action(s) waiting to sync';
  }

  @override
  String offlineSyncing(int count) {
    return 'Syncing $count pending action(s)…';
  }

  @override
  String get offlineCheckInQueued =>
      'Saved locally — will sync when you\'re back online';

  @override
  String get dashboardTabTitle => 'Dashboard';

  @override
  String get dashboardKpiOverdue => 'Past due';

  @override
  String get dashboardKpiPending => 'Pending review';

  @override
  String get dashboardKpiToday => 'Today';

  @override
  String get dashboardKpiActive => 'Active now';

  @override
  String get dashboardActiveOnMapTitle => 'Live employees';

  @override
  String get dashboardActiveEmpty => 'No employees checked in right now';

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
  String get homeTabActive => 'Active';

  @override
  String get homeTabHistory => 'History';

  @override
  String get homeLocationSharingOn => 'Location sharing is on';

  @override
  String get homeLocationSharingOff => 'Location sharing is off';

  @override
  String get nearbyTitle => 'Nearby employees';

  @override
  String nearbyRadiusLabel(String radius) {
    return 'Radius: $radius meters';
  }

  @override
  String get nearbyEmpty => 'No employees within range';

  @override
  String nearbyLastUpdate(String time) {
    return 'Last update: $time';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get confirmLogoutTitle => 'Sign out';

  @override
  String get confirmLogoutMessage => 'Are you sure you want to sign out?';

  @override
  String get confirmExitTitle => 'Exit app';

  @override
  String get confirmExitMessage => 'Are you sure you want to exit the app?';
}
