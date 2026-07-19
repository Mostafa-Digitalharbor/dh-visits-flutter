import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';

/// A titled card of divider-separated rows — the repeating unit of the visit
/// detail screen (info / approval / execution / participants / attachments /
/// history).
///
/// Public (rather than private to `visit_detail_page`) so the sections that
/// live in their own files can build the same shell.
class VisitSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> rows;

  const VisitSection({
    super.key,
    required this.icon,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: cs.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: context.text.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.6)),
                  rows[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
