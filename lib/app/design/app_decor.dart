import 'package:flutter/material.dart';

import '../../shared/extensions/context_extensions.dart';
import '../theme.dart';

/// Shared [BoxDecoration] recipes.
///
/// These are factories rather than wrapper widgets on purpose: the panels that
/// use them already sit inside a `Container` that carries its own padding,
/// constraints or alignment, so returning a decoration composes cleanly instead
/// of adding another element to every tree.
class AppDecor {
  AppDecor._();

  /// The app's standard raised panel — lightest surface, hairline outline and
  /// the level-1 shadow. Analytics tiles, review cards, route cards, the home
  /// action chips and the customer stat tiles were each declaring this by hand;
  /// the copies had already drifted apart on whether they carried a shadow.
  static BoxDecoration panel(
    BuildContext context, {
    double radius = Radii.lg,
    bool shadow = true,
    Color? color,
  }) {
    final x = context.x;
    return BoxDecoration(
      color: color ?? context.colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: x.outlineVariant),
      boxShadow: shadow ? x.elev1 : null,
    );
  }
}
