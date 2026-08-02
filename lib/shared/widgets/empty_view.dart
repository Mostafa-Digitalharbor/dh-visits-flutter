import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../extensions/context_extensions.dart';
import 'adaptive_center.dart';
import 'ambient_pulse.dart';

/// Empty state with a softly breathing halo behind its icon.
///
/// Stateless on purpose: the halo used to be driven by a
/// `..repeat(reverse: true)` controller owned here, which held the vsync loop
/// open for as long as the empty state was on screen. [AmbientPulse] gives the
/// beat a rest gap so the app can go idle between beats — see its doc comment
/// for the measurement that motivated it.
class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The halo/icon scale with the device so the block doesn't dominate a
    // small phone, and AdaptiveCenter lets the whole thing scroll rather
    // than overflow when the viewport is short (landscape).
    final haloSize = context.r(130);
    final iconBox = context.r(78);

    // Built once and passed through as AnimatedBuilder's `child`, so the beat
    // rebuilds only the halo's gradient — never the icon inside it.
    final iconDisc = Center(
      child: Container(
        width: iconBox,
        height: iconBox,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surfaceContainerHighest,
              colors.surfaceContainerHigh,
            ],
          ),
          border: Border.all(color: colors.outlineVariant, width: 1),
        ),
        child: Icon(icon, size: context.r(36), color: colors.primary),
      ),
    );

    return AdaptiveCenter(
      padding: context.padAll(Insets.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The beat ramps 0 → 1 and rests at 1, so the halo must be at its
          // *dimmest* when the beat completes — otherwise it would sit lit
          // through every gap instead of fading away.
          AmbientPulse(
            period: const Duration(milliseconds: 1200),
            rest: const Duration(milliseconds: 1200),
            curve: Curves.easeInOut,
            builder: (_, beat) => AnimatedBuilder(
              animation: beat,
              child: iconDisc,
              builder: (_, child) => Container(
                width: haloSize,
                height: haloSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.lerp(colors.primary, colors.tertiary, 0.5)!
                          .withValues(alpha: 0.22 + 0.10 * (1 - beat.value)),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          ),
          context.gapH(Insets.x5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (action != null) ...[
            context.gapH(Insets.x5),
            action!,
          ],
        ],
      ),
    );
  }
}
