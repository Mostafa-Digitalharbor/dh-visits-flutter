import 'package:flutter/material.dart';

/// Centers [child] in the available space, and lets it scroll instead of
/// overflowing when that space is too short.
///
/// Full-screen placeholders (empty / error states, dialog bodies) are built
/// around a fixed-height illustration plus text. Centered in a portrait body
/// they fit with room to spare; in landscape — or with the OS text scale at
/// our 1.25 cap — the same column exceeds the viewport and a plain `Center`
/// has nowhere to put the excess, so `RenderFlex` overflows and (because
/// `Flex.clipBehavior` is `Clip.none`) paints over the chrome beneath it.
///
/// The height constraint decides the strategy:
///  * **bounded** (a Scaffold body, a sized sheet) — scroll past the viewport
///    when needed, and pin to the centre when it fits, via `minHeight`.
///  * **unbounded** (already inside a `ListView`/`CustomScrollView`, e.g. the
///    notifications empty state) — the parent scrolls, so shrink-wrap. Adding
///    a viewport here would throw "Vertical viewport was given unbounded
///    height" instead of fixing anything.
class AdaptiveCenter extends StatelessWidget {
  final Widget child;

  /// Padding applied inside the scrollable, so it scrolls with the content
  /// rather than clipping it.
  final EdgeInsetsGeometry padding;

  const AdaptiveCenter({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(padding: padding, child: child);
        if (!constraints.hasBoundedHeight) {
          return Center(child: content);
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
