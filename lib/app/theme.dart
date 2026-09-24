import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design/app_colors.dart';
import 'design/app_dimens.dart';
import 'design/app_typography.dart';

export 'design/app_assets.dart';
export 'design/app_colors.dart';
export 'design/app_dimens.dart';
export 'design/app_typography.dart';
export 'design/responsive.dart';

/// Semantic tokens that [ColorScheme] can't carry: status hues + containers,
/// brand-tinted elevation shadows, brand/success glows, and the two brand
/// gradients. Access via `Theme.of(context).extension<AppX>()!` or `context.x`.
@immutable
class AppX extends ThemeExtension<AppX> {
  final Color success, successContainer, onSuccessContainer;
  final Color warning, warningContainer, onWarningContainer;
  final Color info, infoContainer, onInfoContainer;
  final Color textTertiary, textDisabled, outlineVariant, divider, accentHover;
  final List<BoxShadow> elev1, elev2, elev3, elev4, glowBrand, glowSuccess;
  final Gradient brandGradient, avatarGradient;

  const AppX({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.textTertiary,
    required this.textDisabled,
    required this.outlineVariant,
    required this.divider,
    required this.accentHover,
    required this.elev1,
    required this.elev2,
    required this.elev3,
    required this.elev4,
    required this.glowBrand,
    required this.glowSuccess,
    required this.brandGradient,
    required this.avatarGradient,
  });

  @override
  AppX copyWith() => this;

  @override
  AppX lerp(ThemeExtension<AppX>? other, double t) => this;

  static const _gBrandLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2C3A86), Color(0xFF3D6FA8), Color(0xFF4A93C0)],
    stops: [0, .55, 1],
  );
  static const _gAvatarLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2C3A86), Color(0xFF3D6FA8)],
  );
  static const _gBrandDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2358), Color(0xFF25406A), Color(0xFF2C5C7A)],
    stops: [0, .6, 1],
  );
  static const _gAvatarDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D6FA8), Color(0xFF5FD0E6)],
  );

  static const light = AppX(
    success: AppColors.green,
    successContainer: Color(0xFFD6F2E3),
    onSuccessContainer: Color(0xFF04341F),
    warning: AppColors.amber,
    warningContainer: Color(0xFFFBE9C8),
    onWarningContainer: Color(0xFF3D2A00),
    info: Color(0xFF2DA3C0),
    infoContainer: Color(0xFFE0F7FB),
    onInfoContainer: Color(0xFF0C4351),
    textTertiary: Color(0xFF807C9C),
    textDisabled: Color(0xFFA6A2C0),
    outlineVariant: Color(0xFFDEDCEC),
    divider: Color(0xFFE7E5F1),
    accentHover: Color(0xFF2DA3C0),
    elev1: [
      BoxShadow(color: Color(0x0F141B52), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0D141B52), blurRadius: 2, offset: Offset(0, 1)),
    ],
    elev2: [
      BoxShadow(color: Color(0x12141B52), blurRadius: 10, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x0F141B52), blurRadius: 4, offset: Offset(0, 2)),
    ],
    elev3: [BoxShadow(color: Color(0x1F141B52), blurRadius: 28, offset: Offset(0, 12))],
    elev4: [BoxShadow(color: Color(0x29141B52), blurRadius: 40, offset: Offset(0, 18))],
    glowBrand: [BoxShadow(color: Color(0x471E2A6E), blurRadius: 20, offset: Offset(0, 8))],
    glowSuccess: [BoxShadow(color: Color(0x2E1E9E63), blurRadius: 0, spreadRadius: 3)],
    brandGradient: _gBrandLight,
    avatarGradient: _gAvatarLight,
  );

  static const dark = AppX(
    success: AppColors.green400,
    successContainer: Color(0xFF0C3D27),
    onSuccessContainer: Color(0xFFA6EBC9),
    warning: AppColors.amber400,
    warningContainer: Color(0xFF3D2A00),
    onWarningContainer: Color(0xFFFFD79A),
    info: Color(0xFF5FD0E6),
    infoContainer: Color(0xFF134454),
    onInfoContainer: Color(0xFFBFF0F7),
    textTertiary: Color(0xFF8C8AA0),
    textDisabled: Color(0xFF5A5870),
    outlineVariant: Color(0xFF2E3140),
    divider: Color(0xFF242633),
    accentHover: Color(0xFF8FE0EF),
    elev1: [BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1))],
    elev2: [BoxShadow(color: Color(0x73000000), blurRadius: 6, offset: Offset(0, 2))],
    elev3: [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, 8))],
    elev4: [BoxShadow(color: Color(0x99000000), blurRadius: 32, offset: Offset(0, 12))],
    glowBrand: [BoxShadow(color: Color(0x80000000), blurRadius: 22, offset: Offset(0, 8))],
    glowSuccess: [BoxShadow(color: Color(0x2957D89B), blurRadius: 0, spreadRadius: 3)],
    brandGradient: _gBrandDark,
    avatarGradient: _gAvatarDark,
  );
}

/// Convenience accessor for the [AppX] semantic tokens.
extension AppXContext on BuildContext {
  AppX get x => Theme.of(this).extension<AppX>()!;
}

class AppTheme {
  AppTheme._();

  /// 15 — a text field's vertical padding. With the 16dp body text and its
  /// line height, it makes a field about as tall as a [CompSz.buttonHeight]
  /// button.
  static const double _inputPadV = 15;

  // Built once, on first use. `MaterialApp.router(theme: …, darkTheme: …)` sits
  // inside a `BlocBuilder<SettingsCubit>`, so these were re-running on every
  // settings emit — and `_build` is not cheap: a full `ThemeData` fills in
  // dozens of component defaults, and `buildCairoTextTheme` resolves a
  // google_fonts family for all 15 text styles. Both are pure functions of
  // compile-time constants, so caching them is behaviour-preserving.
  static ThemeData? _light;
  static ThemeData? _dark;

  static ThemeData light() =>
      _light ??= _build(AppColors.lightScheme, AppX.light);
  static ThemeData dark() => _dark ??= _build(AppColors.darkScheme, AppX.dark);

  static ThemeData _build(ColorScheme scheme, AppX x) {
    final brightness = scheme.brightness;
    final isLight = brightness == Brightness.light;
    final textTheme = buildCairoTextTheme(brightness, scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: textTheme,
      extensions: [x],
      splashFactory: InkRipple.splashFactory,
      // ── App bar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.appBarTitle.copyWith(color: scheme.onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: scheme.surface,
          systemNavigationBarIconBrightness:
              isLight ? Brightness.dark : Brightness.light,
        ),
      ),
      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: x.outlineVariant, width: CompSz.hairline),
        ),
      ),
      // ── Inputs ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        hintStyle: AppType.bodyMd.copyWith(color: x.textTertiary),
        prefixIconColor: x.textTertiary,
        suffixIconColor: x.textTertiary,
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.x4, vertical: _inputPadV),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: x.outlineVariant, width: CompSz.outlineWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: x.outlineVariant, width: CompSz.outlineWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: CompSz.outlineWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: CompSz.outlineWidth),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: CompSz.outlineWidth),
        ),
      ),
      // ── Buttons ──────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, CompSz.buttonHeight),
          padding: const EdgeInsets.symmetric(vertical: Insets.x3h, horizontal: Insets.x5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.btn)),
          textStyle: AppType.button.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(0, CompSz.buttonHeight),
          padding: const EdgeInsets.symmetric(vertical: Insets.x3h, horizontal: Insets.x5),
          side: BorderSide(color: x.outlineVariant, width: CompSz.outlineWidth),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.btn)),
          textStyle: AppType.button.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(vertical: Insets.x3, horizontal: Insets.x4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.btn)),
          textStyle: AppType.button,
        ),
      ),
      // ── Bottom navigation ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: CompSz.navBarHeight,
        // Pin the icon color to the design tokens (mirrors labelTextStyle).
        // Without this the unselected icon color is unspecified and collapses
        // into the nav background, so only the *selected* destination's icon
        // was visible (dashboard showed only when active; analytics never).
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: IconSz.md,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : x.textTertiary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppType.labelMd.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : x.textTertiary,
          ),
        ),
      ),
      // ── List tiles ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      // ── Dividers ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: x.divider, thickness: CompSz.hairline, space: CompSz.hairline),
      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: AppType.button.copyWith(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      ),
      // ── Bottom sheets / dialogs ──────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      ),
      // ── Snackbar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppType.bodyMd.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      // ── Misc ─────────────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        side: BorderSide(color: x.outlineVariant, width: CompSz.outlineWidth),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
        labelStyle: AppType.labelMd.copyWith(color: scheme.onSurfaceVariant),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
