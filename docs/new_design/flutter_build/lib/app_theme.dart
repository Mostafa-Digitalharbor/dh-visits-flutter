// app_theme.dart — assembles ThemeData (light/dark) + AppX (semantic extras not in ColorScheme).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tokens that ColorScheme can't carry: status hues + containers, brand-tinted
/// elevation shadows, brand glow, and the two gradients. Access via
/// `Theme.of(context).extension<AppX>()!`.
@immutable
class AppX extends ThemeExtension<AppX> {
  final Color success, successContainer, onSuccessContainer;
  final Color warning, warningContainer, onWarningContainer;
  final Color info, infoContainer, onInfoContainer;
  final Color textTertiary, textDisabled, outlineVariant, divider, accentHover;
  final List<BoxShadow> elev1, elev2, elev3, elev4, glowBrand, glowSuccess;
  final Gradient brandGradient, avatarGradient;
  const AppX({
    required this.success, required this.successContainer, required this.onSuccessContainer,
    required this.warning, required this.warningContainer, required this.onWarningContainer,
    required this.info, required this.infoContainer, required this.onInfoContainer,
    required this.textTertiary, required this.textDisabled, required this.outlineVariant,
    required this.divider, required this.accentHover,
    required this.elev1, required this.elev2, required this.elev3, required this.elev4,
    required this.glowBrand, required this.glowSuccess,
    required this.brandGradient, required this.avatarGradient,
  });

  @override AppX copyWith() => this;
  @override AppX lerp(ThemeExtension<AppX>? o, double t) => this;

  static const _gBrandLight = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2C3A86), Color(0xFF3D6FA8), Color(0xFF4A93C0)], stops: [0, .55, 1]);
  static const _gAvatarLight = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight,
    colors: [Color(0xFF2C3A86), Color(0xFF3D6FA8)]);
  static const _gBrandDark = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A2358), Color(0xFF25406A), Color(0xFF2C5C7A)], stops: [0, .6, 1]);
  static const _gAvatarDark = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight,
    colors: [Color(0xFF3D6FA8), Color(0xFF5FD0E6)]);

  static List<BoxShadow> _navy(double o1,double b1,double y1,double o2,double b2,double y2) => [
    BoxShadow(color: const Color(0xFF141B52).withOpacity(o1), blurRadius: b1, offset: Offset(0, y1)),
    BoxShadow(color: const Color(0xFF141B52).withOpacity(o2), blurRadius: b2, offset: Offset(0, y2)),
  ];
  static List<BoxShadow> _black(double o,double b,double y) =>
    [BoxShadow(color: Colors.black.withOpacity(o), blurRadius: b, offset: Offset(0, y))];

  static const light = AppX(
    success: AppColors.green, successContainer: Color(0xFFD6F2E3), onSuccessContainer: Color(0xFF04341F),
    warning: AppColors.amber, warningContainer: Color(0xFFFBE9C8), onWarningContainer: Color(0xFF3D2A00),
    info: Color(0xFF2DA3C0), infoContainer: Color(0xFFE0F7FB), onInfoContainer: Color(0xFF0C4351),
    textTertiary: Color(0xFF807C9C), textDisabled: Color(0xFFA6A2C0),
    outlineVariant: Color(0xFFDEDCEC), divider: Color(0xFFE7E5F1), accentHover: Color(0xFF2DA3C0),
    elev1: [BoxShadow(color: Color(0x0F141B52), blurRadius: 3, offset: Offset(0,1))],
    elev2: [BoxShadow(color: Color(0x12141B52), blurRadius: 10, offset: Offset(0,4))],
    elev3: [BoxShadow(color: Color(0x1F141B52), blurRadius: 28, offset: Offset(0,12))],
    elev4: [BoxShadow(color: Color(0x29141B52), blurRadius: 40, offset: Offset(0,18))],
    glowBrand: [BoxShadow(color: Color(0x471E2A6E), blurRadius: 20, offset: Offset(0,8))],
    glowSuccess: [BoxShadow(color: Color(0x2E1E9E63), blurRadius: 0, spreadRadius: 3)],
    brandGradient: _gBrandLight, avatarGradient: _gAvatarLight,
  );

  static const dark = AppX(
    success: AppColors.green400, successContainer: Color(0xFF0C3D27), onSuccessContainer: Color(0xFFA6EBC9),
    warning: AppColors.amber400, warningContainer: Color(0xFF3D2A00), onWarningContainer: Color(0xFFFFD79A),
    info: Color(0xFF5FD0E6), infoContainer: Color(0xFF134454), onInfoContainer: Color(0xFFBFF0F7),
    textTertiary: Color(0xFF8C8AA0), textDisabled: Color(0xFF5A5870),
    outlineVariant: Color(0xFF2E3140), divider: Color(0xFF242633), accentHover: Color(0xFF8FE0EF),
    elev1: [BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0,1))],
    elev2: [BoxShadow(color: Color(0x73000000), blurRadius: 6, offset: Offset(0,2))],
    elev3: [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0,8))],
    elev4: [BoxShadow(color: Color(0x99000000), blurRadius: 32, offset: Offset(0,12))],
    glowBrand: [BoxShadow(color: Color(0x80000000), blurRadius: 22, offset: Offset(0,8))],
    glowSuccess: [BoxShadow(color: Color(0x2957D89B), blurRadius: 0, spreadRadius: 3)],
    brandGradient: _gBrandDark, avatarGradient: _gAvatarDark,
  );
}

ThemeData _base(ColorScheme cs, AppX x) {
  final tt = GoogleFonts.cairoTextTheme(ThemeData(brightness: cs.brightness).textTheme)
      .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
  return ThemeData(
    useMaterial3: true, colorScheme: cs, scaffoldBackgroundColor: cs.surface,
    fontFamily: GoogleFonts.cairo().fontFamily, textTheme: tt,
    extensions: [x],
    splashFactory: InkRipple.splashFactory,
  );
}

class AppTheme {
  static ThemeData light = _base(AppColors.lightScheme, AppX.light);
  static ThemeData dark  = _base(AppColors.darkScheme,  AppX.dark);
}
