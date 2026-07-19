# Design Brief — "Customer Visits" (Digital Harbor)

> **Purpose of this file:** hand it to Claude (the design assistant) so it can redesign the
> app's UI into a polished, premium, modern product. Claude's output will be implemented
> **verbatim** by a developer, so the deliverables must be a **deterministic, reproducible
> spec** (exact tokens + Dart code), not vague prose.

---

## 1. Product context

**Customer Visits** is a Flutter field-sales app for Digital Harbor. Field employees
check in / check out at customer locations with live GPS tracking; managers oversee the
team from a dashboard. Backend is Odoo (single source of truth — the app is mostly
read + check-in/out, not a full editor).

Two roles drive the UI:
- **Field user** — single Visits screen (their queue, today by default), a persistent
  "active visit" bar at the bottom, no bottom nav.
- **Manager** — two-tab shell (Visits + Dashboard), a FAB to create visits, no persistent bar.

---

## 2. Hard constraints (MUST be respected — do not change)

- **Framework:** Flutter, **Material 3** (`useMaterial3: true`). State management is **BLoC** —
  redesign visuals only, do **not** change architecture, blocs, models, or routing.
- **Font:** **Cairo** via the `google_fonts` package (reads well in both Arabic & English).
- **Bilingual + bidirectional:** Arabic (**RTL**) + English (**LTR**). Every layout must work
  mirrored. Use **logical directions** (`start`/`end`, `EdgeInsetsDirectional`,
  `AlignmentDirectional`) — never hard-coded `left`/`right`.
- **Brand colors (keep):** primary navy `#1E2A6E`, accent cyan `#3FBFD9` (from the logo).
- **Light AND dark theme** both required.
- **No new packages / no new architecture.** Stick to Flutter Material 3 + the packages
  already in the project (listed below). Do not introduce another UI kit or design library.
- Logo assets live at `assets/images/visit-logo.png` (full logo on its navy plate) and
  `assets/images/visit-logo-mark.png` (plate-less glyph, used in the app bar + login
  header + splash, where the surface already supplies its own shape).

**Packages already available (use only these):**
`flutter_bloc`, `equatable`, `dio`, `flutter_secure_storage`, `shared_preferences`,
`geolocator`, `permission_handler`, `flutter_map` + `latlong2` (maps — OpenStreetMap tiles),
`go_router`, `get_it`, `shimmer` (skeletons), `intl`, `url_launcher`, `google_fonts`,
`sentry_flutter`.

---

## 3. Current design system (the starting point to improve)

- Material 3 `ColorScheme.fromSeed(seedColor: #1E2A6E)`, with `tertiary` forced to cyan `#3FBFD9`.
- Corner radius: a single `12.0` used almost everywhere.
- Cards: flat (elevation 0), `surfaceContainerLow` fill, 0.5px `outlineVariant` border.
- Buttons: filled/outlined/text, radius 12, padding ~14×20, weight 700.
- Inputs: filled (`surfaceContainerHighest` @ 30% alpha), 2px primary focus border.
- App bar: flat (elevation 0), centered title, circular white logo chip + title.
- Nav bar: M3 `NavigationBar`, height 64, `primaryContainer` indicator.

**The problem:** it's functional but "basic" — flat, generic Material defaults, single radius,
no depth, no visual hierarchy, no premium feel. We want it to look like a polished commercial
product: considered spacing scale, layered surfaces, tasteful elevation/shadows, richer color
roles, refined typography, micro-states, and brand presence.

---

## 4. Screen inventory (redesign all of these)

| Screen | What's on it now |
|---|---|
| **Splash** | Logo on branded background while session restores. |
| **Server Setup** | First-run form: enter/select backend server URL. |
| **Login** | Gradient brand header (logo + app title + tagline + language/theme/back actions), then a white rounded sheet overlapping the header with username + password fields and a login button. |
| **Home Shell** | Role-based scaffold. Custom app bar = circular logo chip + title + settings icon. Manager: bottom `NavigationBar` (Visits / Dashboard) + "create visit" FAB. User: no nav, persistent visit bar at bottom. |
| **Dashboard** (manager) | Scroll list of cards: (a) 2×2 **KPI grid** — Overdue / Pending review / Today / Active now, each a colored tile (icon + big number + label, tappable→filtered Visits); (b) **Active employees map** card — `flutter_map` mini-map (220px) with circular initial pins + a list of up to 3 checked-in employees; (c) **Top customers** leaderboard (rows: avatar + name + progress bar + count); (d) **Top employees** leaderboard. |
| **Visits list** | List of visit cards; filter chips (all/today, status, timing/overdue); pull-to-refresh; skeleton loading. |
| **Visit detail** | Full visit info: customer, employee, status/lifecycle, check-in/out times + locations, type, notes; actions (check in/out, review). |
| **Create Visit** | Form: pick customer, visit type, schedule/notes. |
| **Customers list** | Searchable list of customer cards. |
| **Customer detail** | Customer info + their visits, contact actions (call/map via `url_launcher`). |
| **Employees list** | List of employees (manager). |
| **Nearby Map** | Full `flutter_map` page showing nearby employees/customers as markers. |
| **Settings** | Language toggle (AR/EN), theme mode (system/light/dark), server, app version, logout. |
| **Persistent Visit Bar** | Bottom bar pinned for field users showing the currently active visit (customer + elapsed time + quick action). |

**Shared widgets that exist** (restyle these, keep their APIs): `AppButton`, `AppCard`,
`AppTextField`, `VisitCard`, `InfoRow`, `EmptyView`, `ErrorView`, `OfflineBanner`,
skeleton/shimmer loaders, `PickerBottomSheet`, `ConfirmDialog`, `AnimatedListItem`
(staggered entrance animation).

---

## 5. What I want from you (Claude) — deliverables

Design a **premium, modern, visually rich** UI for all the screens above. Make deliberate
choices about depth, hierarchy, spacing rhythm, and brand expression. Then output a
**deterministic spec** a developer can reproduce exactly. Deliver **ALL** of the following,
as markdown text + Dart code blocks (copy-pasteable):

### A. Design system — exact tokens
1. **Color palette** — every color as a **hex code**, for **light + dark**, mapped to
   Material 3 `ColorScheme` roles (primary, onPrimary, primaryContainer, secondary,
   tertiary, surface, surfaceContainer/Low/High/Highest, surfaceTint, outline,
   outlineVariant, error, success/warning if you add semantic colors). Keep navy/cyan brand.
2. **Typography scale** — for every text style (display/headline/title/body/label, all sizes):
   exact `fontSize` (sp), `fontWeight`, `letterSpacing`, `height` (line height). Cairo family.
3. **Spacing scale** — a named scale (e.g. 4/8/12/16/20/24/32/40) and which to use where.
4. **Radii** — named radius tokens (e.g. sm/md/lg/xl/pill) with exact values.
5. **Elevation / shadows** — each level with exact `blurRadius`, `offset`, color, opacity.
6. **Icon sizes** — named sizes.

### B. Component specs
For each: **buttons** (filled/outlined/text), **cards**, **text fields**, **list tiles**,
**app bar**, **bottom nav bar**, **chips / filter chips**, **badges**, **avatars**, **FAB**,
**bottom sheets**, **snackbars**, **KPI tile**, **leaderboard row**, **map pin** — give exact
dimensions, padding, radius, colors (by token), typography (by token), and every **state**
(default / pressed / focused / disabled / selected). Reference named tokens, never raw magic
numbers.

### C. Per-screen layout specs
For **every** screen in §4: describe the widget tree top-to-bottom with exact spacing and
which components/tokens each part uses. Note any RTL-specific mirroring. Note loading
(skeleton) and empty states.

### D. Flutter ThemeData (the most important deliverable)
Produce the complete **`ThemeData light()` and `ThemeData dark()`** as copy-pasteable Dart,
Material 3, Cairo via `google_fonts`, using the tokens from §A — to replace
`lib/app/theme.dart`. Include themes for AppBar, Card, Buttons, Input, NavigationBar,
ListTile, Chip, Dialog, BottomSheet, SnackBar, FAB, Divider, ProgressIndicator.
Optionally add a `ThemeExtension` for custom tokens (semantic colors, shadows, spacing)
so screens can read them type-safely.

### E. Reference widget code for hero screens
For **Login**, **Dashboard**, and **Visit detail**: give the full Flutter `build` code as a
concrete reference implementation using the new tokens/components, so the developer can match
the intended result pixel-for-pixel. (Keep widget/class names generic; the developer will wire
the real blocs/data.)

### Output rules
- Everything as **text + Dart code blocks**, nothing that requires opening an external tool.
- **No magic numbers** in code — reference the named tokens.
- Respect every constraint in §2 (Material 3, Cairo, RTL, brand colors, no new packages).
- If you propose new semantic colors (success/warning/info), define them for light + dark.

---

## 6. (Optional) extra context you can attach when sending

- Screenshots of the current screens (so Claude sees exactly what to improve).
- The current `lib/app/theme.dart` (already summarized in §3).
