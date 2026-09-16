# App Store Connect — iOS App 1.0, English (U.S.)

Copy-paste values for the "iOS App Version 1.0" page.

---

## Promotional Text (170 max)

```
Log every customer visit with a GPS-verified start and end and the route of the visit, get approvals fast, and keep working when the network drops.
```

## Keywords (100 max — comma separated, no spaces after commas)

```
field service,sales rep,visit tracking,check-in,visit report,GPS proof,merchandising,CRM
```

> Don't repeat the app name or anything already in the title — Apple indexes those
> separately, so repeating them wastes the 100 characters.

## Description (4000 max)

```
Field Visits is a work tool for reps and technicians who visit customers, and for the managers who review those visits. Every visit is recorded with where and when it started and ended and the route taken during the visit, so the visit report stops being manual work and becomes data.

KEY FEATURES

Daily visit schedule
An ordered list of today's visits with customer details, address, phone number, and notes from the previous visit.

GPS-verified visit start and end
The app captures your coordinates the moment you start a visit and the moment you end it, and measures the distance between you and the customer's registered location — so it is clear whether the visit actually happened on site.

Visit route
While a visit is in progress, the app records its route and shows it on the map, drawn along the roads where road matching is available.

Customer map
See your customers in a list or on the map, and call, email or get directions in one tap.

Approval workflow
The rep submits the visit for review; the manager approves it or sends it back with a note. Every step is stamped with its time and its author.

Push notifications
Get alerted when a visit is assigned to you, approved, or returned for changes.

Works offline
Actions taken while the network is down are stored on the device and sent automatically once the connection returns, so no visit is lost to poor coverage.

Reports and dashboard
Completed visits, average visit duration, and on-site compliance, shown daily and weekly.

Full Arabic and English
A bidirectional interface with a dark mode that is easy on the eyes.

LOCATION AND PRIVACY

The app uses your device's location only for customer visits: once when you start a visit, once when you end it, and to record the route while the visit is in progress. Route recording continues in the background and while the screen is locked, but only until you end the visit or sign out; nothing is recorded before a visit starts, between visits or after it ends. Locations are stored on the phone until they reach your company's system. You can decline the location permission, but visit locations and routes will not be recorded without it. Continued use of GPS in the background can decrease battery life.

IMPORTANT

This is an enterprise app that works with your company's system. You need sign-in credentials issued by your employer to use it; the app does not offer independent account registration.
```

## Other fields on this page

| Field | Value |
|---|---|
| Version | `1.0` |
| Copyright | `2026 Digital Harbor` |
| Support URL | **required** — a real, reachable page (e.g. `https://digital-harbor.net/field-visits/support`) |
| Marketing URL | optional — leave empty rather than pointing at a 404 |
| Routing App Coverage File | leave empty — that is for turn-by-turn navigation apps only |
| App Store Version Release | **Manually release this version** |

## App Review Information

> **2026-08-06:** submitting demo credentials without the **server address** got the
> app rejected under guideline 2.1 — the reviewer could not get past the "Connect
> your server" screen. The Notes below must always carry the server URL + database
> name. Full reply and checklist: [apple-review-2026-08-06.md](apple-review-2026-08-06.md).

**Sign-In required:** tick it. Provide a working demo account on the live backend
with a few clean visits already seeded — including several in the **Approved** state,
because Start Visit moves a visit out of that state — and keep it working until the
app is approved; review can re-test weeks later. Credentials go only into the
Sign-In Information fields of App Store Connect, never into this repository.

**Notes:** the live text now lives in
[apple-review-2026-08-06.md § 4-ب](apple-review-2026-08-06.md) — it carries the server
address and database name, without which the reviewer cannot get past the first screen,
and its LOCATION USE section is the visit-only background location text below. The
draft below is kept only as background.

```
Field Visits is an enterprise field-service app used by employees of companies that run our backend. Sign-in credentials are issued by the employer; there is no public self-registration. The review account (provided in the Sign-In Information fields of this submission) is seeded with sample customers and visits so every screen can be reached.

HOW TO REVIEW
1. Sign in with the review account from the Sign-In Information fields.
2. The Visits tab lists the day's visits. Open any visit in the "Approved" state.
3. Tap Start visit. The app shows a short location disclosure (first time only), requests While Using the App location access, records your coordinates, and shows your distance from the customer's registered location.
4. Tap End visit (enter an outcome) to close the visit, then use Submit to send a visit for approval.
5. The same account has manager rights: open the Dashboard and Analytics tabs, and approve a submitted visit.

LOCATION USE
The app uses location only for customer visits: one position when the employee taps "Start visit" on an approved visit, one when they tap "End visit", and the GPS trail of the visit while it is in progress. No location is collected before a visit starts, between visits or after it ends.
The app declares the "location" background mode for that trail only. Recording starts from the foreground once the server confirms the visit has started, and continues while the app is in the background or the device is locked, with the blue location indicator shown. It stops immediately when the employee taps "End visit" or signs out. While Using the App authorization is sufficient; the app never asks for Always. The trail is uploaded to the employer's own server for the visit report.
To see it: start an approved visit, press Home or lock the device (and move a short distance if possible) — the blue location indicator stays visible — then reopen the app to see the visit's trail. Tap "End visit": the indicator disappears and recording stops.

Please contact us at the address above if any step cannot be completed; we can reset the demo data on request.
```
