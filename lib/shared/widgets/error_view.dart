import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../extensions/context_extensions.dart';
import 'adaptive_center.dart';
import 'app_button.dart';

/// A failure that takes over the screen: icon, the localized sentence that
/// says what went wrong and what to do, and one way forward.
class ErrorView extends StatelessWidget {
  final String message;

  /// The way forward. Labelled [actionLabel] — "Retry" when not given.
  final VoidCallback? onRetry;
  final String? actionLabel;
  final IconData actionIcon;

  final IconData icon;

  /// Small print under the message ("Error code: server") so a screenshot sent
  /// to support says which failure it was. Null hides it.
  final String? reference;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.actionLabel,
    this.actionIcon = Icons.refresh,
    this.icon = Icons.error_outline,
    this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final ref = reference;
    return AdaptiveCenter(
      padding: context.padAll(Insets.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.r(CompSz.errorGlyph), color: context.colors.error),
          context.gapH(Insets.x4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge,
          ),
          if (ref != null) ...[
            context.gapH(Insets.x2),
            Text(
              context.s.commonErrorReference(ref),
              textAlign: TextAlign.center,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
          if (onRetry != null) ...[
            context.gapH(Insets.x5),
            AppButton.secondary(
              label: actionLabel ?? context.s.commonRetry,
              icon: actionIcon,
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}
