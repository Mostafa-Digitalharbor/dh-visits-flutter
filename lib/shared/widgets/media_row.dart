import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';

/// A leading visual, a stack of text lines that takes the remaining width, and
/// an optional trailing widget.
///
/// Seven screens had written this out by hand — a badge or avatar, a
/// `gapW`, then `Expanded(child: Column(crossAxisAlignment: start, …))` — and
/// the hand-written copies had already drifted to three different gap widths
/// for what reads as the same row.
///
/// Deliberately *only* the geometry. Each caller keeps its own leading widget
/// and its own text styles, because they genuinely differ: a detail row puts a
/// small label above a large value, an attachment row puts a large name above a
/// small caption, and a participant row puts a status underneath in its state's
/// colour. A widget that also fixed the typography would have to be configured
/// back apart at every call site.
///
/// Unlike `ListTile` this imposes no Material height, density or icon theme,
/// which is why those screens hand-rolled the row to begin with.
///
/// Not for a row whose trailing widget has to *compete* for width with the
/// text — a `Flexible` summary that shrinks before the title does. [trailing]
/// is laid out at its own size, so such a row (see `route_sections.dart`)
/// keeps its hand-written `Row` on purpose.
class MediaRow extends StatelessWidget {
  /// Badge, avatar or any other fixed-size visual at the start of the row.
  final Widget leading;

  /// The text lines, top to bottom. Laid out start-aligned in the space left
  /// over, so a long name wraps or ellipsizes inside the row instead of
  /// pushing [trailing] off a narrow screen.
  final List<Widget> lines;

  /// Chevron, size label, action button — anything after the text.
  final Widget? trailing;

  /// Gap between [leading] and the text. Scales with the device.
  final double gap;

  /// Gap between the text and [trailing]. Defaults to [gap].
  final double? trailingGap;

  /// How the row's three parts line up against each other. Centre suits a
  /// single-line row; `start` is right when the text can wrap to two lines and
  /// the badge should stay level with the first one.
  final CrossAxisAlignment alignment;

  const MediaRow({
    super.key,
    required this.leading,
    required this.lines,
    this.trailing,
    this.gap = Insets.x3,
    this.trailingGap,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: alignment,
        children: [
          leading,
          context.gapW(gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: lines,
            ),
          ),
          if (trailing case final t?) ...[
            context.gapW(trailingGap ?? gap),
            t,
          ],
        ],
      );
}
