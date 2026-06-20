# 02 — Components

Reusable widgets, in dependency order. Specs are exact; Dart is a faithful starting point
(reads tokens from `theme/`). Reference the `../DESIGN_SPEC.md` for the original Material‑3 variants.

Convention: `cs = Theme.of(context).colorScheme`, `tt = Theme.of(context).textTheme`,
`x = Theme.of(context).extension<AppX>()!` (brand tokens not in ColorScheme — see `lib/app_theme.dart`).

---

## 1. StatusBadge

Pill that encodes a visit status. Used on cards, detail header, customer rows.

- Height 26, padding `0 11`, radius 999. `bg = tone-container`, `fg = tone`, `font label‑md/700`.
- Optional leading **icon 15** (filled) or a **dot** (8×8 circle, for `active`).
- Tones: scheduled→brand, active→success(+dot), review→warning, approved→info, rejected→error, accent (type chips)→accent.

```dart
class StatusBadge extends StatelessWidget {
  final Color fg, bg; final IconData? icon; final bool dot; final String label;
  const StatusBadge({super.key, required this.fg, required this.bg, this.icon, this.dot=false, required this.label});
  @override Widget build(BuildContext c) => Container(
    height: 26, padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (dot) Container(width:8,height:8,margin: const EdgeInsetsDirectional.only(end:6),
        decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
      if (icon!=null) Padding(padding: const EdgeInsetsDirectional.only(end:5),
        child: Icon(icon, size:15, fill:1, color: fg)),
      Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize:12.5, color: fg)),
    ]),
  );
}
```

---

## 2. CvButton (primary / tonal / outlined / text / danger)

- **Filled** (primary CTA): `bg brand`, `fg on‑brand (#fff)`, radius `lg`(20) for big CTAs / `btn`(14)
  for inline, min‑height by size (sm 40 / md 48 / lg 56–64), `glow-brand` shadow, label‑lg/800.
  Press → `scale .985` + drop shadow.
- **Tonal:** `bg brand-container`, `fg on‑brand-container`.
- **Outlined:** transparent, `1.5px` `outline-variant`, `fg text-secondary`.
- **Text:** transparent, `fg brand`.
- **Danger:** `bg error` / `fg #fff` (or `bg error-container`/`fg on-error-container` for soft).
- Optional leading icon (filled, 22–28 by size). `fullWidth` stretches.

Big field CTAs (check‑in green / check‑out red) are a specialised variant: min‑height 64, radius 20,
a moving **sheen** highlight, sub‑label under the main label, icon 28. See screen 11/12.

---

## 3. Avatar / Monogram

- Circle (people) or rounded‑square radius 14–18 (customers). Sizes xs28 sm36 md44 lg56 xl72,
  fontSize ≈ size×0.34, weight 800.
- People avatar bg `surface-high`, fg `text-secondary`; **online** → green dot bottom‑start, 2px surface border.
- Customer monogram bg = **avatar gradient**, fg `#fff`. May show `Symbols.business` instead of a letter.

---

## 4. AppTextField

- Height ~52, radius `md`(16), `bg surface`, `1.5px outline-variant` (focus → `brand`).
- Leading icon 20 `text-tertiary`; placeholder `text-tertiary 500`; text `body-md`.
- Optional trailing icon button (password eye, etc.). RTL: icon on the right.

---

## 5. FilterChip / TypeChip / OutcomeChip

- **Filter chip:** height ~36, radius 999, icon 16 + label‑md. Selected → `bg brand`/`fg on‑brand`+glow; idle → `bg surface`/`1.5px outline-variant`/`fg text-secondary`.
- **Type chip** (visit types in create sheet): same, brand when selected.
- **Outcome tile** (report): vertical, icon 26 + label, tone‑container bg + tone border when selected.

---

## 6. KpiTile (dashboard)

Spec from screenshot 02. Min‑height 116, padding 16, radius `lg`(20), `bg tone-container`,
`1px tone-ring` border. Top row: chevron (start) + tone icon (end), both 24. Bottom (end‑aligned):
**value 34/800 tone** (count‑up), label `body-md/600 text-secondary`. Tap → filtered visits.
Tones: brand/success/warning/error containers.

```dart
class KpiTile extends StatelessWidget {
  final String value; final String label; final IconData icon;
  final Color fg, bg, ring; final VoidCallback? onTap;
  const KpiTile({super.key, required this.value, required this.label, required this.icon,
    required this.fg, required this.bg, required this.ring, this.onTap});
  @override Widget build(BuildContext c) => InkWell(onTap:onTap, borderRadius: BorderRadius.circular(20),
    child: Container(constraints: const BoxConstraints(minHeight:116), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: ring)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
            Icon(Symbols.chevron_left, size:24, color: fg), Icon(icon, size:24, color: fg)]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children:[
            CountUpText(value, style: TextStyle(fontSize:34, height:1, fontWeight: FontWeight.w800, color: fg,
              fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height:6),
            Text(label, style: TextStyle(fontSize:14, fontWeight: FontWeight.w600, color: Theme.of(c).colorScheme.onSurfaceVariant)),
          ]),
        ])));
}
```

---

## 7. VisitCard ⭐ (the hero list item — screenshots 04, 10)

Role‑aware. Used in every visits list.

**Container:** `bg surface`, radius `lg`(20), padding `14 16 14 18`, `1px outline-variant` border
(active → `1px success@32%` + `glow-success`+elev‑1; else elev‑1, hover/press elev‑2 + translateY −1).
**Status accent rail:** 4px wide, full height, inline‑start, colour = status tone.

**Row 1 — identity:** monogram **46×46 radius 14** (avatar gradient, `Symbols.business` or initial;
active adds a 14px green dot top‑end) · title block: customer **16/800** (ellipsis) + meta line
(`VIS/00232` 12/600 tertiary · dot · type 12/700 accent) · trailing column: **StatusBadge** (+ a
red "خارج النطاق" badge if flagged).

**Row 2 — role line** (marginTop 13):
- **Manager:** assignee strip — `bg surface-container` radius sm, 26px people avatar + employee name
  (13/700 secondary) + (if active) `near_me` + distance.
- **Employee:** an **affordance** line (icon 18 filled + text 13/700) coloured by status:
  scheduled→`touch_app` "اضغط لبدء الزيارة" (brand) · active→`bolt` "زيارة جارية الآن" (success) ·
  review→`hourglass_top` "بانتظار مراجعة المدير" (warning) · approved→`verified` "تم اعتمادها" (success) ·
  rejected→`replay` "مرفوضة — أعد الزيارة" (error).

**Row 3 — times strip** (marginTop 13, top hairline divider, padTop 12): scheduled → `event` "الموعد"
+ time; else `login` "بدء" {arrival} → `arrow_back` → `logout` "إنهاء" {departure}. End: date + dir chevron.
Times use 13/800 tabular, labels 11/500 tertiary, icons 16.

---

## 8. CvAppBar (screens 02–10) ⭐

The redesigned bar. `bg surface`, `border-bottom 1px outline-variant`, padding `10 14`, `Row gap 12`.

- **Leading:** if `onBack` → a **40×40 action chip** with dir‑aware back arrow; else a **40×40
  gradient logo mark** (avatar gradient, radius 12, white logo via `ColorFiltered` invert, elev‑1).
- **Title block** (Expanded, start‑aligned): optional **eyebrow** (label‑sm/700 tertiary,
  uppercase, +0.3 ls — used for the role, e.g. "مدير الفريق") above the **title** (19/800,
  −0.2 ls, ellipsis).
- **Trailing:** optional **StatusPill**, then **action chips** (settings / groups / route / delete),
  each a 40×40 chip (`bg surface`, `1px outline-variant`, radius 12, elev‑1, icon 21).

```dart
class CvAppBar extends StatelessWidget {
  final String title; final String? subtitle; final VoidCallback? onBack, onSettings;
  final Widget? status; final List<Widget> actions;
  const CvAppBar({super.key, required this.title, this.subtitle, this.onBack, this.onSettings,
    this.status, this.actions = const []});
  @override Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme; final x = Theme.of(c).extension<AppX>()!;
    final rtl = Directionality.of(c) == TextDirection.rtl;
    Widget chip(IconData i, VoidCallback? on, [Color? col]) => InkWell(onTap:on, borderRadius: BorderRadius.circular(12),
      child: Container(width:40,height:40, decoration: BoxDecoration(color: cs.surface,
        borderRadius: BorderRadius.circular(12), border: Border.all(color: x.outlineVariant), boxShadow: x.elev1),
        child: Icon(i, size:21, color: col ?? cs.onSurfaceVariant)));
    return Container(
      padding: const EdgeInsets.fromLTRB(14,10,14,10),
      decoration: BoxDecoration(color: cs.surface, border: Border(bottom: BorderSide(color: x.outlineVariant))),
      child: Row(children:[
        onBack != null
          ? chip(rtl ? Symbols.arrow_forward_ios : Symbols.arrow_back_ios_new, onBack)
          : Container(width:40,height:40, decoration: BoxDecoration(gradient: x.avatarGradient,
              borderRadius: BorderRadius.circular(12), boxShadow: x.elev1),
              child: Center(child: Image.asset('assets/images/logo-d.png', width:26, height:26,
                color: Colors.white, colorBlendMode: BlendMode.srcIn))),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children:[
          if (subtitle!=null) Text(subtitle!, style: TextStyle(fontSize:11, fontWeight: FontWeight.w700,
            letterSpacing:.3, color: cs.onSurfaceVariant)),
          Text(title, maxLines:1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize:19, fontWeight: FontWeight.w800, letterSpacing:-.2, color: cs.onSurface)),
        ])),
        if (status!=null) Padding(padding: const EdgeInsetsDirectional.only(end:2), child: status!),
        for (final a in actions) Padding(padding: const EdgeInsets.only(left:2,right:2), child: a),
        if (onSettings!=null) chip(Symbols.settings, onSettings),
      ]),
    );
  }
}
```

---

## 9. CvBottomNav (sliding indicator)

`bg surface`, `border-top 1px divider`, padding `8 12`, elev‑2. A single **64×32 pill**
(`brand-container`, radius 999) is **`AnimatedPositioned`** under the active item (340 ms emphasized).
Each item: icon 24 (**filled when active**, `on-brand-container`; else `text-tertiary`) + label
12 (active 700 `brand`, else 500 `text-tertiary`). Tabs per role (see flows §3).

---

## 10. StatusPill (online / offline)

App‑bar pill, height 30, padding `0 10`, radius 999. Online → `bg success-container`/`fg success`,
a pulsing 7px dot + `cloud_done`. Offline → `bg warning-container`/`fg warning` + `cloud_off` + pending
count. Tap → toggle / open sync sheet.

---

## 11. Cards, sheets, toast

- **Card:** `bg surface`, radius `lg`(20), elev‑1, padding 16. Section header above: icon 18–20 +
  title 15/700 (brand for "times & locations"; secondary/tertiary elsewhere) + optional count chip.
- **Bottom sheet:** `bg bg`, top radius 28, drag handle 40×4 `outline-variant`, scrim `0x66`, rise
  320 ms. Header: 40px tone icon chip + 21/800 title + close chip.
- **Toast / snackbar:** floating, `bg ink (#14131C)`, `fg #fff`, radius `md`(16), padding `13 16`,
  elev‑3, leading status icon, optional **Undo** action in `cyan-300`. Bottom offset clears the nav (~96).

Continue to `03-screens.md`.
