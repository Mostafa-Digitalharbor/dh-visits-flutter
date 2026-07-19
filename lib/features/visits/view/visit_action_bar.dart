import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/location/location_describe.dart';
import '../../../core/location/location_outcome.dart';
import '../../../core/location/location_service.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/visit_detail_cubit.dart';
import '../data/models/visit.dart';
import 'action_sheets.dart';

/// The sticky bar of workflow actions at the bottom of the visit detail
/// screen. Which buttons appear is derived from the viewer's role plus the
/// visit's state.
class VisitActionBar extends StatelessWidget {
  final Visit visit;
  const VisitActionBar({super.key, required this.visit});

  /// Acquires a position for a Start/End action, applying the mock-location
  /// policy. Every failure mode is returned distinctly — see [LocationOutcome]
  /// for why collapsing them into `null` was unsafe.
  Future<LocationOutcome> _location(BuildContext context) async {
    final outcome = await sl<LocationService>().acquire();
    if (outcome is! LocationOk) return outcome;

    // Anti-spoofing: the OS flags positions coming from a mock provider. We
    // "allow with a flag" (per the SFA best-practice review) — warn, record it
    // for review, and let the user decide, rather than hard-blocking.
    if (outcome.isMocked) {
      unawaited(Sentry.captureMessage(
        'Mock GPS location used on visit ${visit.name ?? visit.id}',
        level: SentryLevel.warning,
      ));
      if (!context.mounted) return const LocationCancelled();
      final proceed = await ConfirmDialog.show(
        context,
        title: context.s.wfMockLocationTitle,
        message: context.s.wfMockLocationMessage,
        confirmLabel: context.s.commonContinue,
        cancelLabel: context.s.commonCancel,
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
    BuildContext context,
    Future<void> Function(LocationOk fix, String? label) action,
  ) async {
    final outcome = await _location(context);
    if (!context.mounted) return;
    switch (outcome) {
      case LocationOk fix:
        // Reverse-geocode into the text stored as start_location/end_location.
        // Best-effort and never null — see LocationDescriber on why a failure
        // degrades to coordinates rather than blocking the check-in.
        final label = await sl<LocationDescriber>().describe(
          fix.latitude,
          fix.longitude,
          localeIdentifier: Localizations.localeOf(context).languageCode,
        );
        await action(fix, label);
      case LocationCancelled():
        break; // The user backed out — say nothing, do nothing.
      case LocationPermissionDenied():
        context.showSnack(context.s.errLocationNeededForVisit,
            kind: SnackKind.error);
      case LocationUnavailable():
        context.showSnack(context.s.errLocationUnavailable,
            kind: SnackKind.error);
    }
  }

  Future<void> _pickAndUpload(
      BuildContext context, VisitDetailCubit cubit) async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    await cubit.uploadAttachment(
        filename: f.name, dataB64: base64Encode(bytes));
  }

  /// Capture a proof-of-visit photo straight from the camera and upload it as
  /// an attachment. Downscaled + compressed so the base64 payload stays small.
  Future<void> _captureAndUpload(
      BuildContext context, VisitDetailCubit cubit) async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    await cubit.uploadAttachment(
        filename: shot.name, dataB64: base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthBloc>().state.user;
    final cubit = context.read<VisitDetailCubit>();
    final isOwner =
        me?.employeeId != null && me!.employeeId == visit.employeeId;
    final canApprove =
        (me?.canApproveVisits ?? false) && !isOwner && visit.isAwaitingApproval;

    final buttons = <Widget>[];

    if (isOwner && visit.canSubmit) {
      buttons.add(AppButton(
        label: context.s.wfActionSubmit,
        icon: Icons.send_outlined,
        onPressed: cubit.submit,
      ));
    }
    if (canApprove) {
      buttons.add(AppButton(
        label: context.s.wfActionApprove,
        icon: Icons.check_circle_outline,
        onPressed: cubit.approve,
      ));
      buttons.add(AppButton.destructive(
        label: context.s.wfActionReject,
        onPressed: () async {
          final reason = await showRejectReasonSheet(context);
          if (reason == null || !context.mounted) return;
          cubit.reject(reason);
        },
      ));
    }
    if (isOwner && visit.canStart) {
      buttons.add(AppButton(
        label: context.s.wfActionStart,
        icon: Icons.play_arrow_rounded,
        onPressed: () => _withLocation(
          context,
          (fix, label) => cubit.start(
            latitude: fix.latitude,
            longitude: fix.longitude,
            location: label,
            isMocked: fix.isMocked,
          ),
        ),
      ));
    }
    if (isOwner && visit.canEnd) {
      buttons.add(AppButton(
        label: context.s.wfActionEnd,
        icon: Icons.stop_circle_outlined,
        onPressed: () async {
          final outcome =
              await showEndVisitSheet(context, initial: visit.outcome);
          if (outcome == null || !context.mounted) return;
          await _withLocation(
            context,
            (fix, label) => cubit.end(
              outcome: outcome,
              latitude: fix.latitude,
              longitude: fix.longitude,
              location: label,
              isMocked: fix.isMocked,
            ),
          );
        },
      ));
    }
    if (isOwner && (visit.isApproved || visit.isAwaitingApproval)) {
      buttons.add(AppButton.secondary(
        label: context.s.wfActionReschedule,
        icon: Icons.event_repeat,
        onPressed: () async {
          final r = await showRescheduleSheet(
            context,
            initialSchedule: visit.scheduledDatetime,
            initialPurpose: visit.purpose,
            initialLocation: visit.location,
          );
          if (r == null || !context.mounted) return;
          cubit.reschedule(
            scheduledDatetime: r.scheduled,
            purpose: r.purpose,
            location: r.location,
          );
        },
      ));
    }
    if ((isOwner || (me?.canApproveVisits ?? false)) &&
        !visit.isCancelled &&
        !visit.isRejected) {
      buttons.add(AppButton.secondary(
        label: context.s.wfActionTakePhoto,
        icon: Icons.photo_camera_outlined,
        onPressed: () => _captureAndUpload(context, cubit),
      ));
      buttons.add(AppButton.secondary(
        label: visit.attachmentCount > 0
            ? '${context.s.wfActionAddAttachment} (${visit.attachmentCount})'
            : context.s.wfActionAddAttachment,
        icon: Icons.attach_file,
        onPressed: () => _pickAndUpload(context, cubit),
      ));
    }
    if ((isOwner || (me?.canApproveVisits ?? false)) &&
        !visit.isDone &&
        !visit.isCancelled &&
        !visit.isRejected &&
        visit.state != VisitState.inProgress) {
      buttons.add(AppButton.secondary(
        label: context.s.wfActionCancel,
        icon: Icons.block,
        onPressed: () async {
          final ok = await ConfirmDialog.show(
            context,
            title: context.s.wfConfirmCancelTitle,
            message: context.s.wfConfirmCancelMessage,
            icon: Icons.block,
          );
          if (!ok || !context.mounted) return;
          cubit.cancel();
        },
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        // Up to five actions can be offered at once (Start / Reschedule /
        // Photo / Attachment / Cancel). This bar is mounted in a `Positioned`
        // at the bottom of a Stack, which caps its height with no escape — in
        // landscape at a large text scale the column exceeds it and the
        // workflow buttons the screen exists for get clipped away. Cap it
        // against the viewport and let it scroll instead.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final b in buttons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: b,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
