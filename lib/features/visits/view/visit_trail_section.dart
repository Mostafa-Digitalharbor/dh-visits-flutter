import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/app_typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/app_number.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/visit_trail_cubit.dart';
import '../data/models/visit.dart';
import 'visit_detail_row.dart';
import 'visit_labels.dart';
import 'visit_section.dart';

/// The numbers behind the thread drawn on the map: how many positions were
/// logged, how far the employee travelled through them, and when the last fix
/// landed.
///
/// Hidden entirely for a visit that was never started — there is nothing to
/// report yet and an empty "0 km" card would just be noise on the page. Once a
/// visit *is* running it stays visible even with no points, because "recording,
/// nothing yet" is itself the answer to "is tracking working?".
class VisitTrailSection extends StatelessWidget {
  final Visit visit;

  /// Opens the full-screen route.
  final VoidCallback? onOpenTrail;

  const VisitTrailSection({super.key, required this.visit, this.onOpenTrail});

  @override
  Widget build(BuildContext context) {
    if (visit.startDatetime == null) return const SizedBox.shrink();

    return BlocBuilder<VisitTrailCubit, VisitTrailState>(
      builder: (context, state) {
        final s = context.s;
        final track = state.track;
        final running = visit.isTrackingLive;

        if (track.isEmpty && state.status == VisitTrailStatus.loading) {
          // Say nothing rather than flash "0 points" and then correct itself
          // a moment later.
          return const SizedBox.shrink();
        }

        final failed = track.isEmpty && state.status == VisitTrailStatus.error;
        final span = track.span;
        final speed = track.averageSpeedKmh;
        final lastFix = track.lastFixAt;
        final rows = <Widget>[
          if (failed)
            // The map card still shows the check-in/out pins; this row says
            // why the route is missing and offers the way back.
            VisitDetailRow(
              icon: Symbols.error,
              iconColor: context.colors.error,
              label: s.trailMapTitle,
              value: state.error?.localize(context) ?? s.errUnknown,
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: s.commonRetry,
                onPressed: () => context.read<VisitTrailCubit>().load(),
              ),
            )
          else ...[
            VisitDetailRow(
              icon: Symbols.linked_services,
              label: s.trailMapTitle,
              value: s.trailPoints(track.locationLogCount),
              iconColor: running ? context.visitSuccess : null,
              trailing: running
                  ? _RecordingChip(pending: state.pendingUploads)
                  : null,
            ),
            if (track.trackedDistanceKm > 0)
              VisitDetailRow(
                icon: Symbols.straighten,
                label: s.trailDistance,
                value: AppNumber.km(s, track.trackedDistanceKm, precise: true),
              ),
            if (speed != null)
              VisitDetailRow(
                icon: Symbols.speed,
                label: s.trailAvgSpeed,
                value: AppNumber.speedKmh(s, speed),
              ),
            if (span != null)
              VisitDetailRow(
                icon: Symbols.timer,
                label: s.wfDurationLabel,
                value: span.localized(context),
              ),
            if (lastFix != null)
              VisitDetailRow(
                icon: Symbols.my_location,
                label: s.trailLastFix,
                value: AppDate.dateTimeFormat(
                  context,
                ).format(context.toUserTime(lastFix)),
              ),
            if (track.isEmpty)
              VisitDetailRow(
                icon: Symbols.info,
                label: s.trailMapTitle,
                value: running ? s.trailEmptyRunning : s.trailEmptyFinished,
              ),
            if (track.hasPath && onOpenTrail != null)
              VisitDetailRow(
                icon: Symbols.timeline,
                label: s.trailSectionTitle,
                value: s.trailOpenFull,
                onTap: onOpenTrail,
              ),
          ],
        ];

        return VisitSection(
          icon: Symbols.route,
          title: s.trailSectionTitle,
          rows: rows,
        );
      },
    );
  }
}

/// Pushes the device's buffered fixes now and says how it went.
///
/// The flush never throws — offline it simply sends nothing — so the answer
/// is read off what is still waiting afterwards.
Future<void> uploadPendingTrail(BuildContext context) async {
  final s = context.s;
  final left = await context.read<VisitTrailCubit>().flushAndReload();
  if (!context.mounted) return;
  if (left == 0) {
    context.showSnack(s.trailUploadDone, kind: SnackKind.success);
  } else {
    context.showSnack(s.trailUploadStillPending(left), kind: SnackKind.error);
  }
}

/// "Recording" — plus, when fixes are stuck on the device, how many are waiting
/// and a tap to push them.
///
/// The pending count is the honest half of this: a rep who has been in a dead
/// zone should see that their path is captured but not yet uploaded, rather
/// than assume the gap in the line means the tracking failed.
class _RecordingChip extends StatelessWidget {
  final int pending;
  const _RecordingChip({required this.pending});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final waiting = pending > 0;
    final pill = TonePill(
      label: waiting ? AppNumber.whole(pending) : s.trailLive,
      color: waiting ? context.colors.tertiary : context.visitSuccess,
      icon: waiting ? Symbols.cloud_upload : Symbols.fiber_manual_record,
      iconSize: IconSz.inline,
      fontSize: FontSz.xs,
      tintAlpha: Alphas.tint,
    );
    if (!waiting) return pill;
    return Tooltip(
      message: s.trailPendingUploads(pending),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: () => uploadPendingTrail(context),
        child: pill,
      ),
    );
  }
}
