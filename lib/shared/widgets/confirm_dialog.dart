import 'package:flutter/material.dart';

import '../../app/design/responsive.dart';

import '../extensions/context_extensions.dart';
import '../../app/design/app_dimens.dart';

/// Generic Yes/No confirmation dialog. The confirm button is rendered as a
/// destructive (red) filled button to discourage accidental taps.
///
/// Returns `true` if the user confirmed, `false` or `null` otherwise.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final IconData? icon;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.icon,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      // Scrollable because this is a bare Dialog, not an AlertDialog (which
      // scrolls its content for you): icon + title + a long message + two
      // buttons exceeds a landscape viewport at the 1.25 text-scale cap, and
      // an overflowing confirm dialog can hide the very buttons it's asking
      // the user to choose between.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: colors.error),
              ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            context.gapH(Insets.x2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            context.gapH(Insets.x6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.sm)),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelLabel ?? context.s.commonNo),
                  ),
                ),
                context.gapW(Insets.x3),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.sm)),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmLabel ?? context.s.commonYes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
