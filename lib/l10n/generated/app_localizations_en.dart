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
  String unitKm(String value) {
    return '$value km';
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
  String get serverSetupDetectDb => 'Detect database';

  @override
  String get serverSetupDetecting => 'Detecting…';

  @override
  String serverSetupDetected(String db) {
    return 'Database detected: $db';
  }

  @override
  String get serverSetupDetectFailed =>
      'Couldn\'t detect the database — enter it manually';

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
  String get liveLocationUnsupported =>
      'Live location sharing isn\'t available on this server — ask your administrator to enable it.';

  @override
  String get liveLocationPermissionOff =>
      'Location sharing is off, so your manager can\'t see you on the map. Allow location access to turn it back on.';

  @override
  String get liveLocationPingFailed =>
      'Your location isn\'t reaching the server, so your position on the map is out of date.';

  @override
  String get pushChannelName => 'Visit updates';

  @override
  String get pushChannelDescription =>
      'Approvals, reschedules and status changes for your visits.';

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
    return 'Your offline update couldn\'t be saved: $reason Open the visit and record it again.';
  }

  @override
  String get errConflict =>
      'This visit was already updated somewhere else. Pull down to refresh and check its current status before trying again.';

  @override
  String get errInsecureConnection =>
      'Couldn\'t open a secure connection to the server. Its security certificate isn\'t trusted — check the server address with your administrator.';

  @override
  String get errCustomerLoadFailed => 'Failed to load customer';

  @override
  String get errAttachmentOpenFailed =>
      'Couldn\'t open the attachment. Please try again.';

  @override
  String get errAttachmentUnavailable =>
      'This attachment is no longer available — pull down to refresh.';

  @override
  String get errAttachmentsLoadFailed =>
      'Couldn\'t load attachments. Pull down to try again.';

  @override
  String get attachmentsEmpty => 'No attachments yet';

  @override
  String get errCannotLaunchApp =>
      'Couldn\'t open an app for this action on your device.';

  @override
  String get errActionFailed =>
      'The action couldn\'t be completed. Please try again.';

  @override
  String get errFeatureNotAvailable =>
      'This feature isn\'t available on this server';

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
  String get mapLiveTracking => 'Live tracking';

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
  String get createVisitTitle => 'Create a new visit';

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
  String get roleManagerTitle => 'Team manager';

  @override
  String get roleEmployeeTitle => 'Field rep';

  @override
  String get visitsHistoryActiveBadge => 'Active now';

  @override
  String get visitsScheduledLabel => 'Scheduled';

  @override
  String get dashboardGreeting => 'Good morning';

  @override
  String get dashboardTodayProgress => 'Today\'s progress';

  @override
  String get dashboardFieldTime => 'Field time';

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
  String get reviewTitle => 'Review visits';

  @override
  String reviewPendingCount(int n) {
    return '$n awaiting your approval';
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
  String get routeStops => 'stops';

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
  String get reportOutcomeAbsent => 'Client absent';

  @override
  String get reportNotes => 'Notes';

  @override
  String get reportNotesHint => 'Write a summary of the visit and key notes...';

  @override
  String get reportPhoto => 'Proof photo';

  @override
  String get reportAddPhoto => 'Add photo';

  @override
  String get reportSignature => 'Client signature';

  @override
  String get reportSignHere => 'Sign here';

  @override
  String get reportClear => 'Clear';

  @override
  String get reportSubmit => 'Finish and save report';

  @override
  String get createVisitSectionCustomer => 'Customer';

  @override
  String get createVisitSectionEmployee => 'Field employee';

  @override
  String get createVisitSectionType => 'Visit type';

  @override
  String get createVisitSectionDate => 'Visit date';

  @override
  String get createVisitChange => 'Change';

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
  String get statusScheduled => 'Scheduled';

  @override
  String get statusActive => 'Active now';

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
  String get visitDetailOutRangeHint => 'Move closer to start the visit';

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
  String offlinePendingCount(int count) {
    return '$count action(s) still pending — check your connection and try again.';
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
  String get settingsSyncedJustNow => 'Just now';

  @override
  String get settingsHelp => 'Help & support';

  @override
  String get settingsComingSoon => 'Coming soon';

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
  String get wfStateWaitingParticipant => 'Waiting participant approval';

  @override
  String get wfStateWaitingManager => 'Waiting manager approval';

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
  String get wfActionEnd => 'End visit';

  @override
  String get wfActionCancel => 'Cancel visit';

  @override
  String get wfActionAddParticipant => 'Add participant';

  @override
  String get wfActionAddAttachment => 'Add attachment';

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
  String get wfParticipantApproved => 'Participant approved';

  @override
  String get wfParticipantRejected => 'Participant rejected';

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
  String get wfRescheduleTitle => 'Request reschedule';

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
  String get wfOpenInMaps => 'Open in Maps';

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
}
