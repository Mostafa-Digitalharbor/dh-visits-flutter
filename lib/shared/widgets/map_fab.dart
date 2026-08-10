import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../extensions/context_extensions.dart';

/// The floating control buttons that sit on top of a map — zoom, recentre,
/// open-in-maps.
///
/// Two screens grew their own private copy of this (`nearby_map_page` and
/// `visit_map_card`) with the same structure and slightly different chrome.
/// One implementation, two named constructors: the call sites keep the look
/// they were designed with, and the behaviour (ink shape matching the outer
/// shape, tap target, elevation) is defined once.
class MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Rounded-square button, primary-tinted icon. Used on the visit detail map.
  final bool _rounded;

  /// Optional accessibility label — map glyphs carry no text of their own.
  final String? semanticLabel;

  const MapFab.circle({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  }) : _rounded = false;

  const MapFab.rounded({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  }) : _rounded = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = _rounded
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.btn))
        : const CircleBorder();
    final button = Material(
      color: colors.surface,
      shape: shape,
      elevation: _rounded ? 3 : 4,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: _rounded
            ? SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: colors.primary),
              )
            : Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(icon, size: 20, color: colors.onSurface),
              ),
      ),
    );
    return semanticLabel == null
        ? button
        : Semantics(button: true, label: semanticLabel, child: button);
  }
}
