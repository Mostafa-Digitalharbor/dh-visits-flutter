import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/constants/app_locales.dart';
import 'package:location_gps/core/settings/settings_cubit.dart';
import 'package:location_gps/core/settings/settings_repository.dart';
import 'package:location_gps/features/auth/view/auth_chrome.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/widget_harness.dart';

const _longSubtitle =
    'أدخل بريدك الإلكتروني أو اسم المستخدم وكلمة المرور الخاصين بحسابك في '
    'نظام أودو لدى شركتك للمتابعة إلى الزيارات الميدانية';

late SettingsCubit _settings;

Widget _withSettings(Widget child) =>
    BlocProvider<SettingsCubit>.value(value: _settings, child: child);

/// The whole auth composition, as the login screen builds it.
Widget _authScreen(
  Surface s, {
  VoidCallback? onBack,
  bool loading = false,
}) {
  final t = l10n(s.locale);
  return _withSettings(
    AuthScrollBody(
      children: [
        AuthHero(onBack: onBack),
        AuthSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthSheetTitle(
                title: '${t.loginTitle} ${LongText.of(s)}',
                subtitle: _longSubtitle,
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: TextEditingController(text: LongText.of(s)),
                hint: t.loginPassword,
                icon: Symbols.person,
                validator: (_) => LongText.of(s),
              ),
              const SizedBox(height: 12),
              AuthField(
                controller: TextEditingController(),
                hint: t.loginPassword,
                icon: Symbols.lock,
                isPassword: true,
              ),
              const SizedBox(height: 16),
              AuthPrimaryButton(
                key: const Key('cta'),
                loading: loading,
                onPressed: () {},
                icon: Symbols.login,
                label: '${t.loginSubmit} ${LongText.of(s)}',
              ),
              const SizedBox(height: 12),
              AuthSecureFooter(text: '$_longSubtitle ${LongText.of(s)}'),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The glass chip wrapping [child]: the nearest [InkWell] above it.
Finder _chipOf(Finder child) =>
    find.ancestor(of: child, matching: find.byType(InkWell)).first;

void main() {
  setUpAll(initHarness);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    _settings = SettingsCubit(repository: SettingsRepository(prefs: prefs));
  });

  tearDown(() => _settings.close());

  group('auth screen layout', () {
    testOnEverySurface(
      'hero with a back chip, sheet, two fields, CTA and footer fit',
      (s) => _authScreen(s, onBack: () {}),
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.byTooltip(t.commonBack), findsOneWidget);
        // Portrait shows the logo tile and the tagline; landscape drops both.
        final landscape = s.size.width > s.size.height;
        expect(find.text(t.appTagline), landscape ? findsNothing : findsOneWidget);
        expect(find.byType(Image), findsNWidgets(landscape ? 1 : 2));
        // The CTA and the footer are reachable by scrolling.
        await tester.ensureVisible(find.byKey(const Key('cta')));
        await tester.pump();
        await tester.ensureVisible(find.byType(AuthSecureFooter));
        await tester.pump();
      },
    );

    testOnEverySurface(
      'the entry-point variant without a back chip, loading',
      (s) => _authScreen(s, loading: true),
      verify: (tester, s) async {
        expect(find.byTooltip(l10n(s.locale).commonBack), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
        'keyboard open on 320×568: compact hero, the CTA reachable above it',
        (tester) async {
      const keyboard = 260.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      final s = surfaces[1]; // small phone · en · 1.25x
      final t = l10n(s.locale);
      await pumpSurface(tester, s, _authScreen(s, onBack: () {}));
      expectCleanLayout(tester);

      // The logo tile and the tagline give way to the field being typed into.
      expect(find.text(t.appTagline), findsNothing);
      expect(find.byType(Image), findsOneWidget, reason: 'only the backdrop');
      expect(find.text(t.loginTitle), findsOneWidget, reason: 'wordmark kept');

      await tester.ensureVisible(find.byKey(const Key('cta')));
      await tester.pump();
      final cta = tester.getRect(find.byKey(const Key('cta')));
      expect(cta.bottom, lessThanOrEqualTo(s.size.height - keyboard));
      expectCleanLayout(tester);
    });

    testWidgets('closing the keyboard brings the logo and tagline back',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await pumpSurface(tester, phoneEn, _authScreen(phoneEn));
      expect(find.text(l10n(english).appTagline), findsNothing);

      tester.view.resetViewInsets();
      await tester.pump();
      expect(find.text(l10n(english).appTagline), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
      expectCleanLayout(tester);
    });
  });

  group('AuthHero chips', () {
    testWidgets('back fires once and names itself', (tester) async {
      var backs = 0;
      await pumpSurface(
        tester,
        phoneAr,
        _withSettings(AuthHero(onBack: () => backs++)),
      );
      final back = find.byTooltip(l10n(arabic).commonBack);
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('the back chip sits at the start edge in both languages',
        (tester) async {
      Future<(double, double)> xs(Surface s) async {
        await pumpSurface(tester, s, _withSettings(AuthHero(onBack: () {})));
        final back = tester.getCenter(find.byTooltip(l10n(s.locale).commonBack));
        final theme = tester.getCenter(find.byTooltip(
            l10n(s.locale).authSwitchToDarkTheme));
        return (back.dx, theme.dx);
      }

      final (enBack, enTheme) = await xs(phoneEn);
      expect(enBack, lessThan(enTheme));
      final (arBack, arTheme) = await xs(phoneAr);
      expect(arBack, greaterThan(arTheme));
    });

    testWidgets('the back arrow mirrors itself in Arabic', (tester) async {
      await pumpSurface(tester, phoneAr, _withSettings(AuthHero(onBack: () {})));
      final arrow = tester.widget<Icon>(find.byIcon(Symbols.arrow_back));
      expect(arrow.icon!.matchTextDirection, isTrue);
      expect(
        Directionality.of(tester.element(find.byIcon(Symbols.arrow_back))),
        TextDirection.rtl,
      );
    });

    testWidgets('the chips are sized for the text scale', (tester) async {
      await pumpSurface(
        tester,
        surfaces[1],
        _withSettings(AuthHero(onBack: () {})),
      );
      final chip = tester.getSize(
          _chipOf(find.byIcon(Symbols.arrow_back)));
      // Design size 34dp grown with the 1.25x text scale (see _AuthSz.chip).
      // Below the 48dp guideline by design — documented on the chip.
      expect(chip.height, 34 * 1.25);
      expect(chip.width, chip.height, reason: 'a circle');
    });

    testWidgets('the theme chip is named and flips light → dark → light',
        (tester) async {
      await pumpSurface(tester, phoneEn, _withSettings(const AuthHero()));
      final t = l10n(english);
      final toDark = find.byTooltip(t.authSwitchToDarkTheme);
      expect(toDark, findsOneWidget);
      expect(find.byIcon(Symbols.dark_mode), findsOneWidget);

      // Settings start on "system" and the platform is light: dark next.
      expect(_settings.state.themeMode, ThemeMode.system);
      await tester.tap(toDark);
      await tester.pump();
      expect(_settings.state.themeMode, ThemeMode.dark);

      // The app here doesn't follow the cubit, so the page is still light;
      // the next tap reads the stored mode and goes back to light.
      await tester.tap(toDark);
      await tester.pump();
      expect(_settings.state.themeMode, ThemeMode.light);
    });

    testWidgets('in dark mode the theme chip offers light', (tester) async {
      await pumpSurface(
        tester,
        const Surface('dark', size: Size(390, 844), locale: arabic,
            brightness: Brightness.dark),
        _withSettings(const AuthHero()),
      );
      expect(find.byTooltip(l10n(arabic).authSwitchToLightTheme),
          findsOneWidget);
      expect(find.byIcon(Symbols.light_mode), findsOneWidget);
    });

    testWidgets('the language chip names the language it switches to',
        (tester) async {
      await _settings.setLocale(AppLocales.english);
      await pumpSurface(tester, phoneEn, _withSettings(const AuthHero()));
      final t = l10n(english);
      expect(find.text(t.languageCodeShortArabic), findsOneWidget);

      await tester.tap(find.text(t.languageCodeShortArabic));
      await tester.pump();
      expect(_settings.state.locale, AppLocales.arabic);
      expect(find.text(t.languageCodeShortEnglish), findsOneWidget);

      await tester.tap(find.text(t.languageCodeShortEnglish));
      await tester.pump();
      expect(_settings.state.locale, AppLocales.english);
    });

    testWidgets('the wordmark and tagline are localized, one-line wordmark',
        (tester) async {
      await pumpSurface(tester, phoneAr, _withSettings(const AuthHero()));
      final t = l10n(arabic);
      final wordmark = tester.widget<Text>(find.text(t.loginTitle));
      expect(wordmark.maxLines, 1);
      expect(wordmark.overflow, TextOverflow.ellipsis);
      expect(wordmark.style?.color, AppColors.onMap);
      expect(find.text(t.appTagline), findsOneWidget);
    });
  });

  group('AuthField', () {
    Future<TextEditingController> pumpField(
      WidgetTester tester, {
      bool isPassword = false,
      String? Function(String?)? validator,
      ValueChanged<String>? onSubmitted,
      ValueChanged<String>? onChanged,
      List<TextInputFormatter>? formatters,
      GlobalKey<FormState>? formKey,
      Surface surface = phoneEn,
      TextInputAction action = TextInputAction.next,
    }) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpSurface(
        tester,
        surface,
        Form(
          key: formKey,
          child: AuthField(
            controller: controller,
            hint: 'Email',
            icon: Symbols.mail,
            isPassword: isPassword,
            validator: validator,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            inputFormatters: formatters,
            keyboardType: TextInputType.emailAddress,
            textInputAction: action,
            autofillHints: const [AutofillHints.email],
          ),
        ),
      );
      return controller;
    }

    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    testWidgets('shows its hint and icon and passes the keyboard setup',
        (tester) async {
      await pumpField(tester);
      expect(find.text('Email'), findsOneWidget);
      expect(find.byIcon(Symbols.mail), findsOneWidget);
      final f = field(tester);
      expect(f.obscureText, isFalse);
      expect(f.autocorrect, isTrue);
      expect(f.keyboardType, TextInputType.emailAddress);
      expect(f.textInputAction, TextInputAction.next);
      expect(f.autofillHints, [AutofillHints.email]);
      expect(find.byType(IconButton), findsNothing,
          reason: 'only a password has a reveal toggle');
      final context = tester.element(find.byType(AuthField));
      expect(tester.widget<Icon>(find.byIcon(Symbols.mail)).color,
          context.x.textTertiary);
    });

    testWidgets('a password starts hidden and the eye toggles it',
        (tester) async {
      await pumpField(tester, isPassword: true);
      final t = l10n(english);
      var f = field(tester);
      expect(f.obscureText, isTrue);
      expect(f.autocorrect, isFalse);
      expect(f.enableSuggestions, isFalse);
      expect(find.byIcon(Symbols.visibility), findsOneWidget);
      expect(find.byTooltip(t.authShowPassword), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      f = field(tester);
      expect(f.obscureText, isFalse);
      expect(find.byIcon(Symbols.visibility_off), findsOneWidget);
      expect(find.byTooltip(t.authHidePassword), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(field(tester).obscureText, isTrue);
    });

    testWidgets('the reveal toggle is a full tap target and named in Arabic',
        (tester) async {
      await pumpField(tester, isPassword: true, surface: phoneAr);
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(find.byTooltip(l10n(arabic).authShowPassword), findsOneWidget);
    });

    testWidgets('the validator message shows and wraps up to three lines',
        (tester) async {
      final key = GlobalKey<FormState>();
      await pumpField(
        tester,
        formKey: key,
        surface: surfaces[0],
        validator: (v) => (v ?? '').isEmpty ? _longSubtitle * 2 : null,
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text(_longSubtitle * 2), findsOneWidget);
      expect(
        tester
            .widget<InputDecorator>(find.byType(InputDecorator))
            .decoration
            .errorMaxLines,
        3,
      );
      expectCleanLayout(tester);

      await tester.enterText(find.byType(TextField), 'rep@test.com');
      expect(key.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text(_longSubtitle * 2), findsNothing);
    });

    testWidgets('onChanged fires per edit and onSubmitted once',
        (tester) async {
      final changes = <String>[];
      final submits = <String>[];
      await pumpField(
        tester,
        onChanged: changes.add,
        onSubmitted: submits.add,
        action: TextInputAction.done,
      );
      await tester.enterText(find.byType(TextField), 'a');
      await tester.enterText(find.byType(TextField), 'ab');
      expect(changes, ['a', 'ab']);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submits, ['ab']);
    });

    testWidgets('input formatters are applied', (tester) async {
      final controller = await pumpField(
        tester,
        formatters: [FilteringTextInputFormatter.digitsOnly],
      );
      await tester.enterText(find.byType(TextField), 'a1b2c3');
      expect(controller.text, '123');
    });
  });

  group('AuthPrimaryButton', () {
    Future<void> pumpButton(
      WidgetTester tester, {
      required bool loading,
      required VoidCallback onPressed,
      Surface surface = phoneEn,
      String label = 'Sign in',
    }) =>
        pumpSurface(
          tester,
          surface,
          Padding(
            padding: const EdgeInsets.all(16),
            child: AuthPrimaryButton(
              loading: loading,
              onPressed: onPressed,
              icon: Symbols.login,
              label: label,
            ),
          ),
        );

    testWidgets('fires once per tap', (tester) async {
      var taps = 0;
      await pumpButton(tester, loading: false, onPressed: () => taps++);
      await tester.tap(find.byType(AuthPrimaryButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('loading shows a spinner, hides the label, ignores taps',
        (tester) async {
      var taps = 0;
      await pumpButton(tester, loading: true, onPressed: () => taps++);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
      await tester.tap(find.byType(AuthPrimaryButton));
      await tester.pump();
      expect(taps, 0);
      final context = tester.element(find.byType(AuthPrimaryButton));
      expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .color,
        Theme.of(context).colorScheme.onPrimary,
      );
    });

    testWidgets('is primary-filled and at least 56dp tall, growing with text',
        (tester) async {
      await pumpButton(tester, loading: false, onPressed: () {});
      final context = tester.element(find.byType(AuthPrimaryButton));
      final material = tester.widget<Material>(find
          .descendant(
              of: find.byType(AuthPrimaryButton),
              matching: find.byType(Material))
          .first);
      expect(material.color, Theme.of(context).colorScheme.primary);
      expect(tester.getSize(find.byType(AuthPrimaryButton)).height, 56);
      final glow = tester.widget<DecoratedBox>(find
          .descendant(
              of: find.byType(AuthPrimaryButton),
              matching: find.byType(DecoratedBox))
          .first);
      expect((glow.decoration as BoxDecoration).boxShadow,
          context.x.glowBrand);

      await pumpButton(tester,
          loading: false, onPressed: () {}, surface: surfaces[1]);
      expect(tester.getSize(find.byType(AuthPrimaryButton)).height, 56 * 1.25);
    });

    testWidgets('a long label stays one ellipsized line', (tester) async {
      await pumpButton(
        tester,
        loading: false,
        onPressed: () {},
        surface: surfaces[0],
        label: LongText.arabicCompany,
      );
      final text = tester.widget<Text>(find.text(LongText.arabicCompany));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expectCleanLayout(tester);
    });
  });

  group('AuthSheet and its title', () {
    testWidgets('the sheet rides up over the hero and caps its width',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[3], // tablet
        const Column(
          children: [
            SizedBox(height: 100),
            AuthSheet(child: SizedBox(key: Key('body'), height: 40)),
          ],
        ),
      );
      final transform =
          tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.getTranslation().y, -44);
      expect(tester.getSize(find.byKey(const Key('body'))).width, 460);
      final context = tester.element(find.byType(AuthSheet));
      final sheet = tester.widget<Container>(find
          .descendant(
              of: find.byType(AuthSheet), matching: find.byType(Container))
          .first);
      expect((sheet.decoration! as BoxDecoration).color,
          Theme.of(context).colorScheme.surfaceContainerLowest);
    });

    testWidgets('the sheet body spans a phone', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AuthSheet(child: SizedBox(key: Key('body'), height: 40)),
      );
      expect(tester.getSize(find.byKey(const Key('body'))).width,
          lessThan(phoneEn.size.width));
      expect(tester.getSize(find.byKey(const Key('body'))).width,
          greaterThan(300));
    });

    testWidgets('the title pair uses the surface ink colours', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        const AuthSheetTitle(title: 'مرحباً', subtitle: _longSubtitle),
      );
      final context = tester.element(find.byType(AuthSheetTitle));
      final cs = Theme.of(context).colorScheme;
      expect(tester.widget<Text>(find.text('مرحباً')).style?.color,
          cs.onSurface);
      expect(tester.widget<Text>(find.text(_longSubtitle)).style?.color,
          cs.onSurfaceVariant);
    });
  });

  group('AuthSecureFooter', () {
    testWidgets('defaults to the shield, two ellipsized centred lines',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        const AuthSecureFooter(text: '$_longSubtitle $_longSubtitle'),
      );
      expect(find.byIcon(Symbols.shield), findsOneWidget);
      final text =
          tester.widget<Text>(find.text('$_longSubtitle $_longSubtitle'));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.textAlign, TextAlign.center);
      final context = tester.element(find.byType(AuthSecureFooter));
      expect(text.style?.color, context.x.textDisabled);
      expectCleanLayout(tester);
    });

    testWidgets('takes a custom icon and an empty text', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AuthSecureFooter(text: '', icon: Symbols.lock),
      );
      expect(find.byIcon(Symbols.lock), findsOneWidget);
      expect(find.byIcon(Symbols.shield), findsNothing);
      expectCleanLayout(tester);
    });
  });

  group('AuthScrollBody', () {
    testWidgets('fills at least the viewport with short content',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AuthScrollBody(children: [SizedBox(key: Key('a'), height: 50)]),
      );
      final column = tester.getSize(find
          .descendant(
              of: find.byType(AuthScrollBody), matching: find.byType(Column))
          .first);
      expect(column.height, phoneEn.size.height);
      // Children stretch across.
      expect(tester.getSize(find.byKey(const Key('a'))).width,
          phoneEn.size.width);
    });

    testWidgets('scrolls long content and dismisses the keyboard on drag',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AuthScrollBody(children: [
          SizedBox(height: 2000),
          SizedBox(key: Key('last'), height: 50),
        ]),
      );
      final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView));
      expect(scroll.keyboardDismissBehavior,
          ScrollViewKeyboardDismissBehavior.onDrag);
      Rect last() => tester.getRect(find.byKey(const Key('last')));
      expect(last().top, greaterThanOrEqualTo(phoneEn.size.height));
      await tester.drag(find.byType(AuthScrollBody), const Offset(0, -3000));
      // Nothing animates forever here, so settling is safe.
      await tester.pumpAndSettle();
      expect(last().bottom, lessThanOrEqualTo(phoneEn.size.height));
      expect(last().top, greaterThanOrEqualTo(0));
      expectCleanLayout(tester);
    });
  });
}
