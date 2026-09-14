import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Shown before the first "Start work day" (and again when its text version
/// changes): what is collected, that it continues in the background and with
/// the screen locked, when it stops, where it goes. It comes before any
/// permission prompt — Google Play's prominent-disclosure requirement, and
/// the explanation Apple expects before asking for "Always".
///
/// Returns true only when the user explicitly agreed.
class WorkdayDisclosureDialog extends StatelessWidget {
  const WorkdayDisclosureDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WorkdayDisclosureDialog(),
    );
    return agreed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final colors = context.colors;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final paragraphs = [
      s.workdayDisclosureBody,
      s.workdayDisclosureStops,
      s.workdayDisclosureStorage,
      ios ? s.workdayDisclosureIos : s.workdayDisclosureAndroid,
    ];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Symbols.share_location, size: 32, color: colors.primary),
              ),
            ),
            context.gapH(Insets.x3),
            Text(
              s.workdayDisclosureTitle,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            for (final paragraph in paragraphs) ...[
              context.gapH(Insets.x3),
              Text(
                paragraph,
                style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            context.gapH(Insets.x6),
            FilledButton(
              key: const Key('workday-disclosure-agree'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(s.workdayDisclosureAgree),
            ),
            context.gapH(Insets.x2),
            TextButton(
              key: const Key('workday-disclosure-decline'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.workdayDisclosureDecline),
            ),
          ],
        ),
      ),
    );
  }
}
