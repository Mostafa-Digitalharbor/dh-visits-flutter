import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';

/// How a dialog's primary action reads.
enum DialogTone {
  /// Irreversible — sign out, cancel a visit. Red.
  destructive,

  /// A normal step forward — open settings, continue. Brand colour.
  neutral,
}

/// The app's dialog chrome: a width-bounded, scrollable card with an optional
/// icon halo, a title, a body and an action row.
///
/// Scrollable because this is a bare [Dialog], not an [AlertDialog]: icon +
/// title + a long message + two buttons exceeds a landscape viewport at the
/// largest text scale, and an overflowing dialog can hide the very buttons it
/// asks the user to choose between. Width-bounded so paragraphs keep a
/// readable measure on tablets.
class AppDialogFrame extends StatelessWidget {
  final IconData? icon;
  final DialogTone tone;
  final String title;
  final Widget body;
  final List<Widget> actions;

  const AppDialogFrame({
    super.key,
    this.icon,
    this.tone = DialogTone.neutral,
    required this.title,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (halo, glyph) = switch (tone) {
      DialogTone.destructive => (colors.errorContainer, colors.error),
      DialogTone.neutral => (colors.primaryContainer, colors.primary),
    };
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CompSz.dialogMaxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            context.r(Insets.x5),
            context.r(Insets.x6),
            context.r(Insets.x5),
            context.r(Insets.x4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(
                  child: Container(
                    padding: context.padAll(Insets.x3h),
                    decoration: BoxDecoration(
                      color: halo.withValues(alpha: Alphas.soft),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: context.r(IconSz.dialog), color: glyph),
                  ),
                ),
                context.gapH(Insets.x3),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              context.gapH(Insets.x2),
              body,
              context.gapH(Insets.x6),
              IntrinsicHeight(child: _ActionRow(actions: actions)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width buttons side by side. Labels wrap rather than clip, so a long
/// translation or a large font grows the buttons instead of hiding the text.
class _ActionRow extends StatelessWidget {
  final List<Widget> actions;
  const _ActionRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) context.gapW(Insets.x3),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

/// Generic yes/no confirmation. Returns `true` only when the user confirmed.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final IconData? icon;
  final DialogTone tone;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.icon,
    this.tone = DialogTone.destructive,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    IconData? icon,
    DialogTone tone = DialogTone.destructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        tone: tone,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
    );
    final padding = EdgeInsets.symmetric(
      vertical: context.r(Insets.x3h),
      horizontal: context.r(Insets.x4),
    );
    return AppDialogFrame(
      icon: icon,
      tone: tone,
      title: title,
      body: Text(
        message,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(padding: padding, shape: shape),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? context.s.commonNo, textAlign: TextAlign.center),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                tone == DialogTone.destructive ? colors.error : colors.primary,
            foregroundColor:
                tone == DialogTone.destructive ? colors.onError : colors.onPrimary,
            padding: padding,
            shape: shape,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? context.s.commonYes, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
