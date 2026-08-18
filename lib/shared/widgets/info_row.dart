import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
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
      padding: EdgeInsets.symmetric(vertical: context.r(Insets.x1h)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            // Glyph-only, so it tracks the device width rather than the text
            // scale — see [IconActionChip] for the same reasoning.
            width: context.r(CompSz.infoDot),
            height: context.r(CompSz.infoDot),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer.withValues(alpha: Alphas.disabled),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: context.r(IconSz.pill),
              color: colors.onPrimaryContainer,
            ),
          ),
          context.gapW(Insets.x2h),
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
