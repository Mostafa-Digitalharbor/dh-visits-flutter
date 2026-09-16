import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/app_number.dart';
import '../extensions/context_extensions.dart';
import 'initial_avatar.dart';
import 'progress_track.dart';

/// Where a row's figure sits.
///
/// The app ships both placements and they are not interchangeable: the
/// dashboard's boards rank by a raw count, so the number is the row's outcome
/// and belongs at its end; the analytics board's figure is a rate *about the
/// name* ("92% · 12"), so it reads as part of the label. Modelled as an enum
/// rather than left as two hand-written rows because everything else — the
/// gutters, the bar, the ellipsis behaviour, the tabular figures — was
/// identical and had already drifted (4dp vs 6dp under the name).
enum LeaderFigurePlacement {
  /// Centred against the whole row, after the progress bar's column.
  trailing,

  /// On the name's line, directly above the bar.
  inline,
}

/// One row of a ranked board: a leading badge, a name over a progress bar, and
/// a figure.
///
/// Replaces the dashboard's `_LeaderboardRow` and the analytics page's
/// `_EmpRow`, which were the same 40 lines twice.
class LeaderboardRow extends StatelessWidget {
  /// The leading badge — an [InitialAvatar], a [RankMedalAvatar], or a tinted
  /// icon disc. Supplied by the caller because the three boards genuinely show
  /// different things there.
  final Widget leading;

  final String name;

  /// Pre-formatted and already localized — this widget does no number
  /// formatting, so a caller can pass "92% · 12" or "27".
  final String figure;

  /// 0–1. [ProgressTrack] clamps, so a raw ratio is fine.
  final double value;

  /// Tints the bar and the figure.
  final Color color;

  final LeaderFigurePlacement placement;

  const LeaderboardRow({
    super.key,
    required this.leading,
    required this.name,
    required this.figure,
    required this.value,
    required this.color,
    this.placement = LeaderFigurePlacement.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final inline = placement == LeaderFigurePlacement.inline;

    final figureText = Text(
      figure,
      maxLines: 1,
      style: context.text.titleSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        // Tabular figures so the column of numbers stays aligned down the
        // board instead of jittering with each digit's natural width.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.r(Insets.x1h)),
      child: Row(
        children: [
          leading,
          context.gapW(Insets.x2h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inline)
                  Row(
                    children: [
                      // Expanded, not Flexible: the figure is short and fixed,
                      // so the name should take everything else and ellipsize
                      // rather than the two negotiating.
                      Expanded(child: nameText),
                      context.gapW(Insets.x2),
                      figureText,
                    ],
                  )
                else
                  nameText,
                context.gapH(inline ? Insets.x1h : Insets.x1),
                ProgressTrack(value: value, color: color),
              ],
            ),
          ),
          if (!inline) ...[
            context.gapW(Insets.x2h),
            figureText,
          ],
        ],
      ),
    );
  }
}

/// A gradient initial avatar with a rank medal clipped to its corner.
///
/// The analytics leaderboard drew this by hand — its own 42dp gradient circle
/// plus its own `name[0]` — which duplicated [InitialAvatar] including the
/// empty-name guard that stops Odoo's whitespace-only names throwing a
/// RangeError.
class RankMedalAvatar extends StatelessWidget {
  final String? name;
  final int rank;
  final double size;

  const RankMedalAvatar({
    super.key,
    required this.name,
    required this.rank,
    this.size = CompSz.avatarSm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final medal = switch (rank) {
      1 => AppColors.medalGold,
      2 => AppColors.medalSilver,
      3 => AppColors.medalBronze,
      _ => cs.onSurfaceVariant,
    };
    // Ranks 1–3 sit on fixed medal hues that pair with white. Rank 4+ falls
    // back to the theme-adaptive onSurfaceVariant, which is light in dark mode
    // — so white text would vanish there. Use the surface tone (its inverse)
    // for those so the number stays legible in both themes.
    final medalText = rank <= _medalRanks ? AppColors.onMap : cs.surface;
    final badge = context.r(CompSz.medal);

    return Stack(
      // The medal deliberately overhangs the circle, so it must not be clipped.
      clipBehavior: Clip.none,
      children: [
        InitialAvatar(name: name, size: context.r(size)),
        PositionedDirectional(
          end: -_medalOverhang,
          top: -_medalOverhang,
          child: Container(
            width: badge,
            height: badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal,
              shape: BoxShape.circle,
              // Rings the medal in the card colour so it reads as sitting on
              // top of the avatar rather than merging into it.
              border: Border.all(
                color: cs.surfaceContainerLowest,
                width: _medalOverhang,
              ),
            ),
            child: Text(
              AppNumber.whole(rank),
              maxLines: 1,
              // The disc can't grow with the OS text size, so neither may the
              // numeral: at a large setting a two-digit rank spilled out of it.
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: medalText,
                fontSize: FontSz.micro,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// How far the medal sits outside the avatar, and the width of its ring —
  /// the same 2dp, which is what makes the ring read as a cut-out.
  static const double _medalOverhang = 2.0;

  /// Ranks drawn on a metal colour (gold, silver, bronze).
  static const int _medalRanks = 3;
}
