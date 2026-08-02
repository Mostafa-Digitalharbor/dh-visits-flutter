import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
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
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6E6E6),
        highlightColor:
            isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
        period: const Duration(milliseconds: 1400),
        child: child,
      ),
    );
  }
}

/// A single skeleton placeholder box with rounded corners.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // Shimmer paints over this
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pre-built skeleton for a list-tile row. Exactly [SkeletonList.rowHeight]
/// tall, including the hairline divider at its foot.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: const [
              SkeletonCircle(size: 44),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// A list of skeleton tiles wrapped in shimmer.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  const SkeletonList({super.key, this.itemCount = 8});

  /// 44dp avatar + 12dp padding top and bottom + a 1dp divider. Fixed, so the
  /// sliver can place rows arithmetically.
  static const double rowHeight = 69;

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
  const SkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          SkeletonBox(width: 180, height: 16),
          SkeletonBox(width: 240, height: 12),
          SkeletonBox(width: 120, height: 12),
        ],
      ),
    );
  }
}
