import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle? textStyle;
  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer.withValues(alpha: 0.5),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 15,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: textStyle ?? context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
