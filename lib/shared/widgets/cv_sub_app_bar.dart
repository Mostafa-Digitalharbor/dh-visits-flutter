import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';
import 'icon_action_chip.dart';

/// Sub-screen app bar (design `02-components.md §8 — CvAppBar`, back variant):
/// a 40×40 direction-aware back chip + an optional eyebrow above the title,
/// then trailing action chips. Used by pushed routes (settings, customers,
/// review) so they match the redesigned shell bar instead of the plain
/// Material [AppBar].
class CvSubAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  /// Status-bar inset so the declared [preferredSize] matches what the bar
  /// actually paints (mirrors the shell `_AppBar`).
  final double topInset;

  const CvSubAppBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const [],
    this.topInset = 0,
  });

  static const double _barHeight = CompSz.subAppBarHeight;

  /// How far the title block may grow with the OS text size. The bar is fixed
  /// chrome (a PreferredSize), and two lines at the app-wide cap would push
  /// past it; 1.1× stays comfortably legible.
  static const double _maxTitleScale = 1.1;

  /// The title and eyebrow sit as a tight pair.
  static const double _lineHeight = 1.15;

  /// Space above and below the row. Everything in the row is centred, so this
  /// does not move anything. It only sets how much height the row gets. With
  /// 10dp (`Insets.x2h`) the row was 39dp tall, less than the chip's 48dp
  /// touch target, and a tablet's 48dp chip was squashed to 48×39.
  static const double _padV = Insets.x1;

  @override
  Size get preferredSize => Size.fromHeight(_barHeight + topInset);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final rtl = context.isRtl;

    return Material(
      color: cs.surfaceContainerLowest,
      child: Container(
        height: _barHeight + topInset,
        padding: EdgeInsetsDirectional.fromSTEB(
          Insets.x3h,
          _padV + topInset,
          Insets.x3h,
          _padV,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: x.outlineVariant)),
        ),
        child: Row(
          children: [
            IconActionChip(
              icon: rtl ? Symbols.arrow_forward_ios : Symbols.arrow_back_ios_new,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () {
                // maybeOf, not `context.canPop()`: that calls GoRouter.of,
                // which throws when there is no GoRouter above the bar (a
                // route pushed with a plain Navigator), so the Navigator
                // fallback below was never reached.
                final router = GoRouter.maybeOf(context);
                if (router != null && router.canPop()) {
                  router.pop();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
            context.gapW(Insets.x3),
            Expanded(
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxTitleScale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (eyebrow != null)
                      Text(eyebrow!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.eyebrow.copyWith(
                              height: _lineHeight,
                              letterSpacing: rtl ? 0 : null,
                              color: cs.onSurfaceVariant)),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.appBarTitle.copyWith(
                            height: _lineHeight,
                            letterSpacing: rtl ? 0 : null,
                            color: cs.onSurface)),
                  ],
                ),
              ),
            ),
            for (final a in actions) ...[context.gapW(Insets.x2), a],
          ],
        ),
      ),
    );
  }
}

