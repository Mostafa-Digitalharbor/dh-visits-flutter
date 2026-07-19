import 'package:flutter/material.dart';

import '../../core/utils/app_date.dart';
import '../../features/visits/data/models/visit.dart';
import '../../features/visits/view/visit_labels.dart';
import '../extensions/context_extensions.dart';

/// A compact card summarising a visit: customer + reference, type, schedule,
/// workflow-state badge and (optionally) the responsible employee.
class VisitCard extends StatelessWidget {
  final Visit visit;
  final VoidCallback? onTap;
  final bool compact;
  final String? highlight;
  final bool showEmployee;

  const VisitCard({
    super.key,
    required this.visit,
    this.onTap,
    this.compact = false,
    this.highlight,
    this.showEmployee = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final title = visit.partnerName ?? visit.name ?? '#${visit.id}';
    final linked = visit.linkedRecordName;
    final schedule = visit.scheduledDatetime;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (visit.name != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            visit.name!,
                            style: context.text.bodySmall
                                ?.copyWith(color: cs.outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  VisitStateBadge(visit.state),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _meta(
                    context,
                    icon: visit.isOpportunity
                        ? Icons.emoji_events_outlined
                        : Icons.folder_open_outlined,
                    text: visitTypeLabel(context, visit.visitType) +
                        (linked != null ? ' · $linked' : ''),
                  ),
                  if (schedule != null)
                    _meta(
                      context,
                      icon: Icons.schedule,
                      text: AppDate.dateTime(context, schedule.toLocal()),
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
              if (!compact && visit.purpose != null) ...[
                const SizedBox(height: 8),
                Text(
                  visit.purpose!,
                  maxLines: 2,
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
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 4),
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
