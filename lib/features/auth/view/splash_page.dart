import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Timings and sizes of the launch animation. The logo zoom must finish inside
/// `AuthBloc`'s minimum splash time (2s), or the redirect cuts it short.
abstract final class _Splash {
  static const zoomDuration = Duration(milliseconds: 1200);
  static const pulseDuration = Duration(milliseconds: 1400);

  /// The zoom starts small, overshoots, then settles.
  static const zoomFrom = 0.3;
  static const zoomOvershoot = 1.15;
  static const zoomRiseWeight = 65.0;
  static const zoomSettleWeight = 35.0;

  /// The wordmark fades in over the second half of the zoom.
  static const fadeStart = 0.5;

  /// The halo's opacity swings between these two values with the pulse.
  static const haloMinOpacity = 0.25;
  static const haloPulseRange = 0.15;

  static const halo = 200.0;
  static const plate = 130.0;
  static const plateShadowBlur = 30.0;
  static const plateShadowOffset = Offset(0, 10);
  static const spinner = 28.0;
  static const spinnerStroke = 2.5;
  static const titleTracking = 0.5;

  /// Space between the tagline and the spinner.
  static const spinnerGap = Insets.x12 + Insets.x2;
}

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
      duration: _Splash.zoomDuration,
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: _Splash.zoomFrom, end: _Splash.zoomOvershoot)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: _Splash.zoomRiseWeight,
      ),
      TweenSequenceItem(
        tween: Tween(begin: _Splash.zoomOvershoot, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _Splash.zoomSettleWeight,
      ),
    ]).animate(_zoomController);

    _fade = CurvedAnimation(
      parent: _zoomController,
      curve: const Interval(_Splash.fadeStart, 1.0, curve: Curves.easeIn),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: _Splash.pulseDuration,
    )..repeat(reverse: true);

    _zoomController.forward();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// 0 → 1 → 0 across one pulse cycle.
  double get _pulse => 1 - (_pulseController.value - 0.5).abs() * 2;

  @override
  Widget build(BuildContext context) {
    const onBrand = AppColors.onMap;
    final halo = context.r(_Splash.halo);
    final plate = context.r(_Splash.plate);
    final spinner = context.r(_Splash.spinner);

    return Scaffold(
      body: DecoratedBox(
        // The theme's brand gradient carries its own dark variant.
        decoration: BoxDecoration(gradient: context.x.brandGradient),
        child: SafeArea(
          child: Center(
            // Scales the whole composition down rather than overflowing on a
            // phone held sideways, where it is taller than the screen.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: context.padAll(Insets.x4),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_zoomController, _pulseController]),
                  builder: (context, _) {
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
                                opacity: _Splash.haloMinOpacity +
                                    _Splash.haloPulseRange * _pulse,
                                child: Container(
                                  width: halo,
                                  height: halo,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: onBrand.withValues(alpha: Alphas.tintStrong),
                                  ),
                                ),
                              ),
                              Container(
                                width: plate,
                                height: plate,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: onBrand,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.shadowSoft,
                                      blurRadius: _Splash.plateShadowBlur,
                                      offset: _Splash.plateShadowOffset,
                                    ),
                                  ],
                                ),
                                padding: context.padAll(Insets.x4h),
                                // The plate-less mark, not the full logo: the
                                // white circle already supplies the shape. No
                                // ClipOval — the glyph is transparent and
                                // inscribed, so clipping would only shave its
                                // corners.
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
                                  color: onBrand,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: _Splash.titleTracking,
                                ),
                              ),
                              context.gapH(Insets.x2),
                              Text(
                                context.s.appTagline,
                                textAlign: TextAlign.center,
                                style: context.text.bodyMedium?.copyWith(
                                  color: onBrand.withValues(alpha: Alphas.scrim),
                                ),
                              ),
                            ],
                          ),
                        ),
                        context.gapH(_Splash.spinnerGap),
                        Opacity(
                          opacity: _fade.value,
                          child: SizedBox.square(
                            dimension: spinner,
                            child: const CircularProgressIndicator(
                              strokeWidth: _Splash.spinnerStroke,
                              color: onBrand,
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
        ),
      ),
    );
  }
}
