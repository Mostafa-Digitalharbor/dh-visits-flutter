import 'dart:async';

import 'package:flutter/material.dart';

/// Wraps a list child in a one-shot fade-in + slide-up animation. Items
/// stagger based on their `index` so longer lists "cascade" instead of
/// popping in at once.
///
/// **Only the first screenful animates.** A `ListView` builds rows lazily and
/// rebuilds them as they recycle, so wrapping every row meant a fresh
/// `AnimationController` + `Timer` allocated (and a 380ms opacity + transform
/// animation started) for each row that scrolled into view — for the whole life
/// of the list, not just its entrance. The effect is an entrance flourish; past
/// the fold there is no entrance to flourish, only scrolling, and on a low-end
/// device that per-row animation is felt as scroll jank. Rows at or beyond
/// [animateBelowIndex] render their child directly, with no `State` at all.
class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;

  /// Per-item stagger delay. With 55ms × index, an 8-row list finishes
  /// animating in well under half a second.
  final Duration step;

  /// Animation length for a single item.
  final Duration duration;

  /// Max delay (clamped) — without this, the 30th item would have to wait
  /// nearly 2 seconds.
  final Duration maxDelay;

  /// Rows from this index on are not animated. Roughly a tall phone's worth of
  /// list-tile-sized rows, so everything visible on first paint still cascades.
  final int animateBelowIndex;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 55),
    this.duration = const Duration(milliseconds: 380),
    this.maxDelay = const Duration(milliseconds: 350),
    this.animateBelowIndex = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (index >= animateBelowIndex) return child;
    return _AnimatedListItem(
      index: index,
      step: step,
      duration: duration,
      maxDelay: maxDelay,
      child: child,
    );
  }
}

class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration step;
  final Duration duration;
  final Duration maxDelay;

  const _AnimatedListItem({
    required this.index,
    required this.child,
    required this.step,
    required this.duration,
    required this.maxDelay,
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * widget.step.inMilliseconds)
        .clamp(0, widget.maxDelay.inMilliseconds);
    _startTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Soft scale-in for one-off elements (empty states, hero icons). Runs
/// once on mount.
class ScaleFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  const ScaleFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.delay = Duration.zero,
  });

  @override
  State<ScaleFadeIn> createState() => _ScaleFadeInState();
}

class _ScaleFadeInState extends State<ScaleFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      _startTimer = Timer(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
