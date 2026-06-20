# Customer Visits — Flutter Build Package

> **Goal:** everything an engineer (or Claude) needs to rebuild the **Customer Visits** app
> **1:1** in Dart / Flutter, with zero guesswork. Every colour, size, radius, icon, font weight,
> screen layout and interaction is documented here and matches the live HTML prototype exactly.
>
> Brand: **Digital Harbor**. Primary navy `#1E2A6E`, accent cyan `#3FBFD9`, type **Cairo**.
> Bilingual **Arabic (RTL, primary)** + **English (LTR)**. **Light + dark** themes.

---

## 0. What this app is

A field‑sales **visit tracking** app with **two roles**:

| Role | Arabic | Does |
|---|---|---|
| **Manager** | مدير الفريق | Creates & assigns visits, monitors the team live on a map, reviews & approves/rejects completed visits, sees analytics. **Never checks in himself.** |
| **Employee** (field rep) | مندوب ميداني | Sees only the visits assigned to them, drives to the site, **checks in** (GPS captured), does the visit, **checks out**, fills a **report** (outcome + notes + photo + signature) and submits it to the manager → status becomes *pending review*. |

The core loop: **Manager creates → Employee checks in (GPS) → does visit → checks out (GPS) + report → Manager approves.**

---

## 1. How to read this package

| File | Contents |
|---|---|
| `README.md` (this) | Overview, project structure, dependencies, fonts, icons, asset list. |
| `01-foundations.md` | **Design tokens** — full colour scheme (light+dark hex), typography scale, spacing, radii, elevation/shadows, motion, **icon name map**. |
| `02-components.md` | Every **reusable widget** (Button, Card, Badge, Avatar, Chip, Input, KpiTile, VisitCard, AppBar, BottomNav, StatusPill…) with exact specs + Dart. |
| `03-screens.md` | **Per‑screen layout specs** — one section per screen, each with its screenshot, structure, measurements, and both role variants. |
| `04-flows-and-state.md` | **Visit lifecycle state machine**, role permissions, navigation graph, geofence rules, offline/sync behaviour, the 10 micro‑interactions. |
| `lib/` | **Copy‑pasteable reference Dart** — `app_colors.dart`, `app_typography.dart`, `app_dimens.dart`, `app_theme.dart`, plus key widgets. |
| `screenshots/` | 16 reference PNGs (see index below). |
| `assets/` | Brand assets to drop into the Flutter project: `logo-d.png`, `logomark.png`, `map-cairo.png`. |

> There is also a `../DESIGN_SPEC.md` at the project root — the original Material‑3 `ThemeData`
> deliverable. The token tables here supersede/extend it to match the **current** app.

---

## 2. Screenshot index

> The 16 reference PNGs render with the **real Material Symbols Rounded icons, the live map,
> and the brand logo** — they are an accurate 1:1 of the prototype (layout, colour, spacing,
> typography, iconography). Captured from both roles, light + dark. The exact Flutter icon for
> every glyph is also listed in `01-foundations.md › Iconography`.

| # | File | Screen | Role |
|---|---|---|---|
| 01 | `01-login.png` | Login + role selector | both |
| 02 | `02-dashboard.png` | Manager dashboard (greeting, KPIs, field map, activity, leaderboards) | manager |
| 03 | `03-analytics.png` | Analytics (metrics, weekly chart, per‑employee) | manager |
| 04 | `04-team-visits.png` | Team visits list (all employees) | manager |
| 05 | `05-visit-detail-manager.png` | Visit detail — **monitoring** + approve/reject bar | manager |
| 06 | `06-create-visit.png` | Create visit bottom sheet | manager |
| 07 | `07-settings.png` | Settings | both |
| 08 | `08-customers.png` | Customers list | manager |
| 09 | `09-review.png` | Review queue (approve/reject cards) | manager |
| 10 | `10-my-visits.png` | My visits + personal day header | employee |
| 11 | `11-visit-scheduled.png` | Visit detail — **scheduled** (pre check‑in) | employee |
| 12 | `12-visit-active.png` | Visit detail — **active** (after check‑in) | employee |
| 13 | `13-report-sheet.png` | Visit report sheet (outcome/notes/photo/signature) | employee |
| 14 | `14-route.png` | Today's route map (ordered stops) | employee |
| 15 | `15-dark-my-visits.png` | My visits — **dark theme** | employee |
| 16 | `16-dark-detail.png` | Visit detail — **dark theme** | both |

---

## 3. Recommended Flutter project structure

```
lib/
  main.dart
  theme/
    app_colors.dart        // ColorScheme + brand tokens (light & dark)
    app_typography.dart    // Cairo TextTheme
    app_dimens.dart        // spacing, radii, icon sizes, durations
    app_shadows.dart       // elevation BoxShadow lists
    app_theme.dart         // ThemeData.light() / .dark()
  models/
    visit.dart             // Visit + VisitStatus enum + VisitReport
    user.dart              // AppUser + UserRole enum
    customer.dart
  state/
    app_state.dart         // role, theme, lang, visits, overrides (Provider/Riverpod/Bloc)
  widgets/                 // see 02-components.md
    cv_app_bar.dart  cv_bottom_nav.dart  visit_card.dart  status_badge.dart
    cv_button.dart  kpi_tile.dart  avatar.dart  app_text_field.dart  status_pill.dart
  screens/
    login_screen.dart
    shell.dart             // role-aware Scaffold + BottomNav
    dashboard_screen.dart  analytics_screen.dart  visits_screen.dart
    visit_detail_screen.dart   // branches employee vs manager
    report_sheet.dart  create_visit_sheet.dart  review_screen.dart
    route_screen.dart  customers_screen.dart  settings_screen.dart
assets/
  images/logo-d.png  images/logomark.png  images/map-cairo.png
```

---

## 4. Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1          # Cairo
  material_symbols_icons: ^4.2785.1  # exact icon set used in the design (Rounded)
  provider: ^6.1.2              # or riverpod / bloc — any; state is simple
  geolocator: ^12.0.0           # GPS for check-in/out + geofence distance
  google_maps_flutter: ^2.6.0   # real map (prototype uses a static image)
  signature: ^5.5.0             # customer signature pad in the report sheet
  intl: ^0.19.0                 # date/number formatting, RTL

flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

### Fonts — Cairo

The single brand typeface is **Cairo** (excellent Arabic + Latin). Load via `google_fonts`:

```dart
import 'package:google_fonts/google_fonts.dart';
// textTheme: GoogleFonts.cairoTextTheme(base)   // see app_typography.dart
```

Weights used: **400** regular, **500** medium, **600** semibold, **700** bold, **800** extra‑bold.
(800 is used heavily for numbers, titles and CTAs — it is core to the look.)

### Icons — Material Symbols **Rounded**

The design uses **Material Symbols Rounded** throughout (not the classic Material Icons). Use the
`material_symbols_icons` package: `Symbols.business`, `Symbols.login`, `Symbols.call`, … Some icons
are shown **filled** (`Symbols.x` with `fill: 1`) and others outlined (`fill: 0`). The full
name→usage map with fill state is in `01-foundations.md`.

---

## 5. Global rules (apply everywhere)

- **Directionality:** wrap the app in `Directionality(textDirection: lang == ar ? rtl : ltr)`. All
  paddings/positions use **logical** edges (start/end), never hard left/right. Arabic is the default.
- **Min hit target** 48×48. **Screen edge padding** 16. **Card inner padding** 16–20. **Card radius** 20.
- **Numbers** are always `fontFeatures: [FontFeature.tabularFigures()]` and weight 800.
- **Two background layers:** app background `#F6F5FB` (light) / `#0A0B0F` (dark); cards/surfaces sit
  on `#FFFFFF` / `#0E0F15` with soft navy‑tinted shadows (light) or hairline borders (dark).
- **Status drives colour** everywhere: scheduled→navy, active→green, pending review→amber,
  approved→cyan/info, rejected→red. (Exact tokens in foundations.)
- **No emoji** except the single 👋 in the greeting headers. No gradients except the brand
  navy→cyan header/avatar gradient.

Continue to `01-foundations.md`.
