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

  /// How far the state tone is lifted toward white so muted tones stay legible
  /// on navy.
  static const double _badgeLift = 0.25;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
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
              context.gapW(Insets.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
              ),
            ],
          ),
          context.gapH(Insets.x3h),
          Row(
            children: [
              Expanded(
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
    // into the gradient behind it.
    final base = visitStateColor(context, state);
    return TonePill(
      label: visitStateLabel(context, state),
      color: Color.lerp(base, AppColors.onMap, VisitHeroHeader._badgeLift)!,
      tintAlpha: Alphas.halo,
      borderAlpha: Alphas.disabled,
      padding: context.padSym(h: Insets.x3, v: Insets.x1h),
    );
  }
}
