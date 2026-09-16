import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/constants.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/visit_tracking_consent.dart';

/// Shown before the first Start Visit (and again when its text version
/// changes): what is collected, that it continues in the background and with
/// the screen locked while the visit is in progress, when it stops, where it
/// goes. It comes before any location prompt — Google Play's
/// prominent-disclosure requirement, and the explanation Apple expects for
/// background location.
///
/// Returns true only when the user explicitly agreed.
class VisitTrackingDisclosureDialog extends StatelessWidget {
  const VisitTrackingDisclosureDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VisitTrackingDisclosureDialog(),
    );
    return agreed ?? false;
  }

  /// True when [consent] already holds the user's agreement; otherwise shows
  /// the disclosure and remembers a "yes". Every path that starts recording a
  /// visit goes through this, so none can skip the disclosure.
  static Future<bool> ensureAccepted(
    BuildContext context,
    VisitTrackingConsent consent,
  ) async {
    if (consent.accepted) return true;
    if (!context.mounted) return false;
    final agreed = await show(context);
    if (agreed) await consent.accept();
    return agreed;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final colors = context.colors;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final paragraphs = [
      s.visitTrackingDisclosureBody,
      s.visitTrackingDisclosureStops,
      s.visitTrackingDisclosureStorage,
      ios ? s.visitTrackingDisclosureIos : s.visitTrackingDisclosureAndroid,
    ];
    final buttonPadding = context.padSym(v: Insets.x3h, h: Insets.x2);
    return AppDialogFrame(
      icon: Symbols.share_location,
      title: s.visitTrackingDisclosureTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i > 0) context.gapH(Insets.x3),
            Text(
              paragraphs[i],
              style: context.text.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
      // Decline first: in the frame's row the primary action sits at the end,
      // as on every other dialog in the app.
      actions: [
        TextButton(
          key: WidgetKeys.visitTrackingDisclosureDecline,
          style: TextButton.styleFrom(padding: buttonPadding),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.visitTrackingDisclosureDecline,
              textAlign: TextAlign.center),
        ),
        FilledButton(
          key: WidgetKeys.visitTrackingDisclosureAgree,
          style: FilledButton.styleFrom(padding: buttonPadding),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.visitTrackingDisclosureAgree,
              textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
