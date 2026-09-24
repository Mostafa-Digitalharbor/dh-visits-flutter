import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/location/location_describe.dart';
import '../../../core/location/location_outcome.dart';
import '../../../core/location/location_service.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_tool_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/visit_detail_cubit.dart';
import '../data/attachment_upload.dart';
import '../data/models/visit.dart';
import '../data/models/visit_attachment.dart';
import '../data/visit_tracking_consent.dart';
import '../visit_constants.dart';
import 'action_sheets.dart';
import 'visit_tracking_disclosure_dialog.dart';

/// The buttons the bar can show. Photo and file are separate here (both end
/// in one attachment upload) because each spins on its own while it prepares.
enum _BarAction {
  submit,
  approve,
  reject,
  start,
  end,
  reschedule,
  photo,
  file,
  cancel,
}

/// The sticky bar of workflow actions at the bottom of the visit detail
/// screen. Which buttons appear is derived from the viewer's role plus the
/// visit's state.
class VisitActionBar extends StatefulWidget {
  final Visit visit;
  const VisitActionBar({super.key, required this.visit});

  @override
  State<VisitActionBar> createState() => _VisitActionBarState();
}

class _VisitActionBarState extends State<VisitActionBar> {
  /// The action being prepared on the device — a GPS fix, a reverse geocode,
  /// a sheet, a file read — before the cubit takes over and the page's busy
  /// overlay appears. Every button is disabled meanwhile and this one spins:
  /// a fix can take ten seconds, and taps during it used to start parallel GPS
  /// requests and a second End.
  _BarAction? _preparing;

  /// How a wide bar shares its row between the decision and the tools.
  static const int _primaryFlex = 3;
  static const int _toolFlex = 2;

  Visit get _visit => widget.visit;
  VisitDetailCubit get _cubit => context.read<VisitDetailCubit>();

  /// Runs [run] as [action] unless another action is already being prepared.
  Future<void> _guard(_BarAction action, Future<void> Function() run) async {
    if (_preparing != null) return;
    setState(() => _preparing = action);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _preparing = null);
    }
  }

  void _showError(String message) =>
      context.showSnack(message, kind: SnackKind.error);

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  /// Acquires a position for a Start/End action, applying the mock-location
  /// policy. Every failure mode is returned distinctly — see [LocationOutcome]
  /// for why collapsing them into `null` was unsafe.
  Future<LocationOutcome> _location() async {
    final outcome = await sl<LocationService>().acquire();
    if (outcome is! LocationOk) return outcome;

    // Anti-spoofing: the OS flags positions coming from a mock provider. We
    // "allow with a flag" (per the SFA best-practice review) — warn, record it
    // for review, and let the user decide, rather than hard-blocking.
    if (outcome.isMocked) {
      unawaited(
        Sentry.captureMessage(
          'Mock GPS location used on visit ${_visit.id}',
          level: SentryLevel.warning,
        ),
      );
      if (!mounted) return const LocationCancelled();
      final s = context.s;
      final proceed = await ConfirmDialog.show(
        context,
        title: s.wfMockLocationTitle,
        message: s.wfMockLocationMessage,
        confirmLabel: s.commonContinue,
        cancelLabel: s.commonCancel,
        icon: Icons.gpp_maybe_outlined,
      );
      // Cancel aborts the action outright. It used to fall through to "start
      // with no coordinates", which handed a spoofer a better result than
      // confirming — no GPS on the record at all.
      if (!proceed) return const LocationCancelled();
    }
    return outcome;
  }

  /// Runs [action] with a confirmed position, or tells the user why it can't.
  /// A visit is never started or ended without location evidence.
  ///
  /// [action] receives the whole [LocationOk]. It used to receive two bare
  /// doubles, which silently dropped `isMocked` at this boundary — the spoofing
  /// verdict was computed, shown to the user, and then thrown away before it
  /// could reach the server, making the app's own "this will be flagged for
  /// review" message untrue.
  Future<void> _withLocation(
    Future<void> Function(LocationOk fix, String label) action,
  ) async {
    final language = Localizations.localeOf(context).languageCode;
    final outcome = await _location();
    if (!mounted) return;
    switch (outcome) {
      case LocationOk fix:
        // Reverse-geocode into the text stored as start_location/end_location.
        // Best-effort and never null — see LocationDescriber on why a failure
        // degrades to coordinates rather than blocking the check-in.
        final label = await sl<LocationDescriber>().describe(
          fix.latitude,
          fix.longitude,
          localeIdentifier: language,
        );
        await action(fix, label);
      case LocationCancelled():
        break; // The user closed the warning — that was their answer.
      case LocationPermissionDenied():
        _showError(context.s.errLocationNeededForVisit);
      case LocationUnavailable():
        _showError(context.s.errLocationUnavailable);
    }
  }

  // The cubit is read up front in both: the fix and the geocode are awaited
  // before the action runs, and the page may be gone by then.

  /// Starting a visit starts recording its route, so the disclosure comes
  /// first — before the location prompt — and declining it leaves the visit
  /// unstarted.
  Future<void> _start() async {
    final cubit = _cubit;
    final consent = VisitTrackingConsent(slMaybe<SharedPreferences>());
    final agreed =
        await VisitTrackingDisclosureDialog.ensureAccepted(context, consent);
    if (!mounted) return;
    if (!agreed) {
      _showError(context.s.visitTrackingRequired);
      return;
    }
    return _withLocation(
      (fix, label) => cubit.start(
        latitude: fix.latitude,
        longitude: fix.longitude,
        location: label,
        isMocked: fix.isMocked,
      ),
    );
  }

  Future<void> _end() async {
    final cubit = _cubit;
    final outcome = await showEndVisitSheet(context, initial: _visit.outcome);
    if (outcome == null || !mounted) return;
    await _withLocation(
      (fix, label) => cubit.end(
        outcome: outcome,
        latitude: fix.latitude,
        longitude: fix.longitude,
        location: label,
        isMocked: fix.isMocked,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sheets and dialogs
  // ---------------------------------------------------------------------------

  Future<void> _reject() async {
    final reason = await showRejectReasonSheet(context);
    if (reason == null || !mounted) return;
    await _cubit.reject(reason);
  }

  Future<void> _reschedule() async {
    final r = await showRescheduleSheet(
      context,
      initialSchedule: _visit.scheduledDatetime,
      initialPurpose: _visit.purpose,
      initialLocation: _visit.location,
    );
    if (r == null || !mounted) return;
    await _cubit.reschedule(
      scheduledDatetime: r.scheduled,
      purpose: r.purpose,
      location: r.location,
    );
  }

  Future<void> _cancel() async {
    final s = context.s;
    final ok = await ConfirmDialog.show(
      context,
      title: s.wfConfirmCancelTitle,
      message: s.wfConfirmCancelMessage,
      icon: Icons.block,
    );
    if (!ok || !mounted) return;
    await _cubit.cancel();
  }

  // ---------------------------------------------------------------------------
  // Attachments
  // ---------------------------------------------------------------------------

  /// Capture a proof-of-visit photo straight from the camera and upload it as
  /// an attachment. Downscaled + compressed so the base64 payload stays small.
  Future<void> _takePhoto() async {
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: VisitConstants.photoQuality,
        maxWidth: VisitConstants.photoMaxWidth,
      );
    } on PlatformException catch (e) {
      await _pickerFailed(e, camera: true);
      return;
    }
    // Null: the user closed the camera, which is the whole answer.
    if (shot == null || !mounted) return;
    await _upload(shot.name, shot.path);
  }

  Future<void> _attachFile() async {
    final PlatformFile? file;
    try {
      file = (await FilePicker.pickFiles())?.files.firstOrNull;
    } on PlatformException catch (e) {
      await _pickerFailed(e, camera: false);
      return;
    }
    // Null: the user closed the picker without choosing.
    if (file == null || !mounted) return;
    final path = file.path;
    if (path == null) {
      _showError(context.s.wfAttachmentUnreadable);
      return;
    }
    await _upload(file.name, path);
  }

  Future<void> _upload(String filename, String path) async {
    final prepared = await prepareAttachment(filename, path);
    if (!mounted) return;
    final s = context.s;
    switch (prepared) {
      case AttachmentReady(:final filename, :final dataB64):
        await _cubit.uploadAttachment(filename: filename, dataB64: dataB64);
      case AttachmentTooLarge(:final bytes):
        _showError(
          s.wfAttachmentTooLarge(
            VisitAttachment.formatBytes(s, bytes),
            VisitAttachment.formatBytes(s, VisitConstants.maxAttachmentBytes),
          ),
        );
      case AttachmentUnreadable():
        _showError(s.wfAttachmentUnreadable);
    }
  }

  /// A picker that could not open. A permission refusal gets a dialog that
  /// leads to the app's settings, since that is the only place it can be
  /// undone once the system stops asking; anything else gets a retry hint.
  Future<void> _pickerFailed(
    PlatformException e, {
    required bool camera,
  }) async {
    if (!mounted) return;
    final s = context.s;
    if (!_isAccessDenied(e)) {
      _showError(camera ? s.wfCameraUnavailable : s.wfFilePickerUnavailable);
      return;
    }
    final open = await ConfirmDialog.show(
      context,
      title: camera ? s.wfCameraAccessTitle : s.wfFilesAccessTitle,
      message: camera ? s.wfCameraAccessMessage : s.wfFilesAccessMessage,
      confirmLabel: s.wfOpenSettings,
      cancelLabel: s.commonCancel,
      icon: camera ? Icons.no_photography_outlined : Icons.folder_off_outlined,
      tone: DialogTone.neutral,
    );
    if (!open || !mounted) return;
    await context.openExternal(openAppSettings);
  }

  /// `image_picker` reports `camera_access_denied` / `photo_access_denied`;
  /// `file_picker` reports `read_external_storage_denied` where it asks.
  static bool _isAccessDenied(PlatformException e) =>
      e.code.endsWith('_denied') || e.code.contains('permission');

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  Widget _button(
    _BarAction action, {
    required String label,
    IconData? icon,
    required Future<void> Function() run,
    AppButtonVariant variant = AppButtonVariant.primary,
  }) {
    final onPressed = _preparing == null
        ? () => unawaited(_guard(action, run))
        : null;
    final loading = _preparing == action;
    return switch (variant) {
      AppButtonVariant.primary => AppButton(
        label: label,
        icon: icon,
        loading: loading,
        onPressed: onPressed,
      ),
      AppButtonVariant.secondary => AppButton.secondary(
        label: label,
        icon: icon,
        loading: loading,
        onPressed: onPressed,
      ),
      AppButtonVariant.destructive => AppButton.destructive(
        label: label,
        icon: icon,
        loading: loading,
        onPressed: onPressed,
      ),
    };
  }

  /// A secondary action, drawn as a compact tool.
  Widget _tool(
    _BarAction action, {
    required String label,
    required IconData icon,
    required Future<void> Function() run,
    bool destructive = false,
  }) =>
      AppToolButton(
        label: label,
        icon: icon,
        destructive: destructive,
        loading: _preparing == action,
        onPressed: _preparing == null
            ? () => unawaited(_guard(action, run))
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final visit = _visit;
    final me = context.read<AuthBloc>().state.user;
    final isOwner =
        me?.employeeId != null && me!.employeeId == visit.employeeId;
    final isApprover = me?.canApproveVisits ?? false;
    final canDecide = isApprover && !isOwner && visit.isAwaitingApproval;
    // The server refuses Approve while an attendee is pending; Reject stays.
    final waitsForAttendees = canDecide && visit.attendeesPending;
    // Attachments go into the summary posted when the visit ends, so they are
    // taken until then — not on a finished, cancelled or rejected visit.
    final canHandleFiles = (isOwner || isApprover) &&
        !visit.isDone &&
        !visit.isCancelled &&
        !visit.isRejected;

    // The screen's decision — submit, approve or reject, start, end — keeps
    // full-width buttons. Everything else is a compact tool in one row: as
    // stacked buttons they took half the screen (measured on a 2400×1080
    // emulator), leaving the visit a sliver above them.
    final attendeesNote = waitsForAttendees
        ? Text(
            s.wfApproveWaitsForAttendees,
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          )
        : null;
    final primaries = <Widget>[
      if (isOwner && visit.canSubmit)
        _button(
          _BarAction.submit,
          label: s.wfActionSubmit,
          icon: Icons.send_outlined,
          run: _cubit.submit,
        ),
      if (canDecide && !waitsForAttendees)
        _button(
          _BarAction.approve,
          label: s.wfActionApprove,
          icon: Icons.check_circle_outline,
          run: _cubit.approve,
        ),
      if (canDecide)
        _button(
          _BarAction.reject,
          label: s.wfActionReject,
          run: _reject,
          variant: AppButtonVariant.destructive,
        ),
      if (isOwner && visit.canStart)
        _button(
          _BarAction.start,
          label: s.wfActionStart,
          icon: Icons.play_arrow_rounded,
          run: _start,
        ),
      if (isOwner && visit.canEnd)
        _button(
          _BarAction.end,
          label: s.wfActionEnd,
          icon: Icons.stop_circle_outlined,
          run: _end,
        ),
    ];
    final tools = <Widget>[
      if (isOwner && (visit.isApproved || visit.isAwaitingApproval))
        _tool(
          _BarAction.reschedule,
          label: s.wfActionReschedule,
          icon: Icons.event_repeat,
          run: _reschedule,
        ),
      if (canHandleFiles) ...[
        _tool(
          _BarAction.photo,
          label: s.wfActionTakePhoto,
          icon: Icons.photo_camera_outlined,
          run: _takePhoto,
        ),
        _tool(
          _BarAction.file,
          label: visit.attachmentCount > 0
              ? s.wfActionAddAttachmentCount(visit.attachmentCount)
              : s.wfActionAddAttachment,
          icon: Icons.attach_file,
          run: _attachFile,
        ),
      ],
      if ((isOwner || isApprover) && visit.canCancel)
        _tool(
          _BarAction.cancel,
          label: s.wfActionCancel,
          icon: Icons.block,
          run: _cancel,
          destructive: true,
        ),
    ];

    if (primaries.isEmpty && tools.isEmpty && attendeesNote == null) {
      return const SizedBox.shrink();
    }

    final gap = context.r(Insets.x2);
    final primaryRow = primaries.isEmpty
        ? null
        : Row(
            children: [
              for (var i = 0; i < primaries.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: primaries[i]),
              ],
            ],
          );
    final toolRow = tools.isEmpty
        ? null
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final t in tools) Expanded(child: t)],
          );
    // Side by side where the screen is wide, so the bar stays one row tall on
    // a phone held sideways.
    final wide = context.isLandscape || context.isTablet;
    final Widget actions = wide && primaryRow != null && toolRow != null
        ? Row(
            children: [
              Expanded(flex: _primaryFlex, child: primaryRow),
              SizedBox(width: gap * 2),
              Expanded(flex: _toolFlex, child: toolRow),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (primaryRow != null) primaryRow,
              if (primaryRow != null && toolRow != null) SizedBox(height: gap),
              if (toolRow != null) toolRow,
            ],
          );

    // This bar is mounted in a `Positioned` at the bottom of a Stack, which
    // caps its height with no escape — in landscape at a large text scale the
    // actions exceed it and the ones the screen exists for get clipped away.
    // Cap it against the viewport and let it scroll. The cap covers the whole
    // bar: on the scroll area alone, the padding and border took the bar past
    // its share (53% of a 320×568 phone).
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: context.hp(VisitConstants.actionBarMaxHeightFraction),
      ),
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          context.r(Insets.x4),
          context.r(Insets.x2h),
          context.r(Insets.x4),
          context.r(Insets.x2),
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (attendeesNote != null) ...[
                  attendeesNote,
                  SizedBox(height: gap),
                ],
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
