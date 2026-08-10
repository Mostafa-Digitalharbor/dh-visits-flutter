import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: color.withValues(alpha: 0.30),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
