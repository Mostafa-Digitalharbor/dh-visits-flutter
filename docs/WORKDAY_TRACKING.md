# Whole-workday route tracking

How the app records an employee's movement for an entire work day — including
the travel between visits — alongside the existing per-visit GPS trail.

## 1. Two trails, one location source

| | Visit trail | Work-day route |
|---|---|---|
| Covers | One visit, Start → End | The whole day, "Start work day" → "End work day" |
| Server | `dh.visit.location.log` via `/api/visit/*` (docs/API.md) | `dh.work.session` + `dh.work.location` via `/api/workday/*` (module `dh_workday_tracking`); on the dummy server only, the no-code `x_dh_work_session` / `x_dh_work_location` (§2.3) |
| Client | `VisitTrailTracker` | `WorkdayTracker` → `WorkdayRepository` |
| Movement between visits | not contained | contained |

A point taken while a visit is running is stored **twice, on purpose**: once as
a work-day point carrying `visit_id`, once on the visit's own trail through
`/api/visit/log_locations`. The visit API stays the source of truth for visit
trails; the work-day store is the source of truth for the day.

There is never more than one GPS stream:

- **Work day open (Android and iOS):** the native capture is the only sampler —
  `WorkdayLocationService.kt` (foreground service) or `WorkdayLocation.swift`
  (background location updates). `VisitTrailTracker` opens no stream; fixes
  stamped with the running visit are handed to it by `WorkdayTracker.drain()`
  → `VisitTrailTracker.ingest()`.
- **No work day:** `VisitTrailTracker` keeps its original foreground-only
  geolocator stream, unchanged.

## 2. Server

### 2.1 Production: `dh_workday_tracking` (backend/dh_workday_tracking)

The backend source of `dh_visit_management` is not in this workspace, so the
work-day backend is a separate Odoo 19 addon that depends on it (its groups
and `dh.visit`) and can be installed next to it or merged into it. It does not
touch `/api/visit/*` or `dh.visit.location.log`. Setup, tests and the full
contract: [backend/dh_workday_tracking/README.md](../backend/dh_workday_tracking/README.md).

**Models**

`dh.work.session` — one work day: `client_uid`, `employee_id` (required),
`user_id`/`company_id` (stored related), `started_at`, `ended_at`, `state`
(`active` | `completed`), start/end latitude/longitude, `device_id`,
`location_ids`, computed `location_count` and `tracked_distance_km`.

`dh.work.location` — one fix, append-only: `session_id` (required, cascade),
`employee_id`/`user_id`/`company_id` (stored related), `visit_id` (optional
`dh.visit`), `logged_at`, `latitude`, `longitude`, `accuracy`, `altitude`,
`speed`, `heading`, `device_id`, `client_uid`, `source` (`start` | `track` |
`end`).

**Routes** (POST, JSON-RPC, `auth='user'`, naive UTC, like `/api/visit/*`)

| Route | Params | Result |
|---|---|---|
| `/api/workday/start` | `client_uid`, `latitude?`, `longitude?`, `started_at?`, `device_id?` | `{session, created}` — the day with that `client_uid`, else the employee's open day, else a new one |
| `/api/workday/active` | — | `{session}` or `{session: false}` |
| `/api/workday/get` | `session_id` or `client_uid` | `{session}` or `false` when not visible |
| `/api/workday/log_locations` | `session_id`, `points[]` (≤ 500: `client_uid`, `logged_at`, `latitude`, `longitude`, `accuracy?`, `altitude?`, `speed?`, `heading?`, `visit_id?`, `device_id?`, `source?`) | `{created, duplicates[index], rejected[{index, error}], location_count, tracked_distance_km}` |
| `/api/workday/end` | `session_id`, `latitude?`, `longitude?`, `ended_at?` | `{session, already_completed}` |
| `/api/workday/track` | `session_id`, or `date_from` + `date_to` (+ `employee_id?`) | one session with `points` (oldest first), or `{sessions: [...]}` |

**Rules enforced on the server** (Python + SQL, for the API and for `call_kw`)

- One active day per employee: partial unique index
  `(employee_id) WHERE state = 'active'`; `start` serialises per employee with
  a transaction advisory lock, and a race lost at the index is retried by
  Odoo's request retry and then returns the winner's day.
- Idempotency: unique `(employee_id, client_uid)` for days and
  `(session_id, client_uid)` for points; a re-sent point is reported in
  `duplicates`, never stored twice, including two identical uploads at once.
- Ownership: only the employee linked to the user starts, ends or adds points
  to their day (an administrator cannot add points or open a day for someone).
- Points only into an **active** day. `end` locks the day `FOR UPDATE` and
  uploads lock it `FOR SHARE`, so no point commits after the end.
- Completed days cannot be reopened (not even by the superuser) or changed;
  start fields are immutable; points can never be written; deletion only by
  `base.group_system` (retention).
- Coordinates in range and not 0,0; accuracy/speed ≥ 0; heading 0–360;
  `logged_at` parseable, not more than 5 min in the future and not before the
  day's start − 2 min; a day not in the future, not older than 7 days, not
  overlapping a completed day; `visit_id` must exist and be readable by the
  employee. Each refused point is reported by index, never failing the batch.
- Access rules: Visit User reads/creates own; Visit Manager additionally reads
  the days and points of employees below them in the `hr.employee` hierarchy
  (`child_of`, evaluated at query time); Visit Administrator reads all and may
  close a day; multi-company rule on both models.
- **Manager scope vs. the real module (read over RPC, 2026-09-14):**
  `dh.visit.manager_user_ids` on the real `dh_visit_management` 19.0.2.1.0 is a
  stored many2many that is not always the HR hierarchy: on the regression
  server 13 of 15 visits match it, but two visits of an employee with no HR
  manager list a manager explicitly. A work day deliberately follows the HR
  hierarchy only — being added to one visit does not expose that employee's
  whole-day movements. If the business wants visit managers to see the day
  too, that is a product decision for the manager rule in
  `security/workday_security.xml`, not a fix.

**Verified** on a local Odoo 19 (community) with a test stub of
`dh_visit_management` (its groups, `dh.visit` and record rules as probed on the
dummy server): 17 module tests, 22 concurrency checks against the running
server (12 simultaneous starts → one day; 5 identical uploads → each point
once; uploads racing End Work Day over 8 rounds → none after the end), and the
app's own `WorkdayRepository` against it
(`test/workday_odoo_integration_test.dart`). Not yet installed on any
company server.

### 2.2 How the app picks the store

`WorkdayRepository.backend()` calls `/api/workday/active` once per server:
answered (even with an Odoo error such as "no employee") → the dedicated API;
Odoo's 404 page → the legacy models; offline → not remembered, asked again.
`WorkdayTracker` is unchanged by the choice: every repository method means the
same on both. With the API, the employee is derived by the server (the app
sends no `employee_id`), `existingPointUids` is not needed (the server dedupes)
and a refused point surfaces as `ApiErrorCode.validation`, isolated point by
point by the tracker as before.

### 2.3 Legacy: no-code models (dummy server only)

`x_dh_work_session` / `x_dh_work_location` on `visits-dhh.odoo.com`,
provisioned by admin before the module existed: the same fields with `x_`
prefixes, access through record rules, stored computed fields
`x_is_sole_open` and `x_in_session_window` as create-rule guards. Record rules
run per request, so two simultaneous creates could both pass there, and a
refused offline day is not merged — the module fixes both. Remove these models
(and the legacy branch of `WorkdayRepository`) once the dummy server has the
module. They never existed in production, so no production data migrates.

## 3. Lifecycle

1. **Start work day** (bar under the app bar, employee shell): the in-app
   disclosure is accepted once (§7); location access checked (denied /
   permanently denied → Settings / service off / approximate only → Settings);
   notification permission requested (Android); on iOS "Always" is asked once;
   fresh fix acquired. `WorkdayTracker.startDay` adopts a session already open
   on the server, otherwise creates a local one and queues its `start` point,
   then starts native capture.
2. **Capture:** a location update is requested every 5 s (high accuracy,
   ≥ 5 m) and every accepted fix is written to a synced journal in app storage,
   stamped with the local session and the running visit. Accepted = newer than
   the last recorded fix, accuracy ≤ 50 m (≤ 100 m after 30 s without a fix),
   moved ≥ max(5 m, accuracy/2 capped at 15 m), and ≥ 4 s after the last fix
   unless ≥ 15 m away. While moving that is about one fix every 5 s (40–70 m by
   car); standing still records nothing. The same rules run on both platforms.

   **Restart dedupe:** the last recorded fix (time, position) is persisted with
   every journal write, and the day's start position is seeded as the first.
   Capture restarted by the system or after the process died continues from
   it, so the cached position is not recorded again. Each queued point keeps
   its client id (`<session>-<install>-<seq>`), and the server dedupes on it.
   `<install>` is a random token kept with the app's data
   (`workday_install_v1`): after a reinstall or data clear mid-day the journal
   numbers fixes from 1 again, and a plain `<session>-<seq>` then repeated uids
   the server already held — the real module's unique index would discard
   those fixes as duplicates (found in the 2026-09-14 Android E2E).
3. **Drain (every 15 s while the process lives, on resume/pause, before a visit
   ends):** journal → persistent queue (SharedPreferences), `logged_at`
   converted to server time with `ServerClock`; visit-stamped fixes also go to
   the visit trail buffer; journal acknowledged by sequence number.
4. **Sync (every 60 s, on reconnect, on resume, at 20 queued points):** create
   the server session if needed (looked up by client uid first), upload points
   oldest first in batches of 100, then — only once none are left — complete
   the session. A lost response marks points "maybe sent"; they are re-sent and
   recognised by uid. Refused points are isolated one by one; a point refused
   for good is dropped and reported.
5. **Restart:** `HomeShell` calls `WorkdayTracker.restore`: resumes the day open
   on the device (restarting capture if the system stopped it), adopts a day
   open on the server, stops stray capture when no day is open.
6. **End work day:** capture stopped first, journal drained, end point queued
   with a fresh fix, then synced and completed. Offline, the completion stays
   queued and finishes on the next sync.
7. **Logout:** capture stops, recorded points are pushed; the day stays open on
   the server and resumes on the next sign-in.

## 4. Android

- `WorkdayLocationService` — `foregroundServiceType="location"`, not exported,
  ongoing low-importance notification "Workday tracking active / Location
  tracking is currently running" (localised) that opens the app, `START_STICKY`.
  Fused provider on Android 12+, otherwise GPS + network.
- Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` (targetSdk 35).
  `ACCESS_BACKGROUND_LOCATION` is not requested: the service is always started
  from the foreground, which the while-in-use grant covers.
- Play Console: foreground service declaration with video, data safety and
  disclosure text in
  [store/play/location-and-foreground-service-declarations.md](../store/play/location-and-foreground-service-declarations.md).

## 5. iOS

- `ios/Runner/WorkdayLocation.swift`, registered in `AppDelegate`: the same
  method channel (`net.digitalharbor.visits/workday_location`: `start`,
  `stop`, `setVisit`, `status`, `read`, `ack`, plus `authorization`,
  `requestAlways`, `requestFullAccuracy`) and the same journal line format as
  Android, so the Dart side is shared.
- `CLLocationManager`: best accuracy, `distanceFilter` = 5 m,
  `activityType = .other`, `pausesLocationUpdatesAutomatically = false`,
  `allowsBackgroundLocationUpdates = true`,
  `showsBackgroundLocationIndicator = true`; on iOS 17+ a
  `CLBackgroundActivitySession` is held while capturing.
- `Info.plist`: `UIBackgroundModes` includes `location`;
  `NSLocationWhenInUseUsageDescription`,
  `NSLocationAlwaysAndWhenInUseUsageDescription` and
  `NSLocationTemporaryUsageDescriptionDictionary` (`WorkdayRoute`), localised in
  `en.lproj` / `ar.lproj`.
- **While Using** is enough: capture started in the app continues in the
  background and with the screen locked (blue indicator). **Always** (asked
  once, after the disclosure) additionally runs significant-change monitoring,
  so iOS relaunches the app in the background after it terminated it, and
  `resumeIfActive()` restarts capture from the stored config before Flutter is
  up. iOS does not relaunch an app the user force-quit; capture resumes when it
  is opened again (the journal and queue survive).
- Journal in `Application Support/workday/workday_fixes.jsonl`, file protection
  "until first user authentication" (writable while locked), excluded from
  backup.
- Permission changes while capturing: revoked → updates stop, the day stays
  open, the bar shows "tracking paused" with Retry; granted again → capture
  resumes. Precise Location off → a temporary full-accuracy request with the
  `WorkdayRoute` purpose; still reduced → Start is refused with a Settings
  button.
- **Not verified on a device or simulator** (no macOS in this environment):
  see the report / RELEASE.md checklist for the tests that need an iPhone.

## 6. Today's Route

`RoutePage` reads today's work-day session(s) and all their points from the
server (`WorkdayRouteCubit`, refreshed whenever the tracker lands points) and
draws: the whole day in slate, each visit's stretch over it in its own colour,
a numbered pin where each visit begins, the work-day start marker, and the end
flag (or the current position while the day is open). The list shows points,
distance, time span and each visit (opening its own `/api/visit/track` trail).
Without a work day for today it falls back to the per-visit trails.

The lines are road-matched (§7); a **Roads / Raw GPS** switch on the map
shows either, and the map can be zoomed and dragged. Markers always sit on the
recorded fixes; distances are computed from the recorded fixes.

## 7. Road matching (display only)

```
recorded GPS fixes (server, unchanged) → RouteMatcher → OSRM /match → drawn line
```

- **Never stored, never sent back.** `RouteMatcher` only derives a line to draw.
  The fixes on the server — and the markers, distances and point lists in the
  app — are the recorded coordinates.
- **Provider.** The map is OpenStreetMap (`flutter_map` raster tiles), so matching
  uses OSRM's `match` service on the same OSM road network
  (`lib/core/map_matching/osrm_map_matcher.dart`). Input is the trace itself in
  recorded order — not directions between the first and last point — with each
  fix's accuracy as its search radius (8–40 m), relative timestamps, heading when
  moving ≥ 3 m/s, `gaps=split`. No user, employee or device identifier is sent.
- **Only believable matches.** Per pair of consecutive fixes the matched road
  path is used only if both fixes snapped within max(20 m, 1.5 × accuracy)
  (≤ 60 m), the path is ≤ 2 × straight distance + 60 m, has no U-turn, and
  implies ≤ 70 m/s. Otherwise that stretch is drawn straight between the
  recorded fixes. Movement off the road network is never forced onto a street.
- **Fallback.** Offline, rate limited (429), server error, `NoMatch`, or no
  server configured: the raw line is drawn; the map is never empty. After a
  transient failure the service is left alone for 1 minute.
- **Cost and caching.** A trace is split into chunks sharing their boundary
  fix, sized to the server's trace limit: 90 fixes for a self-hosted server
  (`MAP_MATCHING_MAX_POINTS` to change), 10 on the public demo server. A
  `TooBig` answer is retried as two halves. Each chunk is keyed by a hash of
  its fixes + service + algorithm version and cached in memory and in
  `<app support>/route_match_v1/` (30 days, ≤ 1500 files). Requests are
  serialised ≥ 1.1 s apart. The cache is deleted on logout.
- **Where.** Today's Route, the visit trail page (with the switch; raw fixes
  stay visible as dots) and the visit detail map card.
- **Configuration.** `--dart-define=MAP_MATCHING_URL=https://osrm.company`
  (release workflow: repository variable `MAP_MATCHING_URL`),
  `MAP_MATCHING_PROFILE` (default `driving`), `MAP_MATCHING_MAX_POINTS`.
  **Release builds** use only an explicitly configured HTTPS URL and refuse the
  public demo servers (`AppEnvironment.resolveMapMatchingUrl`, and `release.yml`
  fails); without one they hide the switch and draw raw GPS. Debug/profile
  builds default to `router.project-osrm.org` for development. The production
  server's requirements and deployment kit:
  [MAP_MATCHING_DEPLOYMENT.md](MAP_MATCHING_DEPLOYMENT.md) — **not deployed yet**.

## 8. Permissions and disclosure

1. First tap on **Start work day** (and again if `WorkdayCubit.disclosureKey`
   is bumped): `WorkdayDisclosureDialog` — what is collected, background and
   locked screen, when it stops, offline storage, road matching, the Android
   notification / the iOS "Always" choice. **Not now** requests nothing.
   The same dialog is shown before recording resumes for a day **restored**
   on an install that has not accepted it (`WorkdayTracker.restore`'s
   `beforeCapture`, passed by the home shell): a day started on another
   device, or a reinstall mid-day. The disclosure comes before the location
   permission check, and while it is open — or after it was declined — no
   app resume restarts capture (`_consentHeld` blocks `_ensureNativeRunning`).
   Declining keeps the day open but not recording; **Retry** on the bar shows
   the dialog again. Found in the 2026-09-14 Android E2E on a clean install:
   before this, capture started behind the dialog.
2. Location permission (While Using) through geolocator. Denied → message;
   permanently denied → Settings; location services off → message.
3. Approximate only → iOS temporary full accuracy request; still approximate →
   refused with a Settings button (a route cannot be recorded at kilometre
   accuracy).
4. Android 13+: notification permission (so the tracking notification is
   visible; capture works without it).
5. iOS, While Using granted: "Always" requested once; declining changes
   nothing else.
