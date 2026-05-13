import 'package:flutter/material.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard>
    with SingleTickerProviderStateMixin {
  // Lazily created on first tap so non-tappable cards (the majority) never
  // allocate a Ticker. Built eagerly via `_ensureCtrl` on first interaction
  // — must NEVER be triggered from dispose(), because constructing an
  // AnimationController during widget teardown does an InheritedWidget
  // lookup (TickerMode) on a deactivated element and crashes.
  AnimationController? _ctrl;

  AnimationController _ensureCtrl() {
    return _ctrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
      value: 1.0,
      lowerBound: 0.96,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _ensureCtrl().reverse();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap == null) return;
    _ensureCtrl().forward();
  }

  void _onTapCancel() {
    if (widget.onTap == null) return;
    _ensureCtrl().forward();
  }

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: widget.color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
    if (widget.onTap == null) return card;
    return ScaleTransition(scale: _ensureCtrl(), child: card);
  }
}
