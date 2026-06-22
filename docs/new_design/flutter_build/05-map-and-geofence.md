# 05 — The live map, geofence & pulse-ring animation

> This is the single most intricate piece of the UI. It appears on the **Visit-detail**
> screen (employee + manager), the **Dashboard** field map, and the **Route** screen.
> Reference Dart: [`lib/geofence_map.dart`](lib/geofence_map.dart). Web source of truth:
> `ui_kits/customer-visits/VisitDetailScreen.jsx › MapView`.
> Screenshots: `screenshots/11-visit-scheduled-*.png`, `12-visit-active-*.png`, `16-detail-*` (light+dark).

---

## 1. What's on the map (z-order, bottom → top)

| # | Layer | What it is |
|---|-------|-----------|
| 1 | **Base map** | A static image `assets/images/map-cairo.png`, `BoxFit.cover`, centred. In production swap for a real map widget — every layer above is an overlay and stays unchanged. In **dark mode** a colour-matrix tint darkens it. |
| 2 | **Readability veil** | A top→bottom `LinearGradient`: `#0A0B0F` @ .28 → transparent (26%) → transparent (64%) → `#0A0B0F` @ .34. Keeps the white pins/pills legible over any map tile. |
| 3 | **Geofence** | The customer's allowed check-in radius: a **dashed translucent green circle**. Fill `success @ 16%`, stroke `2px dashed success @ 75%`. Fixed visual Ø 132 → radius **66**. |
| 4 | **Radar sweep** | Only while `phase ∈ {locatingIn, locatingOut}` — a rotating ~60° lit wedge (a `SweepGradient` of `accent` 0 → .55 → 0) clipped to the geofence, 1.4 s linear loop. |
| 5 | **Pulse rings** | **Two** expanding circles centred on the employee's GPS dot (details §3). |
| 6 | **Customer pin** | A 40 px gradient teardrop (`Symbols.business`, 3 px white border, navy shadow) + a 2 px white stem; anchored so the tip sits on the point. |
| 7 | **GPS core** | The crisp 18 px accent dot, 3 px white ring, softly "breathing" 1 → 1.18 → 1. |
| 8 | **Live-tracking pill** | Frosted `rgba(10,11,15,.55)` pill, top inline-start: a blinking green dot + "تتبّع مباشر". |
| 9 | **Directions FAB** | 44 px `surface` rounded-14 button, bottom inline-end, `Symbols.assistant_direction` in brand. |

---

## 2. Positioning model — percentage points, not lat/lng

Every placed element uses a **fraction of the map box**, exactly like the web `{x, y}` (in %):

```dart
class MapPoint { final double x, y; const MapPoint(this.x, this.y); // 0..1
  Alignment toAlignment() => Alignment(x * 2 - 1, y * 2 - 1); }    // → Align(-1..1)
```

- **Widgets** (pins, dots, pills) are placed with `Align(alignment: point.toAlignment())`.
- **Painted geometry** (geofence, rings, sweep) converts inside the painter:
  `Offset(point.x * size.width, point.y * size.height)`.

This makes the whole scene **resolution-independent** — it scales with the card, same as the prototype.
The seed data carries `customerPos`/`myPos` already in this form (e.g. `{x: 50, y: 46}` ÷ 100).

---

## 3. The pulse rings — exact timing

The web uses three CSS keyframes; here is the precise mapping to the painter.

| Web keyframe | Web values | Flutter equivalent |
|---|---|---|
| `cvPulse` (ring A) | `scale .55→2.4`, `opacity .55→0` (gone by 70%), `2s ease-out` | Ring A: `fromScale .55 toScale 2.4`, `fromOpacity .55 fadeBy .70` |
| `cvPulse2` (ring B) | `scale .55→3.1`, `opacity .35→0` (gone by 80%), `2s`, **`.6s` delay** | Ring B: `fromScale .55 toScale 3.1`, `fromOpacity .35 fadeBy .80`, phase `+.30` |
| `cvDot` (core) | `scale 1→1.18→1`, `2s ease-in-out` | `1 + .18·|sin(t·2π)|` on the core |

**One controller, two rings.** A single 2 s `AnimationController` (`_pulse`, `repeat()`) gives a
normalized clock `t ∈ [0,1)`. Ring A reads `t`; ring B reads `(t + .30) % 1` — the 0.3 phase offset
reproduces the `0.6 s` delay on a 2 s loop. Each ring computes:

```dart
final eased   = 1 - pow(1 - t, 2);                 // ease-out
final scale   = fromScale + (toScale - fromScale) * eased;
final opacity = t >= fadeBy ? 0 : fromOpacity * (1 - t / fadeBy);
canvas.drawCircle(centre, 11 * scale, Paint()..color = accent.withOpacity(opacity));
```

`11` is the base radius (the web ring is 22 px wide at scale 1). Rings fade to 0 **before** the loop
restarts, so there's no visible "pop" — the ramp-out (`fadeBy` 70 % / 80 %) is what sells the radar feel.

> **Why a painter and not stacked `AnimatedContainer`s?** Three reasons: (a) the rings must stay pixel-
> registered to the same centre as the dashed geofence and the sweep — one painter guarantees it;
> (b) `drawCircle` with a per-frame opacity is far cheaper than rebuilding/compositing decorated boxes;
> (c) it survives parent re-renders (state changes on the detail sheet) without restarting the loop.

---

## 4. The radar sweep (acquiring a fix)

When the user taps **check-in/out**, the phase goes to `locatingIn`/`locatingOut` for ~1.5 s. During
that window a wedge sweeps the geofence:

```dart
Paint()..shader = SweepGradient(
  transform: GradientRotation(sweepT * 2 * pi),       // 1.4s linear controller
  colors: [accent.withOpacity(0), accent.withOpacity(.55), accent.withOpacity(0)],
  stops:  [0.0, 0.16, 0.20],                          // ~60° lit, rest transparent
).createShader(Rect.fromCircle(center: cCentre, radius: 66));
// clipped to the geofence circle so the wedge can't spill outside it
canvas.clipPath(Path()..addOval(Rect.fromCircle(center: cCentre, radius: 66)));
```

---

## 5. Dark-mode map tint

The web darkens the map via a CSS filter:
`brightness(.74) contrast(1.06) saturate(.82) hue-rotate(-6deg)`. In Flutter we wrap the base image
in a `ColorFiltered` with an equivalent **colour matrix** (`_kDarkMapMatrix` in the Dart file) that
multiplies each channel ~0.78–0.86 and subtracts a small constant — pins, veil and rings sit on top
unchanged, so only the underlying tiles darken. Light mode passes a no-op filter.

> If you adopt a real map SDK, prefer its native dark style JSON over the matrix; keep the matrix only
> for the static-image fallback.

---

## 6. Driving the phases

The detail screen owns a `VisitPhase` and feeds it in. Transitions (employee flow):

```
scheduled ──tap check-in──▶ locatingIn ──(1.5s)──▶ active ──tap check-out──▶ locatingOut ──(1.3s)──▶ completed
```

`GeofenceMap` only cares whether the phase is a `locating*` one (to show the sweep); the pulse rings
and breathing dot run continuously in every phase. See `04-flows-and-state.md` for the full machine,
the GPS-capture timing, and how the captured coordinates land on the timeline.

---

## 7. Checklist for a 1:1 result

- [ ] Geofence radius **66** on a 300-tall map; dash **6**, gap **5**, stroke **2**, `success` @ 75 % / fill @ 16 %.
- [ ] Two rings, base radius **11**, scales **2.4** / **3.1**, opacities **.55** / **.35**, fade by **70 %** / **80 %**, ease-out, ring B phase **+.30**.
- [ ] Core dot 18 px, 3 px white border, breathing `1→1.18`.
- [ ] Customer pin 40 px gradient circle + 22 px filled `business` + 2 px white stem, lifted so the tip touches the point.
- [ ] Sweep only while locating; ~60° wedge; clipped to the geofence; 1.4 s linear.
- [ ] Live-tracking pill `rgba(10,11,15,.55)` + blinking `#4ADE80` dot; directions FAB `surface`/brand.
- [ ] Dark mode tints **only** the base image.
