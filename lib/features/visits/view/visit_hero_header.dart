import 'package:flutter/material.dart';

import '../../../app/design/app_colors.dart';
import '../../../app/design/app_dimens.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit.dart';
import 'visit_labels.dart';

/// A rich gradient header: customer + reference + type, with the workflow
/// state badge sitting on the brand gradient.
class VisitHeroHeader extends StatelessWidget {
  final Visit visit;
  const VisitHeroHeader({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final onDark = Colors.white;
    final title = visit.partnerName ?? visit.name ?? '#${visit.id}';
    final typeText = '${visitTypeLabel(context, visit.visitType)}'
        '${visit.linkedRecordName != null ? ' · ${visit.linkedRecordName}' : ''}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.navy700, AppColors.navy900],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy900.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                color: Colors.white,
                iconColor: AppColors.cyan400,
                size: 44,
                iconSize: 24,
                radius: 13,
                tintAlpha: 0.14,
              ),
              const SizedBox(width: 12),
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
                        height: 1.15,
                      ),
                    ),
                    if (visit.name != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        visit.name!,
                        style: context.text.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  typeText,
                  style: context.text.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeroStateBadge(state: visit.state),
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
    // outline the flat list badge doesn't need — a 0.22 tint alone would sink
    // into the gradient behind it.
    final base = visitStateColor(context, state);
    return TonePill(
      label: visitStateLabel(context, state),
      color: Color.lerp(base, Colors.white, 0.25)!,
      tintAlpha: 0.22,
      borderAlpha: 0.5,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}
