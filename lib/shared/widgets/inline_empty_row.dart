import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 8),
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
