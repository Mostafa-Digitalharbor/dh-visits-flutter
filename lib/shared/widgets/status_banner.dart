import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';

import '../../app/design/app_typography.dart';

/// Slim tinted strip that sits under the AppBar to report an app-wide
/// condition — offline, queued work, location sharing stopped.
///
/// Shared so every such strip is the same height, weight and tint: they stack
/// (offline + location off can be true at once) and mismatched ones would read
/// as unrelated widgets rather than one status area.
class StatusBanner extends StatelessWidget {
  /// Tint for the icon, text and hairline. The background and border derive
  /// from it, so callers pass one colour rather than three.
  final Color color;
  final IconData icon;
  final String message;

  /// Optional affordance on the trailing edge — "Retry", "Settings".
  final Widget? action;

  const StatusBanner({
    super.key,
    required this.color,
    required this.icon,
    required this.message,
    this.action,
  });

  /// A hairline under the strip — half the usual, so stacked banners read as
  /// one status area rather than separate boxes.
  static const double _borderWidth = CompSz.hairline / 2;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: Alphas.tint),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: context.padSym(h: Insets.x3, v: Insets.x2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: color.withValues(alpha: Alphas.border),
                width: _borderWidth,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: context.r(IconSz.xs), color: color),
              context.gapW(Insets.x2),
              // Expanded, not bare: these messages are localized sentences that
              // grow in Arabic and at large text scales.
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: FontSz.sm,
                  ),
                ),
              ),
              if (action != null) ...[
                context.gapW(Insets.x2),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
