import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../../core/utils/app_date.dart';
import '../../core/utils/user_time.dart';
import '../../features/visits/data/models/visit.dart';
import '../../features/visits/view/visit_labels.dart';
import '../extensions/context_extensions.dart';

/// A compact card summarising a visit: customer + reference, type, schedule,
/// workflow-state badge and (optionally) the responsible employee.
class VisitCard extends StatelessWidget {
  final Visit visit;
  final VoidCallback? onTap;
  final bool showEmployee;

  const VisitCard({
    super.key,
    required this.visit,
    this.onTap,
    this.showEmployee = false,
  });

  /// The widest the state badge may get, as a share of the screen. A long
  /// Arabic state ("بانتظار اعتماد مدير المشروع") at a large text size would
  /// otherwise squeeze the customer name down to nothing.
  static const double _badgeMaxShare = 0.45;

  /// Lines of purpose shown under the facts.
  static const int _purposeLines = 2;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final schedule = visit.scheduledDatetime;
    // The reference is its own line only when the title is the customer —
    // otherwise the title already *is* the reference.
    final reference = visit.partnerName != null ? visit.name : null;

    return Card(
      margin: EdgeInsets.symmetric(vertical: context.rh(Insets.x1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: context.padAll(Insets.x3h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.displayTitle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (reference != null) ...[
                          context.gapH(Insets.hair),
                          Text(
                            reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall
                                ?.copyWith(color: cs.outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                  context.gapW(Insets.x2),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.screenW * _badgeMaxShare,
                    ),
                    child: VisitStateBadge(visit.state),
                  ),
                ],
              ),
              context.gapH(Insets.x2h),
              Wrap(
                spacing: context.r(Insets.x3),
                runSpacing: context.rh(Insets.x1),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _meta(
                    context,
                    icon: visit.isOpportunity
                        ? Icons.emoji_events_outlined
                        : Icons.folder_open_outlined,
                    text: context.joinFacts([
                      visitTypeLabel(context, visit.visitType),
                      visit.linkedRecordName,
                    ]),
                  ),
                  if (schedule != null)
                    _meta(
                      context,
                      icon: Icons.schedule,
                      // The Odoo user's timezone, like every other visit time.
                      text: AppDate.dateTime(
                          context, context.toUserTime(schedule)),
                    ),
                  if (showEmployee && visit.employeeName != null)
                    _meta(
                      context,
                      icon: Icons.person_outline,
                      text: visit.employeeName!,
                    ),
                  if (visit.isEscalated)
                    _meta(
                      context,
                      icon: Icons.priority_high_rounded,
                      text: context.s.wfEscalatedBadge,
                      color: cs.error,
                    ),
                ],
              ),
              if (visit.purpose != null) ...[
                context.gapH(Insets.x2),
                Text(
                  visit.purpose!,
                  maxLines: _purposeLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(
    BuildContext context, {
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final c = color ?? context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: context.r(IconSz.pill), color: c),
        context.gapW(Insets.x1),
        // Flexible, not a bare Text: the enclosing Wrap hands the Row its full
        // maxWidth, so an unbounded Text takes its intrinsic width and blows
        // past the card. These labels carry user data (Odoo project /
        // opportunity and employee names, longer in Arabic) and do overflow.
        // Loose fit keeps short labels at their natural width.
        Flexible(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(color: c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
