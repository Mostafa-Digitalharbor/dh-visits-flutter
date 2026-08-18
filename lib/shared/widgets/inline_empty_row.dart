import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../extensions/context_extensions.dart';

/// "Nothing here" line rendered *inside* a card, as opposed to [EmptyView],
/// which takes over a whole screen.
///
/// Four screens had their own copy of this row; the one thing they kept getting
/// wrong differently was whether the text was `Expanded` — without it a longer
/// localized sentence overflows the card.
class InlineEmptyRow extends StatelessWidget {
  final String text;
  final IconData icon;

  const InlineEmptyRow({
    super.key,
    required this.text,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.r(Insets.x2)),
      child: Row(
        children: [
          Icon(icon, size: context.r(IconSz.label), color: muted),
          context.gapW(Insets.x2),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
