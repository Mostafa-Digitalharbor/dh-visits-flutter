import 'package:flutter/material.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
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
          padding: EdgeInsetsDirectional.only(
            start: context.r(Insets.x1),
            bottom: context.r(Insets.x2),
          ),
          child: Row(
            children: [
              Icon(icon, size: context.r(IconSz.badge), color: cs.primary),
              context.gapW(Insets.x2),
              Expanded(
                child: Text(
                  title,
                  style: context.text.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
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
            padding: context.padSym(h: Insets.x3h, v: Insets.x1),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(
                        alpha: Alphas.subdued,
                      ),
                    ),
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
