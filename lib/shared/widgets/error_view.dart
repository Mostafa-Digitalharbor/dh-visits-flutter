import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../extensions/context_extensions.dart';
import 'adaptive_center.dart';
import 'app_button.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveCenter(
      padding: context.padAll(Insets.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.r(56), color: context.colors.error),
          context.gapH(Insets.x4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge,
          ),
          if (onRetry != null) ...[
            context.gapH(Insets.x5),
            AppButton.secondary(
              label: context.s.commonRetry,
              icon: Icons.refresh,
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}
