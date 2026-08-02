import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_pulse.dart';
import '../bloc/visit_bloc.dart';
// `show Visit`: the model declares its own `VisitState` enum, which would
// collide with the bloc's state class of the same name.
import '../data/models/visit.dart' show Visit;
import '../../../core/utils/duration_format.dart';

/// Slim banner that lives just above the bottom navigation while a visit is
/// active. Shows the running timer + customer name + a quick check-out
/// button. Tapping the bar (anywhere outside the action) switches to the
/// Active tab.
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
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.activeVisit?.id != curr.activeVisit?.id,
      builder: (context, state) {
        final visit = state.activeVisit;
        final showing = state.status == VisitStatus.running &&
            visit != null &&
            visit.startDatetime != null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: showing
              ? _BarContent(
                  key: ValueKey(visit.id),
                  visit: visit,
                  onTap: onTap,
                )
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = Colors.green.shade600;
    return Material(
      color: colors.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.outlineVariant),
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                _LiveDot(color: accent),
                const SizedBox(width: 10),
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
                          height: 1.1,
                        ),
                      ),
                      if (visit.customerName != null)
                        Text(
                          visit.customerName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AmbientPulse(
            builder: (_, beat) => FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 0.0).animate(beat),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.5, end: 1.0).animate(beat),
                child: SizedBox(width: 22, height: 22, child: dot),
              ),
            ),
          ),
          SizedBox(width: 10, height: 10, child: dot),
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
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recompute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_recompute);
    });
  }

  @override
  void didUpdateWidget(_ElapsedText old) {
    super.didUpdateWidget(old);
    if (old.since != widget.since) setState(_recompute);
  }

  void _recompute() {
    final start = widget.since;
    _elapsed = start == null ? Duration.zero : DateTime.now().difference(start);
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
