import 'package:flutter/material.dart';

import '../../app/design/app_typography.dart';

import '../../core/constants.dart';
import '../../core/utils/communications.dart';

/// OpenStreetMap credit badge.
///
/// The tiles rendered by [AppMapTileLayer] come from OpenStreetMap, whose ODbL
/// licence requires the credit to be visible on the map itself — not buried in
/// an about screen. Both stores also ask you to declare third-party content and
/// confirm you hold the rights to it, and that declaration only holds while this
/// badge ships.
///
/// Add it as the LAST child of every [FlutterMap] so it paints above the tiles
/// and markers. It sits bottom-right by default, which is where the tap targets
/// on our maps (recentre / navigate buttons) are not.
class AppMapAttribution extends StatelessWidget {
  /// Corner to pin the badge to. The visit-detail card puts its navigate button
  /// bottom-right, so that one passes [Alignment.bottomLeft].
  final Alignment alignment;

  const AppMapAttribution({super.key, this.alignment = Alignment.bottomRight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Plain white/black rather than a theme colour: the badge sits on map tiles,
    // not on the app's surfaces, and the tiles are light in both themes (the
    // dark-mode tint only darkens them part way).
    final fg = isDark ? Colors.white : Colors.black87;
    final bg = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => Communications.openWeb(AppConstants.osmCopyrightUrl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: FontSz.micro, height: 1.2, color: fg),
                // Never let a large system font size blow the badge up over
                // the map; the credit only has to be legible, not prominent.
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
