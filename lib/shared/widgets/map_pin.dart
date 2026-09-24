import 'package:flutter/material.dart';

import '../../app/design/app_colors.dart';
import '../../app/design/app_dimens.dart';

/// Circular marker for a `flutter_map` layer: a filled disc with a white ring
/// and a drop shadow, holding an icon, an initial or a number.
///
/// Five pins across four screens drew this by hand, each with its own border
/// width (2–3.5) and shadow (blur 5–12, offset 2–5) — visibly different weights
/// for the same idea. The ring and shadow are what make a pin legible over map
/// tiles, so they belong in one place.
class MapPin extends StatelessWidget {
  final Widget child;

  /// Flat fill. Ignored when [gradient] is set.
  final Color? color;
  final Gradient? gradient;

  final double size;
  final Color borderColor;
  final double borderWidth;

  /// Wraps the pin in a [Tooltip] — used where the pin stands for a person
  /// whose name doesn't fit on the map.
  final String? tooltip;

  /// How much of the disc a glyph fills.
  static const _glyphShare = 0.45;

  /// The drop shadow that lifts a pin off the tiles.
  static const _shadow = [
    BoxShadow(
      color: AppColors.shadowStrong,
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];

  const MapPin({
    super.key,
    required this.child,
    this.color,
    this.gradient,
    this.size = CompSz.mapPin,
    this.borderColor = Colors.white,
    this.borderWidth = CompSz.mapPinRing,
    this.tooltip,
  });

  /// Pin showing a glyph — a customer storefront, a visit marker.
  MapPin.icon({
    Key? key,
    required IconData icon,
    Color? color,
    Gradient? gradient,
    double size = CompSz.mapPin,
    double borderWidth = CompSz.mapPinRing,
    Color iconColor = Colors.white,
    String? tooltip,
  }) : this(
          key: key,
          color: color,
          gradient: gradient,
          size: size,
          borderWidth: borderWidth,
          tooltip: tooltip,
          child: Icon(icon, color: iconColor, size: size * _glyphShare),
        );

  /// Pin showing short text — an initial, or a stop number on the route.
  MapPin.label({
    Key? key,
    required String text,
    Color? color,
    Gradient? gradient,
    double size = CompSz.mapPin,
    double borderWidth = CompSz.mapPinRing,
    Color textColor = Colors.white,
    String? tooltip,
  }) : this(
          key: key,
          color: color,
          gradient: gradient,
          size: size,
          borderWidth: borderWidth,
          tooltip: tooltip,
          // One line, shrunk to fit: the disc is a fixed-size map marker but
          // the text follows the OS text size, so at 1.25x a stop number
          // like "12" wrapped onto a second line and the disc cut it off.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
              ),
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final pin = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gradient == null ? color : null,
        gradient: gradient,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: _shadow,
      ),
      child: child,
    );
    return tooltip == null ? pin : Tooltip(message: tooltip!, child: pin);
  }
}
