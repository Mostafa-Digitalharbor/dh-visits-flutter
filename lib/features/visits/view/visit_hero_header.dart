import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit.dart';
import 'visit_labels.dart';

/// A rich gradient header: customer + reference + type, with the workflow
/// state badge sitting on the brand gradient.
class VisitHeroHeader extends StatelessWidget {
  final Visit visit;
  const VisitHeroHeader({super.key, required this.visit});

  /// The first and the largest step a state tone is lifted toward white on the
  /// navy gradient, and the contrast that stops the lift (WCAG AA for text).
  static const double _minLift = 0.25;
  static const double _maxLift = 0.9;
  static const double _liftStep = 0.05;
  static const double _minContrast = 4.5;

  /// [base] lifted toward white just far enough to read on [background].
  ///
  /// A fixed lift was not enough for every state: "Done" is the success
  /// container's dark green, and at 25% it still sank into the navy (seen on
  /// the emulator, 2026-09-17).
  static Color legibleOn(Color base, Color background) {
    for (var t = _minLift; t < _maxLift; t += _liftStep) {
      final lifted = Color.lerp(base, AppColors.onMap, t)!;
      if (_contrast(lifted, background) >= _minContrast) return lifted;
    }
    return Color.lerp(base, AppColors.onMap, _maxLift)!;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final (hi, lo) = la > lb ? (la, lb) : (lb, la);
    return (hi + 0.05) / (lo + 0.05);
  }

  @override
  Widget build(BuildContext context) {
    const onDark = AppColors.onMap;
    final title = visit.displayTitle(context);
    final typeText = context.joinFacts([
      visitTypeLabel(context, visit.visitType),
      visit.linkedRecordName,
    ]);
    // The reference is shown under the title only when the title is not
    // already the reference.
    final reference = visit.partnerName != null ? visit.name : null;
    return Container(
      padding: context.padAll(Insets.x4h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: [AppColors.navy700, AppColors.navy900],
        ),
        boxShadow: context.x.glowBrand,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaRow(
            // Start-aligned: the title may run to two lines and the badge
            // stays level with the first of them.
            alignment: CrossAxisAlignment.start,
            leading: IconBadge(
              icon: visit.isOpportunity
                  ? Icons.emoji_events_outlined
                  : Icons.storefront_outlined,
              color: onDark,
              iconColor: AppColors.cyan400,
              size: context.r(CompSz.avatar),
              iconSize: context.r(IconSz.md),
              radius: Radii.sm,
              tintAlpha: Alphas.tintStrong,
            ),
            lines: [
              AutoDirectionText(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge?.copyWith(
                  color: onDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (reference != null) ...[
                context.gapH(Insets.x1),
                Text(
                  reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: onDark.withValues(alpha: Alphas.subdued),
                  ),
                ),
              ],
            ],
          ),
          context.gapH(Insets.x3h),
          Row(
            children: [
              Expanded(
                // Composed by joinFacts, which isolates the foreign part, so
                // the line follows the screen's direction.
                child: Text(
                  typeText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: onDark.withValues(alpha: Alphas.scrim),
                  ),
                ),
              ),
              context.gapW(Insets.x2),
              Flexible(child: _HeroStateBadge(state: visit.state)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The state badge tuned for the dark hero (higher-contrast pill).
class _HeroStateBadge extends StatelessWidget {
  final VisitState state;
  const _HeroStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    // Lift muted state tones so they stay legible on navy, and carry an
    // outline the flat list badge doesn't need — a faint tint alone would sink
    // into the gradient behind it. Measured against the gradient's lighter
    // end, where contrast is lowest.
    final base = visitStateColor(context, state);
    return TonePill(
      label: visitStateLabel(context, state),
      color: VisitHeroHeader.legibleOn(base, AppColors.navy700),
      tintAlpha: Alphas.halo,
      borderAlpha: Alphas.disabled,
      padding: context.padSym(h: Insets.x3, v: Insets.x1h),
    );
  }
}
