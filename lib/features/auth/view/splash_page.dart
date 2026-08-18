import 'package:flutter/material.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';

import '../../../app/design/app_assets.dart';
import '../../../shared/extensions/context_extensions.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _zoomController;
  late final AnimationController _pulseController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Elastic-ish zoom from 0.3 → slight overshoot → 1.0
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_zoomController);

    _fade = CurvedAnimation(
      parent: _zoomController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _zoomController.forward();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colors.surface,
                    colors.surfaceContainerHigh,
                  ]
                : [
                    colors.primary,
                    Color.lerp(colors.primary, colors.tertiary, 0.6) ??
                        colors.primary,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_zoomController, _pulseController]),
              builder: (context, _) {
                final onGradient =
                    isDark ? colors.onSurface : colors.onPrimary;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _scale.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulsing halo
                          Opacity(
                            opacity: 0.25 +
                                (0.15 *
                                    (1 -
                                        (_pulseController.value - 0.5).abs() *
                                            2)),
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: onGradient.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            // The plate-less mark, not the full logo: the white
                            // circle above already supplies the shape. No
                            // ClipOval — the glyph is transparent and inscribed,
                            // so clipping would only shave its corners.
                            child: Image.asset(
                              AppAssets.logoMark,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    context.gapH(Insets.x8),
                    Opacity(
                      opacity: _fade.value,
                      child: Column(
                        children: [
                          Text(
                            context.s.appTitle,
                            style: context.text.headlineMedium?.copyWith(
                              color: onGradient,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          context.gapH(Insets.x2),
                          Text(
                            context.s.appTagline,
                            style: context.text.bodyMedium?.copyWith(
                              color: onGradient.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    context.gapH(Insets.x12 + Insets.x2),
                    Opacity(
                      opacity: _fade.value,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: onGradient.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
