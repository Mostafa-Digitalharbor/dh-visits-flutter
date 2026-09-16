# Google Play — location and foreground service declarations

Answers for the Play Console, derived from what the app does
(AndroidManifest.xml, `visittracking/VisitLocationService.kt`,
[docs/VISIT_TRACKING.md](../../docs/VISIT_TRACKING.md)). Re-check this file
whenever a permission, the service type or the disclosure text changes.

> **2026-09-16:** the work-day route (Start/End Work Day), live location
> sharing, the manager "nearby employees" radar and the hr.attendance mirror
> were removed from the app. Location is now collected **only for customer
> visits**. Earlier answers that mention a work day are obsolete — do not
> reuse them.

---

## 1. What the build declares

| Manifest entry | Why |
|---|---|
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Start Visit / End Visit positions and the GPS trail of a visit in progress (while-in-use grant only) |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | `VisitLocationService`, `foregroundServiceType="location"` (the type permission is required from Android 14 / targetSdk 34) |
| `POST_NOTIFICATIONS` | Push notifications; makes the ongoing "Visit tracking active" notification visible on Android 13+ |

**Not declared:** `ACCESS_BACKGROUND_LOCATION`. The service is only started
while the app is in the foreground — right after the server confirms Start
Visit, or when the app is reopened during a visit that is still in progress —
which the while-in-use grant covers. Do not add it: it would require the
separate background-location declaration and review, for access the app does
not need.

---

## 2. App content → Foreground service permissions

Play asks this of every app targeting Android 14+ that declares a
`FOREGROUND_SERVICE_*` type permission.

**Foreground service type:** Location

**Use case / task description** (paste):

```
Records the GPS trail of a customer visit the employee started, while the
visit is in progress; stops when the visit ends.

Field employees open an approved customer visit and tap "Start Visit". Once
the employer's server confirms that the visit has started, the app starts a
foreground service of type location that records the route of that visit
(about one GPS position every few seconds while moving, nothing while
standing still). Positions are stored on the device and uploaded to the
employer's own server for the visit report. The service shows an ongoing
"Visit tracking active" notification for its whole duration and stops
immediately when the employee taps "End Visit" or signs out. No location is
recorded before Start Visit, between visits or after End Visit.
```

**Is the task started by the user?** Yes — the explicit "Start Visit" button
on a visit.

**Impact if the task is deferred or interrupted** (paste):

```
The visit's route would have gaps: positions taken while the phone is in a
pocket or the screen is locked during the visit would never be recorded, so
the route and distance of the visit could not be reported. Recording cannot
be deferred because positions are only meaningful at the moment they are
taken.
```

**Video link:** required (demo video still to be recorded). Record a screen
capture on a real device and share it as an unlisted YouTube or Drive link:
1. Sign in → open an **approved** visit.
2. Tap **Start Visit** → the in-app disclosure appears (first time) → accept →
   the location permission prompt → allow **while using the app**.
3. The visit moves to *In progress* and the "Visit tracking active"
   notification appears.
4. Press Home, lock the screen, move (walk or drive a short route), unlock.
5. Open the app → the visit's trail shows the movement recorded meanwhile.
6. Tap **End Visit** → the notification disappears; show that nothing is
   recorded afterwards (no notification, no new points on the trail).

---

## 3. App content → Location permissions (background location)

**Not required.** That declaration applies to apps that request
`ACCESS_BACKGROUND_LOCATION`, which this app does not. If Play still flags
background access (it inspects behaviour, not only the manifest), answer with
the task description and video above, and point out that background
collection happens only through the location foreground service, with its
ongoing notification, while a visit the user started is in progress.

---

## 4. Prominent disclosure (User Data policy)

Play requires an in-app disclosure, shown before the runtime permission
prompt, when location is used in a way users might not expect — continuing in
the background qualifies. The app shows it before the first **Start Visit**
(and again if the disclosure text version changes). It must state what is
collected, that collection continues in the background and with the screen
locked while the visit is in progress, that it stops at End Visit or sign-out,
and where the data goes. Suggested text (English; the shipped wording, and
its Arabic version in `app_ar.arb`, must say the same — verify against the
build before submitting):

> **Visit location tracking**
>
> While a customer visit you started is in progress, Visits collects this
> device's precise location — also when the app is in the background or the
> screen is locked — to record the route of that visit for your employer.
>
> Tracking starts only when you start a visit and stops when you tap End Visit
> or sign out. No location is collected between visits.
>
> Locations are kept on this phone until they reach your company's server. To
> draw a visit's route along roads, its recorded points may be sent to your
> company's map-matching service.
>
> A notification stays visible for as long as tracking runs.

The disclosure needs an explicit accept action; if the user declines, no
location is tracked.

---

## 5. App content → Data safety

| Data type | Collected | Shared | Ephemeral | Required | Purposes |
|---|---|---|---|---|---|
| Location → Precise location | Yes | No | No | Required | App functionality |
| Location → Approximate location | Yes | No | No | Required | App functionality |
| Personal info → Name, Email address, User IDs | Yes | No | No | Required | App functionality, Account management |
| App activity → Other user-generated content (visit notes) | Yes | No | No | Required | App functionality |
| Photos and videos → Photos | Yes | No | No | Optional | App functionality |
| Files and docs | Yes | No | No | Optional | App functionality |
| App info and performance → Crash logs, Diagnostics | Yes | No | No | Required | App functionality |
| Device or other IDs | Yes (push token, random per-install device id) | No | No | Required | App functionality |

"Shared: No" — the employer's backend, the company-controlled road-matching
server, Sentry and Firebase act on behalf of the developer/employer (service
providers), which Play does not count as sharing. OpenStreetMap tile servers
receive only map-tile requests for the visible map area, never the user's
position.

**Location, in plain terms:** collected only for customer visits — one
position at Start Visit, one at End Visit, and the GPS trail while the visit
is in progress. The trail keeps being collected in the background **only
during an active visit**, through the location foreground service, with the
while-in-use permission. Nothing is collected outside a visit.

- Data encrypted in transit: **Yes**.
- Users can request deletion: **Yes** (through their employer's administrator).

The Data safety form has no "background" question; background collection
during a visit is covered by the privacy policy, the foreground service
declaration and the in-app disclosure.

---

## 6. Privacy policy consistency checklist

- [ ] Hosted policy `https://digitalharbor.com.sa/ar/visit-app` carries the
      current docs/PRIVACY_POLICY.md (last updated 16 September 2026),
      including "Background location during an active visit". **Checked
      2026-09-16 again: not yet** — the page still says "No background
      tracking", still describes sharing live location "during the work day"
      and the nearby-employees map, and its effective date is still the
      "Replace with the date you publish this policy" placeholder. Publish
      docs/PRIVACY_POLICY.html there before submitting to either store.
- [ ] It names the notification, the Start Visit / End Visit limits, offline
      storage, and road matching by a company-controlled service.
- [ ] Store listing text describes visit-only location use
      (store/play/listing-ar.md) — no work day, live sharing or attendance.
- [ ] The disclosure text in the build matches § 4.
- [ ] The demo video (§ 2) was recorded on the build being submitted.
