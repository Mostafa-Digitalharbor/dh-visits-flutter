# Google Play — location and foreground service declarations

Answers for the Play Console, derived from what the app actually does
(AndroidManifest.xml, `WorkdayLocationService.kt`, docs/WORKDAY_TRACKING.md).
Re-check this file whenever a permission, the service type or the disclosure
text changes.

---

## 1. What the build declares

| Manifest entry | Why |
|---|---|
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Visit start/end, visit routes, live sharing while in use, work-day route |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | `WorkdayLocationService`, `foregroundServiceType="location"` (required from Android 14 / targetSdk 34) |
| `POST_NOTIFICATIONS` | Push notifications; makes the ongoing "Workday tracking active" notification visible on Android 13+ |

**Not declared:** `ACCESS_BACKGROUND_LOCATION`. The service is only ever
started while the app is in the foreground (the Start tap, or the app being
reopened during an open work day), which the while-in-use grant covers. Do not
add it: it would require the separate background-location declaration and
review, for access the app does not need.

---

## 2. App content → Foreground service permissions

Play asks this of every app targeting Android 14+ that declares a
`FOREGROUND_SERVICE_*` type permission.

**Foreground service type:** Location

**Use case / task description** (paste):

```
Field employees start a work day in the app ("Start work day"). While the work
day is active, the app records the employee's route with a foreground service
of type location: about one GPS position every 5 seconds while moving, stored
on the device and uploaded to the employer's own server. The route covers the
whole working day, including travel between customer visits, and is used for
the employer's work-day and visit reports. The service runs only between the
user's "Start work day" and "End work day" actions (or sign-out), shows an
ongoing notification "Workday tracking active - Location tracking is currently
running" for its whole duration, and stops immediately when the user ends the
work day.
```

**Is the task started by the user?** Yes — explicit "Start work day" button.

**Impact if the task is deferred or interrupted** (paste):

```
The work-day route would have gaps: the positions of the employee's travel
while the phone is in a pocket or the screen is locked would never be
recorded, so the day's route and the time spent between visits could not be
reported. Recording cannot be deferred because positions are only meaningful
at the moment they are taken.
```

**Video link:** required. Record (screen capture, unlisted YouTube or Drive
link) on a real device:
1. Sign in → the work-day bar shows "Work day not started".
2. Tap **Start work day** → the in-app disclosure appears → **Agree and
   continue** → the location permission prompt → allow while using.
3. The "Workday tracking active" notification appears.
4. Press Home, lock the screen, move (or drive a short route), unlock.
5. Open the app → Today's Route shows the movement recorded meanwhile.
6. Tap **End work day** → confirm → the notification disappears.

---

## 3. App content → Location permissions (background location)

**Not required.** That declaration applies to apps that request
`ACCESS_BACKGROUND_LOCATION`, which this app does not. If Play still flags
background access (it inspects behaviour, not only the manifest), answer with
the task description above and the video, and point out the foreground service
with its ongoing notification.

---

## 4. Prominent disclosure (User Data policy)

Play requires an in-app disclosure, shown before the runtime permission
prompt, when location is used in a way users might not expect — continuing in
the background qualifies. Implemented in
`lib/features/workday/view/workday_disclosure_dialog.dart`, shown before the
first Start work day (and again if the text version changes), with an
explicit **Agree and continue** / **Not now**. Text (English; Arabic in
`app_ar.arb`):

> **Work-day location tracking**
>
> While your work day is active, Visits collects this device's precise
> location — also when the app is closed or in the background and while the
> screen is locked — to record your work-day route and your customer visits
> for your employer.
>
> Tracking starts only when you tap Start work day, and stops when you tap End
> work day or sign out.
>
> Locations are kept on this phone until they reach your company's server. To
> draw routes along roads, recorded points may be sent to your company's
> map-matching service.
>
> A notification stays visible for as long as tracking runs.

Nothing is collected and no permission is requested if the user taps **Not
now**.

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
| Device or other IDs | Yes (push token) | No | No | Required | App functionality |

"Shared: No" — the employer's backend, the company-controlled road-matching
server, Sentry and Firebase act on behalf of the developer/employer (service
providers), which Play does not count as sharing.

- Data encrypted in transit: **Yes**.
- Users can request deletion: **Yes** (through their employer's administrator).

The Data safety form has no "background" question; background collection is
covered by the privacy policy, the foreground service declaration and the
in-app disclosure.

---

## 6. Privacy policy consistency checklist

- [ ] Hosted policy `https://digitalharbor.com.sa/ar/visit-app` has the
      "Background location during an active work day" section of
      docs/PRIVACY_POLICY.md. **Checked 2026-09-14: not yet** — the page still
      says "No background tracking" and has no real effective date.
- [ ] It names the notification, the Start/End work day limits, offline
      storage, and road matching by a company-controlled service.
- [ ] Store listing text no longer says "no background tracking"
      (store/play/listing-ar.md).
- [ ] The disclosure text above matches the build being submitted.
