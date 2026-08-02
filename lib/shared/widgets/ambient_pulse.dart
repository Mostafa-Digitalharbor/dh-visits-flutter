import 'dart:async';

import 'package:flutter/widgets.dart';

/// A decorative pulse that **rests between beats** instead of animating
/// forever.
///
/// ## Why this exists
///
/// Measured on emulator-5554 (profile build, 2026-07-25): with an active visit
/// on screen, the app rendered **~41 frames/second continuously with no user
/// input at all**; with no active visit it rendered **zero**. The entire
/// difference was one `AnimationController..repeat(reverse: true)` driving the
/// live-visit dot. A running controller holds the vsync loop open, so the
/// engine builds, rasterises and composites a whole frame for every beat of a
/// 22dp dot — and it does that for as long as the visit lasts, which for a
/// field rep is the whole working day.
///
/// The cost is not the dot. It is that the device is never allowed to idle:
/// continuous GPU wakeups, continuous compositor work, battery drain and, on a
/// low-end phone, thermal throttling that makes *everything else* slower. That
/// is the exact failure mode this app has to avoid — its primary screen is the
/// one a salesperson leaves open all day.
///
/// ## What it does instead
///
/// Runs the controller for [period], then **stops it** for [rest] before
/// starting again. While stopped there is no ticker, so Flutter produces no
/// frames at all and the device returns to idle. With the defaults the duty
/// cycle is 1.1s on / 1.9s off — a ~63% cut in frames produced, and, more
/// importantly, real idle gaps rather than a permanently hot pipeline.
///
/// The animation must be designed to **rest invisibly at value 1.0**: fade the
/// pulsing element out as the beat completes so the resting state and the
/// finished state look identical. (Do not use `reverse: true` semantics here —
/// the builder is handed a 0 → 1 ramp and rests at 1.)
class AmbientPulse extends StatefulWidget {
  /// Receives a 0 → 1 animation for one beat. It rests at 1 between beats, so
  /// whatever is animated must be invisible (or at its resting appearance) at
  /// the end of the ramp.
  final Widget Function(BuildContext context, Animation<double> beat) builder;

  /// Length of one beat.
  final Duration period;

  /// Silence after each beat. The whole point — frames stop being produced.
  final Duration rest;

  /// Easing applied to the beat before it reaches [builder].
  final Curve curve;

  const AmbientPulse({
    super.key,
    required this.builder,
    this.period = const Duration(milliseconds: 1100),
    this.rest = const Duration(milliseconds: 1900),
    this.curve = Curves.easeOut,
  });

  @override
  State<AmbientPulse> createState() => _AmbientPulseState();
}

class _AmbientPulseState extends State<AmbientPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.period);
  late final Animation<double> _beat =
      CurvedAnimation(parent: _ctrl, curve: widget.curve);
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener(_onStatus);
    _ctrl.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Controller is now stopped. Nothing schedules a frame until the timer
    // fires — this gap is the whole feature.
    _restTimer?.cancel();
    _restTimer = Timer(widget.rest, () {
      if (mounted) _ctrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Contains the repaint to the pulsing element so a beat can't dirty the
    // static chrome around it.
    return RepaintBoundary(child: widget.builder(context, _beat));
  }
}
