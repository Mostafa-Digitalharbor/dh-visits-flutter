import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';

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

  static const double _barHeight = 60;

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
        padding: EdgeInsets.fromLTRB(14, 10 + topInset, 14, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: x.outlineVariant)),
        ),
        child: Row(
          children: [
            _Chip(
              icon: rtl ? Symbols.arrow_forward_ios : Symbols.arrow_back_ios_new,
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              // The bar is a fixed-height chrome element (PreferredSize). Cap
              // how far the eyebrow + title can scale up so a large system
              // font setting can't push the two lines past the 60px bar and
              // trigger a vertical overflow; 1.1x stays comfortably legible.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (eyebrow != null)
                      Text(eyebrow!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: cs.onSurfaceVariant)),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: cs.onSurface)),
                  ],
                ),
              ),
            ),
            for (final a in actions) ...[const SizedBox(width: 8), a],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: x.outlineVariant),
          boxShadow: x.elev1,
        ),
        child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      ),
    );
  }
}
