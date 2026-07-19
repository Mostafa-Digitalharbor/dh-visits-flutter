# Icons render blank in release builds — REQUIRED build flag

## Symptom

In **release** builds, some icons render as **empty boxes** (blank), while others
render fine. Reported as "icons disappear when I switch light/dark mode" — but the
icons are actually missing in *both* themes; toggling the theme just makes it
noticeable. Debug builds look fine (they don't tree-shake icons).

Confirmed examples that were blank: the app-bar **settings** ⚙ and **groups** 👥
chips, the greeting-card calendar, the analytics KPI **calendar** icon, the
**trend arrows** on every analytics card, the "by employee" **bar-chart** icon,
the **System** theme option's brightness icon, and the **visits** tab nav icon.

## Root cause

The app draws its icons from [`material_symbols_icons`](https://pub.dev/packages/material_symbols_icons),
which ships **variable** icon fonts (`MaterialSymbolsOutlined/Rounded/Sharp`).
Flutter's release **icon tree-shaker** subsets those fonts down to only the used
glyphs — but the subsetter mishandles some glyphs in variable fonts and drops or
corrupts them, so those icons come out blank. Which icons break is effectively
arbitrary (it is not a color/theme problem — the tap targets still work, only the
glyph is missing).

This is a known Flutter + variable-font interaction, not a bug in our code.

## Fix — build with `--no-tree-shake-icons`

Disabling icon tree-shaking bundles the full icon fonts, so every glyph is present.

```bash
flutter build apk --release --no-tree-shake-icons
flutter build appbundle --release --no-tree-shake-icons
```

Use the wrapper scripts so nobody forgets the flag:

```bash
scripts/build_release.sh            # or: aab
powershell -File scripts/build_release.ps1     # or: aab
```

### Cost

Bundling the full icon fonts adds ~15 MB to the APK (≈65 MB → ≈80 MB). This is
acceptable for an internally-distributed field app. Do **not** drop the flag to
save size — you get blank icons instead.

> There is no `pubspec.yaml` / gradle setting that persists this; it must be on
> the `flutter build` command line. That is why the wrapper scripts exist —
> always release through them (or remember the flag).

## If the size ever becomes a problem

The only size-free alternative is to stop using the variable-font package and
migrate every `Symbols.*` usage (~88 sites) to Flutter's built-in `Icons.*`
(non-variable Material Icons, which tree-shake correctly). That changes the icon
visual style and is a large, review-heavy refactor — only pursue it if the extra
~15 MB genuinely matters.
