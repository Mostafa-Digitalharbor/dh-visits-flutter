# Action needed: deploy `dh_workday_tracking` to the mobile test server

**To:** Odoo Developer
**From:** Flutter Mobile Dev
**Date:** 2026-09-21
**Re:** `MOBILE_APP_TRACKING_ISSUE.md`

## The one ask

Install **your existing** `dh_workday_tracking` module — the same one running on
`dhv19` — on the server the mobile app is tested against:

- **Server:** `https://visits-dhh.odoo.com`
- **Database:** `shawkialaddin-visits-dh-live-37916914` (Odoo 19.0+e)

**There is no new backend work in this request.** No new endpoints, no new
models, no new fields, no changes to the contract you documented. Deploy what
you already have and this closes.

If you would rather we test against `dhv19` instead, send its URL, database
name and a test login and we will point the app there — either option works.

## Why: the routes are not on that server

Verified on 2026-09-21 and re-checked on 2026-09-24 with a valid `admin`
session on `visits-dhh.odoo.com` — unchanged.
All six routes the app uses answer 404:

```
POST /api/workday/active          -> 404 NOT FOUND
POST /api/workday/start           -> 404 NOT FOUND
POST /api/workday/get             -> 404 NOT FOUND
POST /api/workday/log_locations   -> 404 NOT FOUND
POST /api/workday/end             -> 404 NOT FOUND
POST /api/workday/track           -> 404 NOT FOUND

POST /api/visit/my                -> 200        (dh_visit_management is installed)
```

The module is not merely uninstalled — it is not on the addons path at all:

```python
env['ir.module.module'].search([('name', 'like', 'dh_')]).mapped('name')
# ['delivery_dhl_rest', 'dh_visit_management', 'delivery_dhl']
```

## Please deploy your `dhv19` copy, not the one in our repo

We keep a copy of the module at `backend/dh_workday_tracking/` in the mobile
repository, but **it is older than yours in one way that matters**: it does not
add the **Continuous GPS Tracking** section to the visit form. It only ships
the `dh.work.session` views and the **Employees → Work Days (GPS)** menu.

Checked on `visits-dhh` today, the visit form currently has:

- a **Start / End Tracking** page — present, from `dh_visit_management`; it
  already shows `location_log_ids` (the visit's own trail) and
  `tracked_distance_km`
- **Continuous GPS Tracking** — **not present**

So if our copy is deployed, the data will be correct but the section from your
report will still be missing. Use your version. Ours is only a fallback if
yours is lost, and then the visit-form view needs adding.

## The install will not fail — dependencies checked

`"depends": ["hr", "dh_visit_management"]` — both installed. Every external
reference the module's data files make already resolves on that database:

| Reference | Status on `visits-dhh` |
|---|---|
| `dh_visit_management.group_visit_user` | exists (res.groups id 33) |
| `dh_visit_management.group_visit_manager` | exists (id 34) |
| `dh_visit_management.group_visit_admin` | exists (id 36) |
| `base.group_system` | exists (id 4) |
| `hr.menu_hr_root` (parent of the new menu) | exists |

One runtime note: `_current_employee()` raises *"Your user is not linked to an
employee"* when the caller has no `hr.employee`. Any account used for testing
needs one linked.

## Routes the app calls

All six already exist in the module — listed only so nothing gets stripped
during deployment. **Do not add anything beyond them.**

| Route | Used by the app for |
|---|---|
| `POST /api/workday/start` | open the work day |
| `POST /api/workday/active` | recover an open day after a restart — **also the probe the app uses to decide whether this server has the feature at all** |
| `POST /api/workday/get` | look a day up by `client_uid` before retrying a Start |
| `POST /api/workday/log_locations` | upload GPS batches |
| `POST /api/workday/end` | close the work day |
| `POST /api/workday/track` | read a day's route back for the in-app map |

`/api/workday/active` matters most: the app probes it first and, on a 404,
silently falls back to the older `x_dh_work_*` models. A partial deployment
that omits it looks to the app exactly like "the module is not there".

## How to confirm it worked

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -X POST https://visits-dhh.odoo.com/api/workday/active \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","params":{}}'
```

Anything other than `404` means the routes are live (`100 / Odoo Session
Expired` without a session cookie is the expected answer and is fine).

Tell us when it is in and we will re-run the mobile suite against the real
routes and confirm all seven acceptance criteria from your document.

## The mobile side is done and already verified

Run end to end on an Android emulator against `visits-dhh.odoo.com` on
2026-09-21. Because the routes were unavailable, the app used its fallback
store — same app code, same payloads, same field values, only the transport
differs. One recorded work day, 13 points:

```
work day   : opened 18:06:56 -> closed 18:23:21, with start and end coordinates
  18:06:56   24.71360,46.67530   visit=-     source=start
  18:08:15   24.71418,46.67597   visit=-     source=track    (before the visit)
  …
  18:13:40   24.71737,46.67917   visit=308   source=track    (during visit 308)
  18:13:50   24.71817,46.67997   visit=308   source=track
  18:13:55   24.71897,46.68076   visit=308   source=track
  18:14:06   24.71900,46.68080   visit=308   source=track
  18:20:27   24.71977,46.68157   visit=-     source=track    (after the visit)
  18:20:37   24.72057,46.68237   visit=-     source=track
  18:23:21   24.72060,46.68240   visit=-     source=end

13/13 unique client_uid (no duplicates), ordered by logged_at,
4 points linked to visit 308, 9 outside any visit.
```

The same four fixes were also filed on visit 308's own trail
(`dh.visit.location.log`, 6 points, 0.361 km) — one GPS capture feeds both
routes, so the two can never disagree.

Once the module is live, those `visit=308` points are what will appear under
**Start / End Tracking → Continuous GPS Tracking** on the visit form, and the
untagged ones under **Employees → Work Days (GPS)**.
