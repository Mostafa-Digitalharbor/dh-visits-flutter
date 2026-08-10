import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';

/// Shared visual chrome for the authentication-flow screens (login + server
/// setup): the full-bleed brand hero, the overlapping credential sheet, the
/// placeholder-style field, the primary CTA and the secure footer. Both screens
/// compose these so they stay pixel-identical — only the sheet's fields differ.

// ─── Hero ────────────────────────────────────────────────────────────────────

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(AppAssets.mapCairo, fit: BoxFit.cover),
        ),
        // Brand gradient veil — 155deg navy900@92 → brand@88 → cyan600@82.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1, -0.7),
                end: const Alignment(1, 1),
                colors: [
                  AppColors.navy900.withValues(alpha: 0.92),
                  AppColors.navy700.withValues(alpha: 0.88),
                  AppColors.teal500.withValues(alpha: 0.82),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -40,
          child: _Glow(size: 200, color: AppColors.cyan500.withValues(alpha: 0.45)),
        ),
        Positioned(
          bottom: -10,
          left: -50,
          child: _Glow(size: 170, color: Colors.white.withValues(alpha: 0.18)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, topPad + 14, 22, 70),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _HeroChips(),
              const SizedBox(height: 26),
              const _LogoTile(),
              const SizedBox(height: 14),
              Text(
                context.s.loginTitle,
                style: const TextStyle(
                  fontSize: FontSz.wordmark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.s.appTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: FontSz.base,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
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
    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowMedium, blurRadius: 24, offset: Offset(0, 10)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
      ),
      child: Image.asset(AppAssets.logoMark, fit: BoxFit.contain),
    );
  }
}

class _HeroChips extends StatelessWidget {
  const _HeroChips();

  ThemeMode _nextThemeMode(ThemeMode current, Brightness platformBrightness) {
    final effective = current == ThemeMode.system
        ? (platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light)
        : current;
    return effective == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final isArabic = state.locale.languageCode == 'ar';
        // Pinned to the visual left: theme toggle leftmost, then language.
        return Row(
          children: [
            const Spacer(),
            _GlassChip(
              onTap: () =>
                  context.read<SettingsCubit>().setLocale(Locale(isArabic ? 'en' : 'ar')),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'EN' : 'ع',
                    style: const TextStyle(
                      fontSize: FontSz.sm,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Symbols.translate, size: 16, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _GlassChip(
              onTap: () => context.read<SettingsCubit>().setThemeMode(
                    _nextThemeMode(state.themeMode, MediaQuery.platformBrightnessOf(context)),
                  ),
              circular: true,
              child: Icon(
                isDark ? Symbols.light_mode : Symbols.dark_mode,
                size: 18,
                color: Colors.white,
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
  const _GlassChip({required this.child, required this.onTap, this.circular = false});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.pill);
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 34,
          width: circular ? 34 : null,
          padding: circular ? null : const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
          ),
          child: child,
        ),
      ),
    );
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
      offset: const Offset(0, -44),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          boxShadow: x.elev3,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
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
            letterSpacing: -0.3,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
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
  final List<TextInputFormatter>? inputFormatters;

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
    this.inputFormatters,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      style: const TextStyle(fontSize: FontSz.lg, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(widget.icon, size: 20, color: x.textTertiary),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Symbols.visibility : Symbols.visibility_off,
                  size: 20,
                  color: x.textTertiary,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
    );
  }
}

// ─── Primary CTA ─────────────────────────────────────────────────────────────

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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: x.glowBrand,
      ),
      child: Material(
        color: cs.primary,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: SizedBox(
            height: 56,
            child: Center(
              child: loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.onPrimary),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22, fill: 1, color: cs.onPrimary),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: FontSz.lg,
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimary,
                          ),
                        ),
                      ],
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
        Icon(icon, size: 14, color: x.textDisabled),
        const SizedBox(width: 6),
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
