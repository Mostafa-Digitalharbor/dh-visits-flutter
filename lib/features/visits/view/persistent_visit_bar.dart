import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/network/server_clock.dart';
import '../../../core/utils/duration_format.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_pulse.dart';
import '../bloc/visit_bloc.dart';
// `show Visit`: the model declares its own `VisitState` enum, which would
// collide with the bloc's state class of the same name.
import '../data/models/visit.dart' show Visit;
import '../data/visit_tracking_consent.dart';
import '../data/visit_trail_tracker.dart';
import '../domain/visit_action.dart';
import 'visit_labels.dart';
import 'visit_tracking_disclosure_dialog.dart';

/// Slim banner that lives just above the bottom navigation while a visit is
/// active. Shows the running timer and the customer name; tapping it
/// switches to the Active tab.
///
/// Auto-hides (animates out) when there is no active visit.
class PersistentVisitBar extends StatelessWidget {
  /// Called when the user taps the body of the bar to jump to the active
  /// visit tab.
  final VoidCallback onTap;

  const PersistentVisitBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitBloc, VisitState>(
      // The start time is compared too: an offline Start shows a device-side
      // estimate that the server's own stamp later replaces.
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.activeVisit?.id != curr.activeVisit?.id ||
          prev.activeVisit?.startDatetime != curr.activeVisit?.startDatetime,
      builder: (context, state) {
        final visit = state.activeVisit;
        final showing =
            state.status == VisitStatus.running &&
            visit != null &&
            visit.startDatetime != null;
        return AnimatedSwitcher(
          duration: AppDurations.base,
          switchInCurve: AppCurves.decelerate,
          switchOutCurve: AppCurves.standard,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: showing
              ? _BarContent(key: ValueKey(visit.id), visit: visit, onTap: onTap)
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// The bar body. Static except for the two things that genuinely move — the
/// live dot and the elapsed-time text — each isolated in its own widget so a
/// tick repaints only itself.
class _BarContent extends StatelessWidget {
  final Visit visit;
  final VoidCallback onTap;

  const _BarContent({super.key, required this.visit, required this.onTap});

  /// Lifts the bar off the page it floats over.
  static const double _elevation = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.visitSuccess;
    return Material(
      color: colors.surface,
      elevation: _elevation,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: context.padSym(h: Insets.x3, v: Insets.x2),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.outlineVariant),
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                _LiveDot(color: accent),
                context.gapW(Insets.x2h),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ElapsedText(
                        since: visit.checkInTime,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (visit.customerName != null)
                        Text(
                          visit.customerName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      _TrailStatusLine(visitId: visit.id),
                    ],
                  ),
                ),
                Icon(
                  context.isRtl ? Icons.chevron_left : Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the running visit's route is actually being recorded — and, when
/// it is paused, the one tap that resumes it.
class _TrailStatusLine extends StatelessWidget {
  final int visitId;
  const _TrailStatusLine({required this.visitId});

  @override
  Widget build(BuildContext context) {
    final tracker = slMaybe<VisitTrailTracker>();
    if (tracker == null) return const SizedBox.shrink();
    return ValueListenableBuilder<TrailCaptureStatus>(
      valueListenable: tracker.status,
      builder: (context, status, _) {
        final s = context.s;
        final String text;
        final TrailPause? fix;
        if (status.visitId != visitId) {
          // Shown as running, not recorded: normally a Start still waiting in
          // the offline queue. Anything else is a transition — say nothing.
          if (!_startQueued()) return const SizedBox.shrink();
          text = s.trailStatusWaitingSync;
          fix = null;
        } else {
          fix = status.paused;
          text = switch (fix) {
            null => s.trailStatusRecording,
            TrailPause.consent => s.trailStatusNoConsent,
            TrailPause.permission => s.trailStatusNoPermission,
            TrailPause.unavailable => s.trailStatusUnavailable,
          };
        }
        final color =
            fix == null ? context.colors.onSurfaceVariant : context.visitWarning;
        return Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: color),
              ),
            ),
            if (fix != null)
              TextButton(
                onPressed: () => _resume(context, tracker, fix!),
                child: Text(s.trailStatusResume),
              ),
          ],
        );
      },
    );
  }

  bool _startQueued() {
    try {
      return slMaybe<PendingActionsQueue>()?.pending.any(
                (a) => a.visitId == visitId && a.action == VisitAction.start,
              ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _resume(
    BuildContext context,
    VisitTrailTracker tracker,
    TrailPause pause,
  ) async {
    switch (pause) {
      case TrailPause.consent:
        final agreed = await VisitTrackingDisclosureDialog.ensureAccepted(
          context,
          VisitTrackingConsent(slMaybe<SharedPreferences>()),
        );
        if (!agreed) return;
      case TrailPause.permission:
        final location = slMaybe<LocationService>();
        if (location == null) return;
        final access = await location.requestAccess();
        // No prompt left to show: the fix is in Settings. The tracker checks
        // again when the app comes back to the foreground.
        if (access == LocationAccess.deniedForever) {
          await location.openAppSettings();
          return;
        }
        if (access == LocationAccess.serviceDisabled) {
          await location.openLocationSettings();
          return;
        }
      case TrailPause.unavailable:
        break;
    }
    await tracker.retry();
  }
}

/// The "recording" indicator: a solid dot with a halo that beats outward.
///
/// Two problems were fixed here, both of which only bite because this widget is
/// on screen for the entire duration of a visit — hours, for a field rep.
///
/// 1. The halo was a `BoxShadow` with an *animated* `blurRadius`/`spreadRadius`.
///    A blur cannot be raster-cached, so every frame re-ran the filter. It is
///    now a plain circle behind the dot, faded and scaled — a transform and an
///    opacity, which the GPU does for free.
/// 2. The controller ran `repeat()`, which holds the vsync loop open forever.
///    Measured: the app produced ~41 frames/second with no user input while a
///    visit was active, and zero when it wasn't. [AmbientPulse] gives the beat
///    a rest gap so the device goes fully idle in between; the halo fades to
///    nothing as the beat ends, so the resting state is the finished state.
class _LiveDot extends StatelessWidget {
  final Color color;
  const _LiveDot({required this.color});

  /// The solid dot, and the halo that expands out of it. The halo's box is the
  /// widget's own footprint, so the ring never gets clipped at full scale.
  static const double _core = 10.0;
  static const double _halo = 22.0;

  /// The halo fades from this opacity to nothing, and grows from half size
  /// to the full footprint, over one beat.
  static const double _haloStartAlpha = 0.35;
  static const double _haloStartScale = 0.5;

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    final halo = context.r(_halo);
    final core = context.r(_core);
    return SizedBox(
      width: halo,
      height: halo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AmbientPulse(
            builder: (_, beat) => FadeTransition(
              opacity: Tween<double>(
                begin: _haloStartAlpha,
                end: 0.0,
              ).animate(beat),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: _haloStartScale,
                  end: 1.0,
                ).animate(beat),
                child: SizedBox(width: halo, height: halo, child: dot),
              ),
            ),
          ),
          SizedBox(width: core, height: core, child: dot),
        ],
      ),
    );
  }
}

/// Ticks the running visit duration once a second.
///
/// Its own widget so the `setState` repaints one `Text` instead of the whole
/// bar — which previously meant re-running the `Material` elevation shadow, the
/// `SafeArea`, the `InkWell` and the pulse subtree 60 times a minute, forever.
class _ElapsedText extends StatefulWidget {
  final DateTime? since;
  final TextStyle? style;
  const _ElapsedText({required this.since, this.style});

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  static const _tick = Duration(seconds: 1);

  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recompute();
    _ticker = Timer.periodic(_tick, (_) {
      if (mounted) setState(_recompute);
    });
  }

  @override
  void didUpdateWidget(_ElapsedText old) {
    super.didUpdateWidget(old);
    if (old.since != widget.since) setState(_recompute);
  }

  /// Measured on the server's clock, which stamped [_ElapsedText.since]. On
  /// the device's own clock a phone running a few minutes slow showed a
  /// negative duration — which the clock format then printed as a small
  /// positive one.
  void _recompute() {
    final start = widget.since;
    if (start == null) {
      _elapsed = Duration.zero;
      return;
    }
    final now = slMaybe<ServerClock>()?.now() ?? DateTime.now();
    final elapsed = now.difference(start);
    _elapsed = elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(_elapsed.clockWithSeconds, style: widget.style);
}
