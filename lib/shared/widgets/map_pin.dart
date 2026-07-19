import 'package:flutter/material.dart';

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

  const MapPin({
    super.key,
    required this.child,
    this.color,
    this.gradient,
    this.size = 42,
    this.borderColor = Colors.white,
    this.borderWidth = 2.5,
    this.tooltip,
  });

  /// Pin showing a glyph — a customer storefront, a visit marker.
  MapPin.icon({
    Key? key,
    required IconData icon,
    Color? color,
    Gradient? gradient,
    double size = 42,
    double borderWidth = 2.5,
    Color iconColor = Colors.white,
    String? tooltip,
  }) : this(
          key: key,
          color: color,
          gradient: gradient,
          size: size,
          borderWidth: borderWidth,
          tooltip: tooltip,
          child: Icon(icon, color: iconColor, size: size * 0.45),
        );

  /// Pin showing short text — an initial, or a stop number on the route.
  MapPin.label({
    Key? key,
    required String text,
    Color? color,
    Gradient? gradient,
    double size = 42,
    double borderWidth = 2.5,
    Color textColor = Colors.white,
    String? tooltip,
  }) : this(
          key: key,
          color: color,
          gradient: gradient,
          size: size,
          borderWidth: borderWidth,
          tooltip: tooltip,
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.36,
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    return tooltip == null ? pin : Tooltip(message: tooltip!, child: pin);
  }
}
