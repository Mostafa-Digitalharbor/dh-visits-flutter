import 'package:flutter/material.dart';

/// Brand-styled `RefreshIndicator` wrapper. Picks the primary color for
/// the spinner stroke, the surface for the disc background, and a
/// thinner stroke so the spinner feels lighter and more modern than
/// Material's default.
class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      strokeWidth: 2.4,
      displacement: 56,
      child: child,
    );
  }
}
