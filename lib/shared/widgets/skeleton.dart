import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../app/design/app_colors.dart';
import '../../app/design/app_dimens.dart';

/// Wraps any child with shimmer animation, using theme-appropriate colors.
///
/// The [RepaintBoundary] is load-bearing, not decoration: `Shimmer` is a
/// `ShaderMask`, which forces a `saveLayer` over its subtree and re-composites
/// it every frame for as long as the sweep runs. Without a boundary that
/// repaint propagates outward and drags whatever shares the layer — an app bar,
/// a status banner, a nav bar — into the same 60fps loop. Skeletons are shown
/// precisely while the device is also busy parsing a response, which is the
/// worst moment to be spending frame budget on siblings that aren't moving.
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (base, highlight) = AppColors.skeletonShimmer(isDark);
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        period: AppDurations.shimmer,
        child: child,
      ),
    );
  }
}

/// The fill a skeleton shape is drawn with. Its colour never shows — the
/// shimmer's shader replaces it; only its opacity matters.
const Color _shimmerMask = AppColors.onMap;

/// A single skeleton placeholder box with rounded corners.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    this.height = Insets.x4,
    this.radius = Radii.xs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _shimmerMask,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, this.size = CompSz.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _shimmerMask,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pre-built skeleton for a list-tile row. Exactly [SkeletonList.rowHeight]
/// tall, including the hairline divider at its foot.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  static const double _rowPadding = Insets.x3;
  static const double _titleLine = 14;
  static const double _subtitleLine = 12;
  static const double _titleShare = 0.55;
  static const double _subtitleShare = 0.8;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.x4,
            vertical: _rowPadding,
          ),
          child: Row(
            children: [
              SkeletonCircle(size: CompSz.avatar),
              SizedBox(width: Insets.x3h),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shares, not fixed widths: a 220dp bar overflowed the row
                    // on a 320dp screen once the avatar and gutters were in.
                    FractionallySizedBox(
                      widthFactor: _titleShare,
                      child: SkeletonBox(height: _titleLine),
                    ),
                    SizedBox(height: Insets.x2),
                    FractionallySizedBox(
                      widthFactor: _subtitleShare,
                      child: SkeletonBox(height: _subtitleLine),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: CompSz.hairline),
      ],
    );
  }
}

/// A list of skeleton tiles wrapped in shimmer.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  const SkeletonList({super.key, this.itemCount = 8});

  /// Avatar + padding above and below + the divider. Fixed, so the sliver can
  /// place rows arithmetically.
  static const double rowHeight = CompSz.avatar +
      SkeletonListTile._rowPadding * 2 +
      CompSz.hairline;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      // `itemExtent` (and hence `builder` rather than `separated`, which cannot
      // take one): every row is the same known height, so telling the sliver
      // that lets it skip a layout pass per row and compute total extent
      // directly. The divider moved into the tile to keep the extent uniform.
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemExtent: rowHeight,
        itemCount: itemCount,
        itemBuilder: (_, __) => const SkeletonListTile(),
      ),
    );
  }
}

/// Card-shaped skeleton with title + two lines.
///
/// Draws no shimmer of its own — like [SkeletonBox] and [SkeletonCircle], it is
/// a plain shape and the caller wraps a group in a single [AppShimmer]. Cards
/// used to self-wrap, so a screen showing several ran one animation *per card*;
/// they drifted out of phase and the sweep read as flicker rather than one
/// surface loading.
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = _defaultHeight});

  static const double _defaultHeight = 120;
  static const double _titleLine = 16;
  static const double _bodyLine = 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(Insets.cardPad),
      decoration: BoxDecoration(
        color: _shimmerMask,
        // The radius of the cards it stands in for.
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          FractionallySizedBox(
            widthFactor: 0.6,
            child: SkeletonBox(height: _titleLine),
          ),
          FractionallySizedBox(
            widthFactor: 0.9,
            child: SkeletonBox(height: _bodyLine),
          ),
          FractionallySizedBox(
            widthFactor: 0.4,
            child: SkeletonBox(height: _bodyLine),
          ),
        ],
      ),
    );
  }
}
