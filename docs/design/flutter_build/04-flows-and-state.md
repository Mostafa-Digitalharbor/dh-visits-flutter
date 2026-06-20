# 04 — Flows, Roles & State

The app's behaviour is small and deterministic. Model it with any state solution (Provider shown).

---

## 1. Domain models

```dart
enum UserRole { manager, employee }

class AppUser {
  final String nameAr, nameEn, initial, roleAr, roleEn, email;
  const AppUser({required this.nameAr, required this.nameEn, required this.initial,
    required this.roleAr, required this.roleEn, required this.email});
}

// Seed identities
const kManager = AppUser(nameAr:'محمد عادل', nameEn:'Mohamed Adel', initial:'م',
  roleAr:'مدير الفريق', roleEn:'Team manager', email:'m.adel@harbor.eg');
const kEmployee = AppUser(nameAr:'منى فؤاد', nameEn:'Mona Fouad', initial:'م',
  roleAr:'مندوب ميداني', roleEn:'Field rep', email:'mona.fouad@harbor.eg');

enum VisitStatus { scheduled, active, review, approved, rejected }

class Visit {
  final String id;                 // "VIS/00232"
  final String customerAr, customerEn, addrAr, addrEn;
  final String employeeAr, employeeEn, initial;   // assignee
  final String createdByAr, createdByEn;          // manager who created it
  final String date;               // "2026-06-19"
  final String typeAr, typeEn;     // متابعة / ديمو / تحصيل / صيانة
  VisitStatus status;
  final String scheduledAt;        // "05:00"
  String? arrival, departure;      // check-in / check-out clock "HH:mm"
  String? duration;                // "00:55:00"
  bool onTime;
  // geofence
  final int geofence;              // radius metres (120–200)
  bool inRange;                    // employee within geofence at open time
  final int distance;              // metres away
  bool flagged;                    // checked in OUT of range → needs review
  final String startCoords, endCoords;  // "30.0131° N, 31.2089° E"
  final bool mine;                 // assigned to current employee
  VisitReport? report;
}

class VisitReport {
  final String outcome;            // 'done' | 'postponed' | 'absent'
  final String notes;
  final bool photo, signed;
}
```

**Outcomes** (report sheet): `done` تمّت بنجاح (`task_alt`, green) · `postponed` مؤجلة
(`event_repeat`, amber) · `absent` العميل غير موجود (`person_off`, red).

**Visit types:** متابعة Follow‑up · ديمو Demo · تحصيل Collection · صيانة Maintenance.

---

## 2. Visit lifecycle — state machine

```
                    manager creates & assigns
                              │
                          ┌───▼────┐
                          │scheduled│  employee sees it in "مجدولة اليوم"
                          └───┬────┘
        employee taps Check‑in (must be inRange, else override→flagged)
                              │  (GPS captured → arrival + startCoords)
                          ┌───▼────┐
                          │ active │  live elapsed timer; manager sees "live monitoring"
                          └───┬────┘
        employee taps Check‑out → GPS captured → Report sheet (outcome/notes/photo/signature)
                              │  submit
                          ┌───▼────┐
                          │ review │  manager queue; employee sees "بانتظار مراجعة المدير"
                          └───┬────┘
                  manager Approve │ Reject
                     ┌────────────┴───────────┐
                 ┌───▼────┐               ┌────▼────┐
                 │approved│               │rejected │ (employee redoes)
                 └────────┘               └─────────┘
```

**Status → colour/label** (used by `StatusBadge`, cards, detail):

| status | ar | en | tone | icon |
|---|---|---|---|---|
| scheduled | مجدولة | Scheduled | brand (navy) | schedule |
| active | نشطة الآن | Active now | success (green) + dot | — |
| review | بانتظار المراجعة | Pending review | warning (amber) | pending |
| approved | معتمدة | Approved | info (cyan) | verified |
| rejected | مرفوضة | Rejected | error (red) | cancel |

The current state is held in `AppState.overrides: Map<String, VisitStatus>` layered over the seed
list, so a check‑out (→review) or an approve (→approved) updates the visit everywhere at once.

```dart
List<Visit> get effectiveVisits =>
  _seed.map((v) => overrides.containsKey(v.id) ? v.copyWith(status: overrides[v.id]) : v).toList();

void submitReport(Visit v, VisitReport r) {       // employee check-out
  v.report = r;
  overrides[v.id] = VisitStatus.review;
  notify();
}
void decide(String id, bool approved) {           // manager
  final prev = overrides[id];
  overrides[id] = approved ? VisitStatus.approved : VisitStatus.rejected;
  showUndoSnackbar(onUndo: () { overrides[id] = prev; notify(); });
  notify();
}
```

---

## 3. Roles — what each sees

| Capability | Manager | Employee |
|---|---|---|
| Landing tab | Dashboard | My visits |
| Bottom‑nav tabs | لوحة التحكم · زيارات الفريق · التحليلات | زياراتي · مسار اليوم · الإعدادات |
| Visits list | **all** team visits | **only `mine == true`** |
| Visit detail | **monitoring** (read‑only) + Approve/Reject when `review` | **action** (check‑in/out + report) |
| Create visit (FAB) | ✅ on the visits tab | ❌ |
| Review queue | ✅ (via dashboard "pending review" KPI) | ❌ |
| Analytics | ✅ | ❌ |
| Customers | ✅ (dashboard app‑bar `groups` action) | ❌ |
| Route map | (n/a) | ✅ own tab |
| Field check‑in/out | ❌ never | ✅ |

Role is chosen on the **login screen** (segmented `مدير` / `موظف ميداني`) and stored in `AppState.role`.

---

## 4. Navigation graph

```
login ──login(role)──▶ shell
shell (manager): tabs {dashboard, visits, analytics}
   dashboard ──KPI "pending review"──▶ review
   dashboard ──appbar groups──▶ customers
   dashboard ──appbar settings──▶ settings
   visits ──FAB──▶ createVisitSheet (modal)
   visits / review ──tap card──▶ visitDetail(manager)
shell (employee): tabs {visits, route, settings}
   visits ──tap card──▶ visitDetail(employee)
   visitDetail ──check‑out submit──▶ reportSheet (modal) ──▶ back to detail (review state)
```

- **Sub‑screens** (settings, customers, route, review, detail) push over the shell with a back
  chip in the app bar (RTL: `arrow_forward_ios` on the **right**).
- **Detail** has no app bar: a translucent **back chip** (and manager **delete** chip) float over
  the map at top‑start/top‑end.
- **Modal sheets** (create visit, report, sync) rise from the bottom, radius‑28 top corners,
  scrim `0x66` behind, drag handle 40×4 at top.

---

## 5. Geofence rules (check‑in)

- Each visit has `geofence` (radius m) and `distance` (m away). `inRange = distance <= geofence`.
- **In range:** primary green **Check‑in** button enabled; a green strip shows "أنت داخل نطاق العميل · يبعد {distance} م · نطاق التسجيل {geofence} م".
- **Out of range:** the check‑in button is replaced by an **amber warning block** ("أنت خارج نطاق العميل …") + an **outlined** secondary button "تسجيل خارج النطاق". Tapping it checks in but sets `flagged = true`.
- A **flagged** visit shows a red "خارج النطاق · سُجّلت خارج نطاق الموقع المعتمد" banner on the detail and a red bordered header in the manager review card → forces manager attention.
- On real devices use `geolocator`: capture `Position` at check‑in/out, compute
  `Geolocator.distanceBetween(...)` to the customer location for `distance`.

---

## 6. Offline & sync

- A **status pill** sits in the shell app bar: green `cloud_done` (online) or amber `cloud_off` +
  pending count (offline). Tapping toggles (demo) / opens the **sync queue** sheet.
- While **offline**, an amber banner shows under the app bar ("وضع عدم الاتصال — سيتم رفع التسجيلات تلقائياً"), and a check‑out **queues** the visit instead of uploading.
- **Sync sheet:** lists queued visits (`cloud_upload`), a "مزامنة الآن" button (disabled while
  offline); syncing spins `progress_activity` ~1.4 s then clears the queue + success toast.

---

## 7. Micro‑interaction specs (the 10)

1. **Stagger:** each card `AnimatedOpacity`+`SlideTransition` from `(0, 14px)`; per‑item delay `index*55ms`, dur 420 ms, `Cubic(.2,.7,.3,1)`. Re‑run on pull‑to‑refresh.
2. **Count‑up:** `TweenAnimationBuilder<double>(0→value, 850ms, Curves.easeOutCubic)`, tabular figures; keep any trailing unit (`%`, `كم`). Skip non‑numeric like `00:58`.
3. **Success burst:** full‑screen `Stack` overlay, scrim `bg@72%` + blur; a 96px ring scales 0.4→1.7 fading out, a check `Path` draws via `CustomPainter` with animated `PathMetric` (0.5 s), label fades up. Auto‑dismiss 1.25 s. Trigger on approve + check‑out submit.
4. **Skeleton:** shimmer blocks (`LinearGradient` sweeping 200%→−200%, 1.3 s) matching the screen; show ~460 ms on tab/route change.
5. **Pull‑to‑refresh:** `RefreshIndicator` (or custom) on the visits `ListView`; threshold ~70 px.
6. **Parallax:** detail `ScrollController` listener → map `Transform.translate(0, scroll*0.4)` + `scale(1 + min(.14, scroll*0.0007))`.
7. **Nav indicator:** `AnimatedPositioned`/`AnimatedAlign` pill (64×32, `brand-container`) sliding under the active tab, 340 ms `Cubic(.2,0,0,1)`.
8. **Route dash‑flow:** polyline drawn by `CustomPainter`, animate `dashOffset` (e.g. `0→-100`, 1.6 s linear, repeat).
9. **Undo snackbar:** after approve/reject, `SnackBar` (ink bg) with `SnackBarAction('تراجع')` that reverts the override; ~4 s.
10. **Pulse:** GPS dot / live dots use a repeating `scale` 1→1.18 (1.5–2 s) + expanding ring rings (`cvPulse`). Respect `MediaQuery.disableAnimations` / reduce‑motion (snap to end state).

Continue to `02-components.md` and `03-screens.md`.
