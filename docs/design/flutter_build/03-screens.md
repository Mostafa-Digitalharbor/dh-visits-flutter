# 03 — Screens

One section per screen. Each: **screenshot**, **app bar**, **body structure top→bottom**, **measurements**,
and role notes. Edge padding is **16** unless stated. All composed from `02-components.md` widgets.

---

## 01 · Login — `screenshots/01-login.png`

Full‑bleed **brand‑gradient header** (radius‑28 bottom corners, padding `14 20 64`) containing: a
top row (ghost back + translate + theme‑toggle icon buttons), then centered **96px white logo circle**
(elev‑3), app title **"Visits" 30/800 #fff**, tagline 15/500 white@88%.

An **overlapping white sheet** (`margin: -44 16 0`, radius‑28, elev‑3, padding 24) holds:
- Title "أهلاً بعودتك" 26/800 + sub "سجّل دخولك لبدء يومك الميداني" 15/500 secondary.
- **Role selector** — label "الدخول بصفتك" 12/700 tertiary, then 2 equal tiles (`مدير` `shield_person` /
  `موظف ميداني` `badge`): vertical icon 26 + label 13/700; selected → `brand-container` bg + `brand`
  1.5px border + filled icon; idle → surface + outline‑variant.
- Two `AppTextField` (person / lock+eye), prefilled.
- **Filled CTA** "تسجيل الدخول" `login`, full‑width, size lg.

`onLogin(role)` → shell. Picking a role updates the username field (`m.adel` / `mona.fouad`).

---

## 02 · Manager Dashboard — `screenshots/02-dashboard.png`

**App bar:** logo mark · eyebrow "مدير الفريق" + title "Visits" · StatusPill · `groups` + `settings` chips.

Body (scroll, gap 16):
1. **Greeting header** — brand gradient, radius‑28, padding `18 18 16`, decorative circle top‑end.
   Row: 46px translucent avatar + ("صباح الخير 👋" 13/600 white@85%, name 22/800) + 46px notif tile.
   Then "إنجاز اليوم" + `done/total · pct%` 13/800; an 8px progress bar (track white@20%, fill
   `#fff→accent`); a stat row: `route` {km} + "كم في الميدان", `schedule` {hours} + "وقت الميدان". (km counts up.)
2. **KPI grid** 2×2, gap 12 — `KpiTile`s: active(success) / review(warning) / overdue(error) / today(brand). Values count up. Tap → visits (review → review screen).
3. **Field map card** — `Card` padding 0, header ("الموظفون في الميدان" + count chip), a **190px map**
   (asset `map-cairo.png`, cover) with pulsing 38px **green pins** (employee initials) + readability
   gradient veil; then a staff list (36px green avatar + name/company + chevron).
4. **Recent activity** — section "آخر النشاطات" `bolt`; a `Card` list: 40px avatar with a small tone
   badge (login/logout/add_task), "{name} {action} {target}", time on the end.
5. **Top customers** / **Top employees** — `emoji_events` / `workspace_premium` sections; `Card`s of
   leaderboard rows (rank, name, mini progress bar to max, value).

---

## 03 · Analytics — `screenshots/03-analytics.png`  (manager)

**App bar:** "التحليلات", no extra action.
1. **Metric grid** 2×2 — tiles (`bg surface`, radius lg, elev‑1, padding 14): top row tone icon chip
   (38, tone‑container) + delta (`trending_up/down` + %); value 26/800 (count‑up); label 12.5/500.
   Metrics: visits 27 (+12%) · on‑time 92% (+4%) · avg 00:58 (−3د) · km 214 (+8%).
2. **Weekly bar chart** `Card` — header "الزيارات هذا الأسبوع" + "مقارنة بالأسبوع الماضي"; 7 day columns
   (value on top, bar grows to max, today highlighted with avatar gradient + brand label; empty = surface‑high).
3. **By employee** — section `leaderboard`; `Card` rows: 42px avatar with rank medal badge
   (gold/silver/bronze), name, on‑time **progress bar** (success ≥90 else warning) + "{pct}% · {visits}".

---

## 04 · Team Visits — `screenshots/04-team-visits.png`  (manager)

**App bar:** eyebrow + "زيارات الفريق" · StatusPill · `route` + `settings`. **FAB** extended
"زيارة جديدة" (`add`, brand pill, glow) bottom‑end.

Body: `AppTextField` search · **StatusStrip** (4 cells: للمراجعة/نشطة/مكتملة/الإجمالي, divided, the
"review" cell highlighted amber) · then visits grouped by **SectionHead** (icon+label+count chip):
مجدولة اليوم → جارية الآن → بانتظار المراجعة → مكتملة, each a list of **VisitCard** (`role: manager`,
shows assignee row). Cards stagger in. Pull‑to‑refresh.

---

## 05 · Visit Detail — MANAGER (monitoring) — `screenshots/05-visit-detail-manager.png`

No app bar. Floating **back chip** (top‑start) + **delete chip** (top‑end, error) over the map.

1. **Map** 300px (`data-cv-map`, parallax) — geofence dashed ring, customer pin (40px gradient,
   `business`), pulsing GPS dot, "تتبّع مباشر" pill top‑start, directions FAB.
2. **Overlapping sheet** (marginTop −26, top radius 28): drag handle; a centered **"عرض للمدير — لا
   توجد إجراءات ميدانية"** note (`visibility` 16 + 12/700 tertiary).
3. **Identity** — 56px gradient tile + customer 19/800 + (`VIS` · type chip) + **StatusBadge**.
4. **Assignee tile** — 36px avatar (online if active) + "المسؤول" label + employee name + `call` button.
5. **State block:** active → live‑monitor strip ("الموظف في الموقع", green pulse "متابعة مباشرة");
   review/approved → 2 tiles (duration | on‑time/verified or flagged/warning); scheduled → "موعد الزيارة".
6. **Flagged banner** (if flagged, red).  7. **Employee report card** (`fact_check` "تقرير الموظف" +
   outcome chip + notes + photo/signature ✓).  8. **Timeline** (created → check‑in → check‑out with
   times + GPS coords).
9. **Approve/Reject bar** (only when `review`) — sticky bottom, `bg surface`, top divider: "رفض وإعادة"
   (error‑container, flex 1) + "اعتماد الزيارة" (success, glow, flex 1.5). Approve → success burst + undo snackbar.

---

## 06 · Create Visit sheet — `screenshots/06-create-visit.png`  (manager)

Bottom sheet (radius‑28, drag handle, scrim). Header "إنشاء زيارة جديدة" 21/800 + close chip.
Sections (each: icon 18 brand + label 13/700):
- **العميل** — 3 customer rows (radio‑select): 36px avatar + name/address + `radio_button_unchecked`→
  `check_circle`; selected row `brand-container` + brand border.
- **الموظف الميداني** — horizontal scroller of 88px employee tiles (avatar + first name), brand when selected.
- **نوع الزيارة** — wrap of type pill chips (brand when selected + glow).
- **موعد الزيارة** — a row tile (`schedule` + "2026-06-19 · 05:00" + "تغيير").
- **CTA** "إنشاء الزيارة" `add_task`, filled lg → toast "تم إنشاء الزيارة وإسنادها".

---

## 07 · Settings — `screenshots/07-settings.png`  (both)

**App bar:** eyebrow + "الإعدادات" + back chip.
- **Profile card** (`bg surface`, radius lg, elev‑1, row‑reverse): xl avatar (online) + name 20/700 +
  email (ltr) + role chip (`shield_person`/`badge` + role label).
- **الحساب** group card: "تعديل الملف الشخصي" (`manage_accounts`, chevron) · "الإشعارات" (`notifications`,
  sub "تنبيهات الزيارات والتذكيرات", **Switch** brand).
- **المظهر** group: radio rows فاتح/داكن/حسب النظام (selected → filled brand check circle).
- **اللغة** group: العربية / English radio rows.
- **sync / help / about** group: "آخر مزامنة" (+ "مزامنة الآن"), "المساعدة والدعم", "حول التطبيق" (الإصدار 2.4.0).
- **Logout** button (`bg error-container`, error fg, `logout`). Footer "Customer Visits · Digital Harbor © 2026".

---

## 08 · Customers — `screenshots/08-customers.png`  (manager)

**App bar:** "العملاء" + back. **Stats row:** 2 tiles (groups → total · trending_up → active).
Search field. Then **customer cards** (row‑reverse): 56px gradient monogram + name 17/700 + address
(`location_on`) + status badge (active dot / last‑visit) ; divider; footer row: `call` + phone (ltr)
and `event_available` {visits} + `history` {lastVisit}.

---

## 09 · Review queue — `screenshots/09-review.png`  (manager)

**App bar:** "مراجعة الزيارات" + back. Centered "{n} بانتظار موافقتك" (count chip amber). Then
**review cards** (`bg surface`, radius lg; flagged → red border + red "خارج النطاق" banner on top):
identity row (48px gradient tile + customer + `VIS·type` + duration chip) · meta strip (employee,
arrival–departure, on‑time colour) · actions row: **رفض** (error‑container, flex 1) + **اعتماد**
(success, glow, flex 1.4). Acting removes the card; empty → `task_alt` "لا توجد زيارات بانتظار المراجعة".

---

## 10 · My Visits — `screenshots/10-my-visits.png`  (employee)

**App bar:** eyebrow "مندوب ميداني" + "زياراتي" · StatusPill · `settings`.
- **Day header** — brand gradient, radius‑28: 46px avatar (initial) + ("صباح الخير 👋", name 18/800) +
  role chip; then "جدول يومك" + `done/total · pct%`; progress bar.
- Search field. Then **VisitCard**s (`role: employee`, affordance line) grouped: جارية الآن → مجدولة اليوم
  → بانتظار المراجعة → مكتملة (only `mine`). Stagger + pull‑to‑refresh.

---

## 11 · Visit Detail — EMPLOYEE · scheduled — `screenshots/11-visit-scheduled.png`

No app bar; floating back chip. Map 300px (geofence ring + GPS dot). Overlapping sheet:
- Identity (customer + VIS + type chip + **مجدولة** badge) · address row (`location_on` + `call`).
- "موعد الزيارة" tile (scheduled time).
- **Range strip** — in‑range green ("أنت داخل نطاق العميل · يبعد {d} م · نطاق التسجيل {g} م") OR
  out‑of‑range amber warning block.
- **Check‑in CTA** — big green button (`login`, "تسجيل بدء الزيارة", sub "أنت داخل النطاق", min‑h 64,
  glow, sheen). Out of range → outlined "تسجيل خارج النطاق" instead (→ flagged).
- **Timeline** (created done; check‑in = next/live; check‑out pending).
- Meta: date tile + field‑employee tile.

Tap check‑in → **locating** state (busy button `my_location` "جارٍ تحديد موقعك…", radar sweep on map,
~1.5 s) → **active**.

---

## 12 · Visit Detail — EMPLOYEE · active — `screenshots/12-visit-active.png`

Same scaffold; status now **نشطة الآن**. The state block becomes a **live elapsed card**
(`bg surface`, radius xl, glow‑success ring): "الوقت المنقضي" (green pulse dot) + **HH:MM:SS 46/800
tabular** ticking every second + "بدء الزيارة {arrival}". CTA becomes the big **red check‑out**
(`logout`, "تسجيل إنهاء الزيارة", sub "تم التقاط الموقع · {coords}"). Tap → locating ~1.3 s → **Report sheet**.

---

## 13 · Report sheet — `screenshots/13-report-sheet.png`  (employee)

Bottom sheet (radius‑28, drag handle), header 40px success icon chip (`fact_check`) + "تقرير الزيارة" 21/800.
- **نتيجة الزيارة** (`flag`) — 3 outcome tiles (تمّت بنجاح `task_alt` green / مؤجلة `event_repeat` amber /
  العميل غير موجود `person_off` red); selected → tone‑container + tone border + filled icon.
- **ملاحظات** (`edit_note`) — multiline textarea (radius md, outline‑variant, placeholder).
- **صورة إثبات** (`add_a_photo`) — an 84px dashed "إضافة صورة" tile (`photo_camera`); added photo shows a
  thumbnail with a remove ✕. (Use `image_picker` / camera.)
- **توقيع العميل** (`signature`) — a 130px signing canvas (radius md, dashed, "وقّع هنا" hint + `draw`);
  use the `signature` package; a "مسح" (`ink_eraser`) clears.
- **CTA** "إنهاء وحفظ التقرير" (`check_circle`, success, glow, min‑h 56) → success burst → status `review`,
  detail shows a **report summary card** + amber "تم الإرسال للمراجعة · بانتظار مراجعة المدير" banner.

---

## 14 · Today's Route — `screenshots/14-route.png`  (employee)

**App bar:** eyebrow + "مسار اليوم" + StatusPill + settings.
- **Map** 280px (parallax): a **dashed white polyline** (animated dash‑flow) through ordered stops;
  numbered pins (next = brand + pulse ring, others = ink); a "{n} محطات · {km} كم" pill top‑start.
- **Summary row:** 2 tiles (stops count | total km).
- **Stops list** with a connecting rail: each row = number badge (next = brand + glow) + name +
  (`schedule` ETA, `directions_car` drive‑time) + ("المحطة التالية" chip for next / a directions
  button for others).
- **CTA** "بدء الملاحة" (`navigation`, brand, glow).

---

## 15 · Dark — My Visits — `screenshots/15-dark-my-visits.png`

Same as 10 with dark tokens: bg `#0A0B0F`, surfaces `#0E0F15`+, text `#ECECF4`, dark cards use
hairline inset borders instead of soft shadows. The brand gradient header stays (slightly darker
variant). Maps get a **dark tint** (`brightness .74 contrast 1.06 saturate .82`). Status colours use the
dark tones (success `#57D89B`, warning `#FFB955`, etc.).

---

## 16 · Dark — Visit Detail — `screenshots/16-dark-detail.png`

Detail scaffold in dark; the map is tinted darker; surfaces and dividers follow the dark scheme.
Confirms the floating chips, sheet, timeline and CTAs all read correctly on dark.

---

### Build order suggestion
Foundations → `theme/` → core widgets (StatusBadge, CvButton, Avatar, AppTextField, CvAppBar,
CvBottomNav, StatusPill) → VisitCard + KpiTile → Login + Shell + role nav → Visits lists → Visit
detail (employee lifecycle first, then manager monitoring) → Report sheet → Review → Create sheet →
Dashboard/Analytics/Customers/Route/Settings → micro‑interactions pass.
