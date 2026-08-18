import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';

enum AppButtonVariant { primary, secondary, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.variant = AppButtonVariant.primary,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveOnPressed = loading ? null : onPressed;

    final child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == AppButtonVariant.secondary
                  ? colors.primary
                  : colors.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                context.gapW(Insets.x2),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = FilledButton(onPressed: effectiveOnPressed, child: child);
        break;
      case AppButtonVariant.secondary:
        button = OutlinedButton(onPressed: effectiveOnPressed, child: child);
        break;
      case AppButtonVariant.destructive:
        button = FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        );
        break;
    }

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
