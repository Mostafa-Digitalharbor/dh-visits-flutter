import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';

// Shared visual chrome for the authentication-flow screens (login + server
// setup): the full-bleed brand hero, the overlapping credential sheet, the
// placeholder-style field, the primary CTA and the secure footer. Both screens
// compose these so they stay pixel-identical — only the sheet's fields differ.

/// Component sizes of the auth chrome. Design-space dp: each is scaled at its
/// call site (`context.r` for glyph boxes, `context.fixedH` for boxes that hold
/// text).
abstract final class _AuthSz {
  /// The white tile holding the logo mark.
  static const logoTile = 84.0;
  static const logoRadius = 24.0;
  static const logoShadowBlur = 24.0;
  static const logoShadowOffset = Offset(0, 10);

  /// The glass chips in the hero's top row.
  static const chip = 34.0;

  /// The decorative glows behind the hero content, and how far they hang off
  /// its edges.
  static const glowLarge = 200.0;
  static const glowSmall = 170.0;
  static const glowLargeInset = -40.0;
  static const glowSmallBottom = -10.0;
  static const glowSmallStart = -50.0;

  /// How far the credential sheet rides up over the hero.
  static const sheetOverlap = 44.0;

  /// The sheet stops growing here, so fields keep a sane width on tablets.
  static const sheetMaxWidth = 460.0;

  /// The drag handle drawn at the top of the sheet.
  static const handleWidth = 40.0;
  static const handleHeight = 4.0;

  /// The primary CTA — taller than a standard button; it is the one action on
  /// these screens.
  static const ctaHeight = 56.0;
  static const ctaSpinnerStroke = 2.4;

  static const wordmarkTracking = -0.5;
  static const headingTracking = -0.3;
}

/// The brand veil over the hero photo — navy900 → navy700 → teal500, each
/// slightly translucent so the map shows through.
const _veilAlphas = (deep: 0.92, mid: 0.88, light: 0.82);

/// The cyan glow in the hero's top corner — strong enough to read through the
/// veil, unlike the faint white one opposite ([Alphas.wash]).
const _accentGlowAlpha = 0.45;

// ─── Frame ───────────────────────────────────────────────────────────────────

/// The scrolling frame both auth screens share: at least one viewport tall, so
/// the sheet's colour reaches the bottom on tall screens, and scrollable, so
/// the form stays reachable above the keyboard on a 320×568 phone.
class AuthScrollBody extends StatelessWidget {
  final List<Widget> children;
  const AuthScrollBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class AuthHero extends StatelessWidget {
  /// When non-null, a back chip is pinned to the visual start of the hero's
  /// top row. Login passes this to step back to the server-setup screen; the
  /// setup screen passes it only when it was pushed (from Profile), since as
  /// the entry point of the flow there is nothing behind it.
  final VoidCallback? onBack;

  const AuthHero({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    // With the keyboard up, or a phone on its side, the logo and tagline would
    // push the very field being typed into off screen. The wordmark alone
    // keeps the brand.
    final compact = context.keyboardInset > 0 || context.isLandscape;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(AppAssets.mapCairo, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1, -0.7),
                end: Alignment.bottomRight,
                colors: [
                  AppColors.navy900.withValues(alpha: _veilAlphas.deep),
                  AppColors.navy700.withValues(alpha: _veilAlphas.mid),
                  AppColors.teal500.withValues(alpha: _veilAlphas.light),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: _AuthSz.glowLargeInset,
          end: _AuthSz.glowLargeInset,
          child: _Glow(
            size: context.r(_AuthSz.glowLarge),
            color: AppColors.cyan500.withValues(alpha: _accentGlowAlpha),
          ),
        ),
        PositionedDirectional(
          bottom: _AuthSz.glowSmallBottom,
          start: _AuthSz.glowSmallStart,
          child: _Glow(
            size: context.r(_AuthSz.glowSmall),
            color: AppColors.onMap.withValues(alpha: Alphas.wash),
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            context.r(Insets.x5),
            topPad + context.rh(Insets.x3h),
            context.r(Insets.x5),
            _AuthSz.sheetOverlap + context.rh(compact ? Insets.x3 : Insets.x6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeroChips(onBack: onBack),
              if (!compact) ...[
                context.gapH(Insets.x6),
                const _LogoTile(),
              ],
              context.gapH(compact ? Insets.x1 : Insets.x3h),
              Text(
                context.s.loginTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: FontSz.wordmark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: _AuthSz.wordmarkTracking,
                  color: AppColors.onMap,
                ),
              ),
              if (!compact) ...[
                context.gapH(Insets.x1h),
                Text(
                  context.s.appTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: FontSz.base,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onMap.withValues(alpha: Alphas.scrim),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    final size = context.r(_AuthSz.logoTile);
    return Container(
      width: size,
      height: size,
      padding: context.padAll(Insets.x4),
      decoration: BoxDecoration(
        color: AppColors.onMap,
        borderRadius: BorderRadius.circular(_AuthSz.logoRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: _AuthSz.logoShadowBlur,
            offset: _AuthSz.logoShadowOffset,
          ),
        ],
        border: Border.all(color: AppColors.onMap.withValues(alpha: Alphas.soft)),
      ),
      child: Image.asset(AppAssets.logoMark, fit: BoxFit.contain),
    );
  }
}

class _HeroChips extends StatelessWidget {
  final VoidCallback? onBack;
  const _HeroChips({this.onBack});

  ThemeMode _nextThemeMode(ThemeMode current, Brightness platformBrightness) {
    final effective = current == ThemeMode.system
        ? (platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light)
        : current;
    return effective == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final glyph = context.r(IconSz.label);
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final isArabic = AppLocales.isArabic(state.locale);
        // Back chip at the start edge, the language and theme chips at the end.
        return Row(
          children: [
            if (onBack != null)
              _GlassChip(
                onTap: onBack!,
                circular: true,
                tooltip: context.s.commonBack,
                // `arrow_back` carries `matchTextDirection`, so Flutter already
                // mirrors it for Arabic — it points left in English and right
                // in Arabic without any help here.
                child: Icon(Symbols.arrow_back, size: glyph, color: AppColors.onMap),
              ),
            const Spacer(),
            _GlassChip(
              onTap: () => context.read<SettingsCubit>().setLocale(
                    isArabic ? AppLocales.english : AppLocales.arabic,
                  ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // The chip advertises the language it switches *to*, so
                    // each label is written in its own script rather than
                    // translated — see the ARB descriptions.
                    isArabic
                        ? context.s.languageCodeShortEnglish
                        : context.s.languageCodeShortArabic,
                    style: const TextStyle(
                      fontSize: FontSz.sm,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onMap,
                    ),
                  ),
                  context.gapW(Insets.x1h),
                  Icon(
                    Symbols.translate,
                    size: context.r(IconSz.xs),
                    color: AppColors.onMap,
                  ),
                ],
              ),
            ),
            context.gapW(Insets.x2),
            _GlassChip(
              onTap: () => context.read<SettingsCubit>().setThemeMode(
                    _nextThemeMode(state.themeMode, MediaQuery.platformBrightnessOf(context)),
                  ),
              circular: true,
              child: Icon(
                isDark ? Symbols.light_mode : Symbols.dark_mode,
                size: glyph,
                color: AppColors.onMap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlassChip extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool circular;

  /// Names an icon-only chip for screen readers (and on long-press). The
  /// labelled chips carry their own text and leave this null.
  final String? tooltip;

  const _GlassChip({
    required this.child,
    required this.onTap,
    this.circular = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.pill);
    final size = context.fixedH(_AuthSz.chip);
    final chip = Material(
      color: AppColors.onMap.withValues(alpha: Alphas.tint),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: size,
          width: circular ? size : null,
          padding: circular ? null : context.padSym(h: Insets.x3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.onMap.withValues(alpha: Alphas.halo)),
          ),
          child: child,
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

// ─── Overlapping credential sheet ────────────────────────────────────────────

class AuthSheet extends StatelessWidget {
  final Widget child;
  const AuthSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return Transform.translate(
      offset: const Offset(0, -_AuthSz.sheetOverlap),
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          context.r(Insets.x5),
          context.rh(Insets.x2h),
          context.r(Insets.x5),
          context.rh(Insets.x5),
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          boxShadow: x.elev3,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _AuthSz.sheetMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: _AuthSz.handleWidth,
                    height: _AuthSz.handleHeight,
                    margin: EdgeInsets.only(bottom: context.rh(Insets.x4)),
                    decoration: BoxDecoration(
                      color: x.outlineVariant,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSheetTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthSheetTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: FontSz.authHeading,
            fontWeight: FontWeight.w800,
            letterSpacing: _AuthSz.headingTracking,
            color: cs.onSurface,
          ),
        ),
        context.gapH(Insets.x1),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: FontSz.md,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Placeholder-style field ─────────────────────────────────────────────────

class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.autofillHints,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    final glyph = context.r(IconSz.sm);
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      autocorrect: !widget.isPassword,
      enableSuggestions: !widget.isPassword,
      style: const TextStyle(fontSize: FontSz.lg, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: widget.hint,
        // The hint disappears once the field has text; the error text is the
        // only other label, so let it wrap rather than cut its advice short.
        errorMaxLines: 3,
        prefixIcon: Icon(widget.icon, size: glyph, color: x.textTertiary),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Symbols.visibility : Symbols.visibility_off,
                  size: glyph,
                  color: x.textTertiary,
                ),
              )
            : null,
        contentPadding: context.padSym(h: Insets.x3h, v: Insets.x3h),
      ),
    );
  }
}

// ─── Primary CTA ─────────────────────────────────────────────────────────────

/// The hero CTA of the auth sheet. Not [AppButton]: it is taller and carries
/// the brand glow, which is this screen's design and nowhere else's.
class AuthPrimaryButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  const AuthPrimaryButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final radius = BorderRadius.circular(Radii.lg);
    final spinner = context.r(IconSz.sm);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: x.glowBrand),
      child: Material(
        color: cs.primary,
        borderRadius: radius,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: radius,
          child: SizedBox(
            height: context.fixedH(_AuthSz.ctaHeight),
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: spinner,
                      child: CircularProgressIndicator(
                        strokeWidth: _AuthSz.ctaSpinnerStroke,
                        color: cs.onPrimary,
                      ),
                    )
                  : Padding(
                      padding: context.padSym(h: Insets.x4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              size: context.r(IconSz.tile),
                              fill: 1,
                              color: cs.onPrimary),
                          context.gapW(Insets.x2),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: FontSz.lg,
                                fontWeight: FontWeight.w800,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Secure footer ───────────────────────────────────────────────────────────

class AuthSecureFooter extends StatelessWidget {
  final String text;
  final IconData icon;
  const AuthSecureFooter({super.key, required this.text, this.icon = Symbols.shield});

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: context.r(IconSz.inline), color: x.textDisabled),
        context.gapW(Insets.x1h),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: FontSz.xs, fontWeight: FontWeight.w600, color: x.textDisabled),
          ),
        ),
      ],
    );
  }
}
