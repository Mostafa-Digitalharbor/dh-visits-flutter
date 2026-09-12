import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../bloc/visit_trail_cubit.dart';
import '../data/models/visit.dart';
import 'visit_detail_row.dart';
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

        if (track.isEmpty && state.status != VisitTrailStatus.ready) {
          // Still loading (or failed): say nothing rather than flash "0 points"
          // and then correct itself a moment later.
          return const SizedBox.shrink();
        }

        final rows = <Widget>[
          VisitDetailRow(
            icon: Symbols.linked_services,
            label: s.trailMapTitle,
            value: s.trailPoints(track.locationLogCount),
            iconColor: running ? Colors.green.shade600 : null,
            trailing: running
                ? _RecordingChip(pending: state.pendingUploads)
                : null,
          ),
          if (track.trackedDistanceKm > 0)
            VisitDetailRow(
              icon: Symbols.straighten,
              label: s.trailDistance,
              value: s.trailDistanceKm(
                  track.trackedDistanceKm.toStringAsFixed(2)),
            ),
          if (track.averageSpeedKmh != null)
            VisitDetailRow(
              icon: Symbols.speed,
              label: s.trailAvgSpeed,
              value:
                  s.trailSpeedKmh(track.averageSpeedKmh!.toStringAsFixed(0)),
            ),
          if (track.span != null)
            VisitDetailRow(
              icon: Symbols.timer,
              label: s.wfDurationLabel,
              value: track.span!.localized(context),
            ),
          if (track.lastFixAt != null)
            VisitDetailRow(
              icon: Symbols.my_location,
              label: s.trailLastFix,
              value: AppDate.dateTimeFormat(context)
                  .format(context.toUserTime(track.lastFixAt!)),
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
    final cs = context.colors;
    final waiting = pending > 0;
    final tone = waiting ? cs.tertiary : Colors.green.shade600;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.x2, vertical: Insets.x1),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: Alphas.tint),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            waiting ? Symbols.cloud_upload : Symbols.fiber_manual_record,
            size: 14,
            color: tone,
          ),
          context.gapW(Insets.x1),
          Text(
            waiting ? '$pending' : s.trailLive,
            style: context.text.labelSmall
                ?.copyWith(color: tone, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    if (!waiting) return chip;
    return Tooltip(
      message: s.trailPendingUploads(pending),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: () => context.read<VisitTrailCubit>().flushAndReload(),
        child: chip,
      ),
    );
  }
}
