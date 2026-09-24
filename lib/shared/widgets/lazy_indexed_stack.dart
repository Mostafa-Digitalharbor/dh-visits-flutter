import 'package:flutter/widgets.dart';

/// An [IndexedStack] that builds a child only once its tab has been opened,
/// then keeps it alive like the real thing.
///
/// A plain `IndexedStack` builds **every** child on the first frame, offscreen
/// ones included. For the manager shell that meant the Dashboard (which hosts a
/// `FlutterMap` — tile layer, marker layer, camera) and the Analytics screen
/// both mounting and running their first layout during the login → home
/// transition, on top of the visits list that is actually visible. On a
/// low-end device that is the single longest frame the app produces.
///
/// Keeping the children alive after first build is the point of using a stack
/// here at all: scroll offsets, map cameras and text fields must survive a tab
/// switch, so this is deliberately *not* a plain conditional build.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final AlignmentGeometry alignment;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  /// Which slots have ever been selected. Grows only.
  late List<bool> _mounted;

  @override
  void initState() {
    super.initState();
    _mounted = List<bool>.filled(widget.children.length, false);
    _markVisited();
  }

  @override
  void didUpdateWidget(LazyIndexedStack old) {
    super.didUpdateWidget(old);
    if (widget.children.length != _mounted.length) {
      final next = List<bool>.filled(widget.children.length, false);
      for (var i = 0; i < next.length && i < _mounted.length; i++) {
        next[i] = _mounted[i];
      }
      _mounted = next;
    }
    _markVisited();
  }

  void _markVisited() {
    final i = widget.index;
    if (i >= 0 && i < _mounted.length) _mounted[i] = true;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      alignment: widget.alignment,
      // A zero-size box holds the slot so `index` keeps lining up with
      // `children`; it costs nothing until the tab is first opened.
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _mounted[i]
              // A hidden tab keeps its state but not its clock: pulses,
              // shimmers and count-ups pause until it is shown again,
              // instead of drawing offscreen frames on a field phone's
              // battery all day.
              ? TickerMode(enabled: i == widget.index, child: widget.children[i])
              : const SizedBox.shrink(),
      ],
    );
  }
}
