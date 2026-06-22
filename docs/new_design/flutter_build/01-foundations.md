# 01 — Foundations (Design Tokens)

All values are **exact**. px in CSS == logical px (dp) in Flutter == sp for text. Copy the Dart
equivalents from `lib/app_colors.dart`, `lib/app_typography.dart`, `lib/app_dimens.dart`.

---

## 1. Colour

### 1.1 Brand ramps (raw)

| Navy | Hex | Cyan | Hex | Neutral (slate) | Hex |
|---|---|---|---|---|---|
| navy‑50 | `#EEF0FA` | cyan‑50 | `#F0FBFD` | slate‑50 | `#F6F5FB` |
| navy‑100 | `#DDE1F5` | cyan‑100 | `#E0F7FB` | slate‑100 | `#EEEDF6` |
| navy‑200 | `#BAC0E6` | cyan‑200 | `#BFF0F7` | slate‑150 | `#E7E5F1` |
| navy‑300 | `#8C95CE` | cyan‑300 | `#8FE0EF` | slate‑200 | `#DEDCEC` |
| navy‑400 | `#5A66B0` | cyan‑400 | `#5FD0E6` | slate‑300 | `#C8C5DD` |
| navy‑500 | `#3D4D9E` | cyan‑500 ★ | `#3FBFD9` | slate‑400 | `#A6A2C0` |
| navy‑600 | `#2C3A86` | cyan‑600 | `#2DA3C0` | slate‑500 | `#807C9C` |
| navy‑700 ★ | `#1E2A6E` | cyan‑700 | `#1E859F` | slate‑600 | `#5E5A79` |
| navy‑800 | `#141B52` | cyan‑800 | `#155F73` | slate‑700 | `#423F58` |
| navy‑900 | `#0B1240` | | | slate‑800 | `#2A2839` |
| | | | | slate‑900 | `#1A1925` |
| | | | | ink | `#14131C` |

Semantic hues: **green** `#1E9E63` (c:`#D6F2E3` on:`#04341F` light‑on‑dark:`#57D89B`) ·
**amber** `#E8910C` (c:`#FBE9C8` on:`#3D2A00` alt:`#FFB955`) ·
**red** `#C8364B` (c:`#FBDCE0` on:`#410008` alt:`#FF8A93`).

### 1.2 Semantic aliases — **LIGHT**

| Token | Hex | Token | Hex |
|---|---|---|---|
| bg | `#F6F5FB` | text‑primary | `#14131C` |
| surface | `#FFFFFF` | text‑secondary | `#5E5A79` |
| surface‑low | `#FBFAFE` | text‑tertiary | `#807C9C` |
| surface‑container | `#F2F1F8` | text‑disabled | `#A6A2C0` |
| surface‑high | `#ECEAF4` | text‑on‑brand | `#FFFFFF` |
| surface‑highest | `#E6E4F0` | text‑on‑accent | `#04323B` |
| brand | `#1E2A6E` | brand‑hover | `#141B52` |
| brand‑pressed | `#0B1240` | brand‑container | `#DDE1F5` |
| on‑brand‑container | `#0B1240` | accent | `#3FBFD9` |
| accent‑hover | `#2DA3C0` | accent‑container | `#E0F7FB` |
| on‑accent‑container | `#0C4351` | outline | `#B5B2C9` |
| outline‑variant | `#DEDCEC` | divider | `#E7E5F1` |
| success | `#1E9E63` | success‑container | `#D6F2E3` |
| on‑success‑container | `#04341F` | warning | `#E8910C` |
| warning‑container | `#FBE9C8` | on‑warning‑container | `#3D2A00` |
| error | `#C8364B` | error‑container | `#FBDCE0` |
| on‑error‑container | `#410008` | info | `#2DA3C0` |
| info‑container | `#E0F7FB` | on‑info‑container | `#0C4351` |
| scrim | `rgba(11,18,64,.40)` | | |

### 1.3 Semantic aliases — **DARK**

| Token | Hex | Token | Hex |
|---|---|---|---|
| bg | `#0A0B0F` | text‑primary | `#ECECF4` |
| surface | `#0E0F15` | text‑secondary | `#B7B6C8` |
| surface‑low | `#131420` | text‑tertiary | `#8C8AA0` |
| surface‑container | `#181A26` | text‑disabled | `#5A5870` |
| surface‑high | `#1F2230` | text‑on‑brand | `#0B1240` |
| surface‑highest | `#272A3A` | text‑on‑accent | `#04323B` |
| brand | `#8C95CE` | brand‑container | `#28306B` |
| on‑brand‑container | `#DDE1F5` | accent | `#5FD0E6` |
| accent‑hover | `#8FE0EF` | accent‑container | `#134454` |
| on‑accent‑container | `#BFF0F7` | outline | `#4A4C5C` |
| outline‑variant | `#2E3140` | divider | `#242633` |
| success | `#57D89B` | success‑container | `#0C3D27` |
| on‑success‑container | `#A6EBC9` | warning | `#FFB955` |
| warning‑container | `#3D2A00` | on‑warning‑container | `#FFD79A` |
| error | `#FF8A93` | error‑container | `#5C141C` |
| on‑error‑container | `#FFDADD` | info | `#5FD0E6` |
| info‑container | `#134454` | on‑info‑container | `#BFF0F7` |
| scrim | `rgba(0,0,0,.60)` | | |

> **Dark theme note:** in dark mode `brand` flips to the *light* navy tone `#8C95CE` (so navy text/icons
> read on a dark surface), and `accent` brightens to `#5FD0E6`. This is the standard M3 tonal flip.

### 1.4 Gradients (the only gradients in the app)

- **Brand header** (login header, dashboard greeting, employee day header):
  light `linear-gradient(135°, #2C3A86 0%, #3D6FA8 55%, #4A93C0 100%)` ·
  dark `linear-gradient(135°, #1A2358 0%, #25406A 60%, #2C5C7A 100%)`.
- **Avatar / map‑pin** (customer monograms, identity tiles):
  light `linear-gradient(150°, #2C3A86 0%, #3D6FA8 100%)` ·
  dark `linear-gradient(150°, #3D6FA8 0%, #5FD0E6 130%)`.

In Flutter: `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [...])`
(135° ≈ topLeft→bottomRight; 150° is slightly steeper — use `begin: Alignment(-1,-0.5)`).

---

## 2. Typography — Cairo

`fontFamily: GoogleFonts.cairo().fontFamily`. Sizes in sp. height = unitless line‑height.

| Role | Size | Weight | Height | Letter‑spacing | Used for |
|---|---|---|---|---|---|
| display‑lg | 34 | 800 | 1.18 | −0.4 | live timer (46 in‑situ), hero numbers |
| display‑md | 28 | 700 | 1.18 | −0.4 | (rare) |
| headline | 24 | 700 | 1.30 | −0.2 | screen H1 (legacy — now in app bar) |
| title‑lg | 20 | 700 | 1.30 | −0.2 | app‑bar title (19, w800), section heads |
| title‑md | 17 | 600 | 1.30 | 0 | card titles (customer name 16–17, w800) |
| title‑sm | 15 | 600 | 1.45 | 0 | list item titles |
| body‑lg | 16 | 400 | 1.45 | 0 | inputs, addresses |
| body‑md | 14 | 400 | 1.45 | 0 | body text, secondary |
| body‑sm | 13 | 400 | 1.45 | 0 | meta, captions |
| label‑lg | 14 | 700 | 1.30 | 0.3 | buttons |
| label‑md | 12 | 600 | 1.30 | 0.3 | badges, chips, tab labels |
| label‑sm | 11 | 600 | 1.30 | 0.3 | eyebrows, tiny meta |

**Weight cheat‑sheet (what the design actually uses):** numbers & KPI values **800**; card/customer
titles **800**; screen/app‑bar title **800**; CTAs **800**; section heads **700**; badges/labels **700**;
secondary text **600**; body **500–600**; placeholders **500**.

---

## 3. Spacing, radii, sizing

**Spacing scale (base‑4):** 4, 8, 12, 16, 20, 24, 32, 40, 48, 64.
- Screen edge padding **16**. Gap between stacked cards **14–16**. Card inner padding **14–20**.
- Icon↔label gap **6–8**. Section header → content **6–10**.

**Radii:** xs `8` · sm `12` · md `16` (inputs, small tiles) · lg `20` (cards) · xl `28`
(bottom sheets, hero header, overlapping detail sheet) · pill `999` (chips, status badges,
extended FAB, primary CTA pill) · button `14`.

**Icon sizes:** xs `16` · sm `20` · md `24` · lg `28` · xl `40`. Hit target `48`.

**Common component dims:**
- Action chip (app bar) **40×40**, radius 12, 1px outline‑variant border, elev‑1.
- Avatar/monogram sizes: xs 28, sm 36, md 44, lg 56, xl 72. Customer tile monogram **46×46 radius 14** or **56×56 radius 18**.
- Primary CTA min‑height **56–64**, radius `lg`(20). Bottom‑nav height ~64. FAB extended height 56.
- Status accent rail on visit card: **4px** wide, full height, inline‑start.

---

## 4. Elevation & shadows

Soft **navy‑tinted** shadows in light; deeper black + hairline inset border in dark.

| Level | Light | Dark |
|---|---|---|
| elev‑1 (resting cards) | `0 1 2 rgba(20,27,82,.06)`, `0 1 3 rgba(20,27,82,.05)` | `0 1 2 rgba(0,0,0,.40)` + inset hairline `rgba(255,255,255,.04)` |
| elev‑2 (raised) | `0 2 4 /.06`, `0 4 10 /.07` | `0 2 6 rgba(0,0,0,.45)` + inset `.05` |
| elev‑3 (sheets, dialogs) | `0 6 12 /.08`, `0 12 28 /.12` | `0 8 24 rgba(0,0,0,.55)` + inset `.06` |
| elev‑4 (FAB, floating bar) | `0 10 20 /.12`, `0 18 40 /.16` | `0 12 32 rgba(0,0,0,.60)` + inset `.07` |

Special:
- **glow‑brand** (primary CTA, active card ring): `0 8 20 rgba(30,42,110,.28)`.
- **glow‑success** (active‑visit card, live block): `0 0 0 3 rgba(30,158,99,.18)` (a soft ring).
- **glow‑accent**: `0 6 16 rgba(63,191,217,.30)`.

Dart: `BoxShadow(color: Color(0x14...).withOpacity(...), blurRadius: b, offset: Offset(0, y))`.
See `lib/app_shadows.dart`.

---

## 5. Motion

| Token | Value |
|---|---|
| dur‑fast | 120 ms (press/scale feedback) |
| dur‑base | 200 ms (colour, shadow, nav indicator slide is 340 ms) |
| dur‑slow | 320 ms (sheet rise) |
| ease‑standard | `cubic-bezier(.2,0,0,1)` → `Curves.easeOutCubic`/`Cubic(.2,0,0,1)` |
| ease‑decelerate | `cubic-bezier(0,0,0,1)` → `Curves.decelerate` |

The 10 signature interactions (full detail in `04-flows-and-state.md`):
1. **Stagger fade‑up** of list cards (each +55 ms, 420 ms, translateY 14→0).
2. **Count‑up** numbers (KPIs, analytics, headers) ~850 ms ease‑out‑cubic from 0.
3. **Success burst** — drawn ✓ + expanding ring overlay on approve / check‑out (~1.25 s).
4. **Skeleton shimmer** while a tab/screen opens (~460 ms).
5. **Pull‑to‑refresh** on the visits list (threshold ~70 px).
6. **Parallax** — detail map translates 0.4× scroll + slight scale.
7. **Sliding bottom‑nav indicator** (pill slides between tabs, 340 ms emphasized).
8. **Route polyline dash‑flow** (animated dashoffset).
9. **Snackbar with Undo** after approve/reject (reverts the status override).
10. **Pulsing GPS dot / live dot** on maps and active states.

---

## 6. Iconography — Material Symbols **Rounded**

Use `material_symbols_icons` (`import 'package:material_symbols_icons/symbols.dart';` →
`Icon(Symbols.business, fill: 1, weight: 400, opticalSize: 24)`). **Filled** vs **outlined** matters —
filled = `fill: 1`. Every glyph below is the exact icon used in the prototype and reference shots.

| Name in shots | `Symbols.` | Fill | Where |
|---|---|---|---|
| business | `business` | 1 | customer monogram / identity tiles |
| login | `login` | 1 | check‑in button, timeline "بدء" |
| logout | `logout` | 1 | check‑out button, timeline "إنهاء" |
| my_location | `my_location` | 1 | "in range", locating, live monitor |
| location_searching | `location_searching` | 1 | out of range |
| location_on | `location_on` | 1 | address rows |
| where_to_vote | `where_to_vote` | 1 | captured GPS coords, override check‑in |
| gpp_maybe | `gpp_maybe` | 1 | out‑of‑range warning block |
| warning | `warning` | 1 | flagged "out of range" |
| assistant_direction | `assistant_direction` | 0 | map directions FAB |
| navigation | `navigation` | 1 | "start navigation" (route) |
| route | `route` | 0 | route header / nav, km stat |
| directions_car | `directions_car` | 0 | drive‑time on route stops |
| schedule | `schedule` | 1/0 | scheduled time, "scheduled for" |
| timer / timelapse | `timer` / `timelapse` | 0 | durations |
| event / today | `event` / `today` | 0 | dates, "today" KPI |
| event_available | `event_available` | 1 | visits count |
| bolt | `bolt` | 1 | "active now" KPI/section |
| pending | `pending` | 1 | "pending review" status |
| rate_review | `rate_review` | 0 | review entry |
| verified | `verified` | 1 | approved, on‑time, signature ✓ |
| task_alt | `task_alt` | 1 | report outcome "successful" |
| event_repeat | `event_repeat` | 1 | outcome "postponed" |
| person_off | `person_off` | 1 | outcome "client absent" |
| fact_check | `fact_check` | 1 | report card header |
| flag | `flag` | 0 | report "outcome" label |
| edit_note | `edit_note` | 0 | report "notes" label |
| add_a_photo / photo_camera | `add_a_photo`/`photo_camera` | 1 | photo proof |
| signature / draw / ink_eraser | `signature`/`draw`/`ink_eraser` | 0 | signature pad |
| send | `send` | 1 | "sent for review" |
| check / check_circle | `check`/`check_circle` | 1 | approve, success, toast |
| close / cancel | `close`/`cancel` | 0 | reject, dismiss |
| call | `call` | 0 | call customer/employee |
| sell | `sell` | 1 | visit type chip |
| business / groups | `groups` | 0 | customers entry |
| near_me | `near_me` | 0 | distance on cards |
| timeline | `timeline` | 0 | "times & locations" header |
| insights | `insights` | 1 | analytics tab |
| dashboard | `dashboard` | 1 | dashboard tab |
| list_alt | `list_alt` | 1 | visits tab |
| settings | `settings` | 0 | settings action |
| notifications | `notifications` | 0/1 | greeting bell, notif row |
| shield_person | `shield_person` | 1 | manager role badge |
| badge | `badge` | 1 | employee role badge |
| cloud_done / cloud_off | `cloud_done`/`cloud_off` | 1 | online/offline status pill |
| cloud_upload | `cloud_upload` | 0 | sync queue item |
| sync / progress_activity | `sync`/`progress_activity` | 0 | syncing spinner |
| translate | `translate` | 0 | language |
| light_mode / dark_mode / brightness_auto | same | 0 | theme options |
| undo | `undo` | 0 | snackbar undo |
| manage_accounts | `manage_accounts` | 0 | edit profile |
| trending_up / trending_down | same | 0 | analytics deltas |
| leaderboard / emoji_events / workspace_premium | same | 0 | leaderboards |
| arrow_back_ios_new / arrow_forward_ios | same | 0 | back (LTR / RTL) |
| chevron_left / chevron_right | same | 0 | row affordance (dir‑aware) |
| delete | `delete` | 0 | manager delete visit |
| touch_app / hourglass_top / replay | same | 1 | employee card affordances |

> Tab icons in the bottom nav are **filled when active**, outlined when inactive.

Continue to `02-components.md`.
