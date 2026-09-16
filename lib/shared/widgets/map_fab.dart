import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../extensions/context_extensions.dart';

/// A floating control button that sits on top of a map — zoom, recentre,
/// open-in-maps: a rounded square with a primary-tinted icon.
///
/// Shared by the visit map card and the full-screen visit trail, so the ink
/// shape, tap target and elevation are defined once.
class MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Optional accessibility label — map glyphs carry no text of their own.
  final String? semanticLabel;

  static const double _size = 44;
  static const double _elevation = 3;

  const MapFab.rounded({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.btn));
    final button = Material(
      color: colors.surface,
      shape: shape,
      elevation: _elevation,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Icon(icon, color: colors.primary),
        ),
      ),
    );
    return semanticLabel == null
        ? button
        : Semantics(button: true, label: semanticLabel, child: button);
  }
}
