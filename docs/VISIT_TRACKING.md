# Visit-only location tracking

How the app collects location since 2026-09-16: **only for customer visits**.
The former work-day route, live location sharing, the manager "nearby
employees" radar and the hr.attendance mirror of Start/End are gone (see
[WORKDAY_TRACKING.md](WORKDAY_TRACKING.md) — obsolete). Server contract:
[API.md](API.md) §4.6–4.7. User-facing wording:
[PRIVACY_POLICY.md](PRIVACY_POLICY.md) and
[store/play/location-and-foreground-service-declarations.md](../store/play/location-and-foreground-service-declarations.md).

## 1. What is collected, and when

| Moment | Data | Endpoint |
|---|---|---|
| Create visit | nothing — the app sends no coordinates on create (the API accepts optional `latitude`/`longitude`) | `/api/visit/create` |
| Start Visit on an `approved` visit | one fresh fix | `/api/visit/start` → first trail point (`source: start`) |
| While the visit is `in_progress` | trail points | `/api/visit/log_locations` (`source: track`) |
| End Visit | one fresh fix | `/api/visit/end` → last trail point (`source: end`) |

Trail point: `latitude`, `longitude`, `logged_at` (real fix time, converted to
server time with `ServerClock`), `accuracy`, `altitude`, `speed`, `heading`,
`device_id` (the same stable id the FCM registration sends: a SHA-256 of
`ANDROID_ID` on Android, a Keychain-held random id on iOS — both survive a
reinstall).

Nothing is collected before Start, between visits, after End, or for a whole
day. There is never more than one visit being tracked.

## 2. Lifecycle

1. **Start (online).** The app acquires a fix and calls `/api/visit/start`.
   Tracking starts **only after the server answers `in_progress`**: the visit
   is marked active on the device, then native capture is started for that
   visit id (from the foreground, permission already granted).
2. **Start (offline).** Start is queued in the pending-actions queue with its
   fix. Tracking starts only once the queued Start has been **accepted by the
   server** and **no End for that visit is queued**. A Start the server
   refuses never starts tracking.
3. **Capture.** The native layer (§5, §6) writes every accepted fix to its
   journal; Dart drains it into the upload buffer (§4).
4. **End.** In this order: stop native capture (the config is deactivated
   first, so nothing is recorded after this point) → drain the native journal
   → flush the buffer → call `/api/visit/end` with a fresh fix. Capture is
   restarted **only if** the server refuses End **and** still reports the
   visit `in_progress`. An End queued offline leaves capture stopped; buffered
   points upload later.
5. **Restart / resume** (app start, sign-in). Capture is restored only if the
   server (`/api/visit/my`) reports the visit still `in_progress` and no End
   for it is queued; when offline, the local active-visit marker decides and
   the server is asked again as soon as the network is back. Until that first
   answer, an app resume does not bring capture back from the marker alone.
   When the server shows the visit ended elsewhere, fixes taken after its
   `end_datetime` are discarded on the device instead of uploaded. Otherwise any
   stray capture is stopped and the marker cleared. While recording, the visit
   is also re-checked (`/api/visit/get`, throttled) when the app returns to the
   foreground, after a refused batch, and whenever its detail screen is read;
   anything but `in_progress` (done, cancelled, rescheduled) stops capture.
6. **Logout.** Capture stops immediately and what was recorded is uploaded
   while the session is still valid. Anything left stays keyed to the
   signed-out account and is uploaded only under that account.
7. **Push notifications** can only **stop** tracking (a push about the visit
   being recorded triggers the re-check above); they never start it.
8. **After End** no fix can enter the buffer: the native config is
   deactivated before the service stops and re-read for every fix, and Dart
   additionally discards any journal entry stamped after the local end time.
9. **Permission revoked** during a visit: Android kills the process and the
   restarted service refuses to run (`SecurityException`, caught); the visit
   stays `in_progress` on the server and the trail has a gap. The active-visit
   bar shows "Route paused" with a Resume action; capture restarts when access
   is granted and the app is in the foreground.

## 3. Sampling

The same rules run on Android and iOS:

| Rule | Value |
|---|---|
| Requested update interval | 5 s, high accuracy |
| Movement needed to keep a fix | ≥ max(10 m, min(accuracy / 2, 15 m)) from the last kept fix |
| Minimum spacing between kept fixes | 4 s, unless the fix is ≥ 15 m away |
| Accuracy accepted | ≤ 50 m; relaxed to ≤ 100 m after 30 s without a kept fix |
| Ordering | a fix older than the last kept one is dropped |

While moving that is roughly one fix every 5 s; standing still records
nothing. The last kept fix is persisted, so a restarted capture does not
record the cached position again.

## 4. Buffer and upload (Dart, `VisitTrailTracker`)

- **Drain:** journal → buffer every 15 s while the process lives, and on
  resume, pause and before End. Fixes are acknowledged to the native layer by
  **sequence number**, which removes them from the journal only after they are
  safely in the buffer.
- **Buffer:** app-private storage (SharedPreferences), keyed by **visit id and
  signed-in account**, capped at **4000 points** (oldest discarded beyond
  that).
- **Flush:** every 60 s, at 20 buffered points, on reconnect, on resume and
  before End; batches of **≤ 100** points per `/api/visit/log_locations` call,
  one visit per call. A flush waits while that visit's Start is still queued
  (the server would refuse the batch).
- **Result handling:** points not listed in `rejected[]` are removed.
  `rejected[].index` maps to the batch sent:
  - dated in the future (device clock ahead) → kept and retried, **at most 5
    times**;
  - any other refusal (outside the visit's start–end window, invalid
    coordinates, …) → dropped at once and reported to the user.
- **Whole batch refused** (a `UserError`/`AccessError` for the call) → kept and
  retried at most 5 times, then dropped and reported.
- **Transport and session failures** (offline, timeout, 5xx, expired session)
  keep the batch for the next flush without using up an attempt.
- **Journal sequence:** Dart remembers the last sequence it took; a replay
  after a lost acknowledgement is skipped, and a journal whose newest entry is
  older than that (native storage reset) is taken in from the start.
- **Late uploads** are normal: points recorded offline during the visit are
  sent after End with their original `logged_at`; the server accepts them
  while they fall inside the visit's start–end window.
- Points are deleted from the device once uploaded or permanently refused.

## 5. Native bridge

Method channel `net.digitalharbor.visits/visit_location`, same contract on
both platforms:

| Method | Purpose |
|---|---|
| `start` | activate capture for a visit id with the sampling config and notification text |
| `stop` | deactivate the config, then stop updates / the service |
| `status` | whether capture is active, and for which visit |
| `read` | return up to N journal lines, oldest first |
| `ack` | drop journal lines up to and including a sequence number |

Journal: `visit_fixes.jsonl`, append-only JSON lines (sequence, visit id, fix
fields), synced to disk on every write, before anything depends on the network
or on a Flutter engine.

## 6. Android

- `net.digitalharbor.visits.visittracking`: `VisitLocationService` (writer),
  `VisitLocationStore` (config in SharedPreferences + journal in the app's
  private files directory), `VisitLocationChannel` (reader).
- `VisitLocationService`: `foregroundServiceType="location"`, not exported,
  ongoing low-importance notification **"Visit tracking active"** (localised,
  opens the app), shown only while a visit is being recorded. Fused /
  high-accuracy request on Android 12+, GPS + network below.
- `START_STICKY`: after the system kills the process, the service resumes
  **only while a visit is still marked active**, and gives up quietly where
  the OS refuses to start a location service from the background; Dart
  restarts capture when the app is next opened during the visit. A
  force-stopped app is never restarted.
- Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`.
  **`ACCESS_BACKGROUND_LOCATION` is not requested**: the service is always
  started from the foreground, which the while-in-use grant covers.
- Excluded from cloud backup (`data_extraction_rules.xml`).

- `targetSdk 36` (Play requirement since 2026-08-31). Observed on an Android 16
  emulator: after the system killed the process during a visit, the sticky
  service was restarted and kept journalling fixes without the UI (uploaded on
  the next app open); OEM behaviour may differ, which is why Dart restores
  capture on every app open.

## 7. iOS

- `ios/Runner/VisitLocation.swift`, registered in `AppDelegate`, same channel
  and journal format as Android.
- `CLLocationManager`: best accuracy, `distanceFilter` from the config,
  `pausesLocationUpdatesAutomatically = false`,
  `allowsBackgroundLocationUpdates = true`,
  `showsBackgroundLocationIndicator = true`; on iOS 17+ a
  `CLBackgroundActivitySession` is held while capturing.
- `Info.plist`: `UIBackgroundModes` contains `location`. Capture is always
  started from the foreground, so **"While Using the App" is sufficient**; the
  app never asks for "Always" (`NSLocationAlwaysAndWhenInUseUsageDescription`
  is still declared: `geolocator_apple` links the Always API, and it lets
  Settings offer "Always"). The blue location indicator is shown while a
  visit is recorded.
- If the user grants "Always" in Settings, significant-change monitoring runs
  alongside, so iOS may relaunch an app it terminated during an active visit;
  `resumeIfActive(relaunchedForLocation:)` continues from the stored config
  only for such a location relaunch. On a normal launch nothing restarts
  natively: Dart asks the server first. A force-quit app is not relaunched;
  Dart restarts capture when the app is opened again while the visit is still
  `in_progress`.
- Journal in `Application Support/visit_tracking/visit_fixes.jsonl`, file
  protection "until first user authentication" (writable while locked),
  excluded from backup; capture state in the app's own `UserDefaults`
  (privacy manifest reason `CA92.1`).
- Precise Location off → a temporary full-accuracy request
  (`NSLocationTemporaryUsageDescriptionDictionary`, purpose key
  `VisitRoute`); with reduced accuracy
  most fixes fail the accuracy rule (§3).

## 8. Disclosure and permissions

1. Before the **first Start Visit** (and again when the disclosure version is
   bumped) the app shows an in-app prominent disclosure: what is collected,
   that it continues in the background / with the screen locked during the
   visit, that it stops at End Visit or sign-out, and where it goes (the
   employer's server; the company's map-matching service for road-drawn
   trails). Declining leaves the visit unstarted (a visit is only started with
   its route recorded); a visit restored without agreement shows the
   disclosure again and is not recorded until the user agrees.
2. Location permission (while in use). Denied → message; permanently denied or
   location services off → Settings.
3. Android 13+: notification permission, so the tracking notification is
   visible (capture works without it).

## 9. Road-matched trails (display only)

- Optional. Only when a map-matching URL is configured
  (`MAP_MATCHING_URL`); otherwise the recorded trail is drawn as is and nothing
  is sent. Deployment: [MAP_MATCHING_DEPLOYMENT.md](MAP_MATCHING_DEPLOYMENT.md).
- Only the recorded points of **the one visit being displayed** are sent to
  OSRM `/match` (coordinates, accuracy radius, heading while moving, relative
  timestamps) — no identifiers, no session. There is no full-day matching.
- The raw GPS stays authoritative: markers, distances and point lists use the
  recorded fixes; implausible matched stretches are drawn straight; any
  failure falls back to the raw line.
- Matched lines are cached on the device for up to 30 days and deleted on
  logout. Release builds refuse public demo OSRM servers.

## 10. Upgrade from a work-day build

On start-up `VisitTrailTracker` deletes every key in
`StorageKeys.legacyLocationKeys` (the `workday_*` preferences, including queued
work-day points, and the retired active-visit key). None of that data is read
or uploaded. The app never calls `/api/workday/*` and never writes
`x_dh_work_*` / `dh.work.*` models.

## 11. Manual verification (per release)

- [ ] Android device: Start an approved visit → disclosure → permission →
      notification appears only after the server confirms → Home + lock +
      move → reopen: trail grew → End Visit → notification gone, no new
      points.
- [ ] Airplane mode: Start offline → no notification until the queued Start
      is accepted; End offline → buffered points upload later with original
      times.
- [ ] Kill the process during a visit → capture resumes (at the latest when
      the app is reopened) only while the visit is still `in_progress`.
- [ ] Logout during a visit → capture stops at once.
- [ ] iPhone: same flow with the blue indicator; no "Always" prompt ever.
- [ ] No location activity before Start, between visits, or after End.
