import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/constants.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';

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
    final buttonPadding = context.padSym(v: Insets.x3h, h: Insets.x2);
    // The shared frame, like the visit disclosure beside it: it owns the
    // rounded shape, the tinted icon halo, the scroll for a long translation
    // and the equal-width action row. Hand-rolling those again is how this
    // dialog ended up with four raw dp values and its own key strings.
    return AppDialogFrame(
      icon: Symbols.share_location,
      title: s.workdayDisclosureTitle,
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
          key: WidgetKeys.workdayDisclosureDecline,
          style: TextButton.styleFrom(padding: buttonPadding),
          onPressed: () => Navigator.of(context).pop(false),
          child:
              Text(s.workdayDisclosureDecline, textAlign: TextAlign.center),
        ),
        FilledButton(
          key: WidgetKeys.workdayDisclosureAgree,
          style: FilledButton.styleFrom(padding: buttonPadding),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.workdayDisclosureAgree, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
