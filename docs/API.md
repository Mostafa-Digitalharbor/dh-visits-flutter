# Visit Management — Mobile API

JSON API for the `dh_visit_management` Odoo add-on.

- **Base URL:** `https://visits-dhh.odoo.com`
- **Database:** `shawkialaddin-visits-dh-live-37916914`
- **Odoo:** 19.0 · **Add-on version:** 19.0.2.1.0

> Every example below was executed against this instance and the responses are
> copied verbatim from the live run.

---

## 1. Conventions

All `/api/visit/*` routes share the same shape:

| | |
|---|---|
| Method | `POST` (only) |
| Content-Type | `application/json` |
| Auth | `auth='user'` — a logged-in session cookie is required |
| Protocol | Odoo JSON-RPC 2.0 |

**Every request body** wraps your arguments in `params`:

```json
{ "jsonrpc": "2.0", "method": "call", "params": { "…your arguments…" } }
```

**Every response** wraps the result in `result`:

```json
{ "jsonrpc": "2.0", "id": null, "result": { "…" } }
```

### Four things that will bite you if you skip them

1. **Errors return HTTP 200.** A failure is *not* signalled by the status code —
   it comes back as `200` with an `error` key instead of `result`. Always branch
   on the presence of `error`, never on the HTTP status.
2. **Empty values are `false`, not `null`.** Odoo returns `false` for an unset
   relation, string or date (`"location": false`, `"partner_id": false`). Empty
   numbers come back as `0.0`. Decode defensively.
3. **Datetimes are UTC and naive — with two different formats.** You *send*
   `"2026-09-12 09:20:01"` (space separator) and you *receive*
   `"2026-09-12T09:20:01"` (ISO `T` separator). Neither carries a timezone
   suffix; both are UTC. Convert to local time for display yourself.
4. **Trailing state is authoritative.** Most write calls echo the resulting
   `state` — trust that over your local optimistic update.

### Error shape

```json
{
  "jsonrpc": "2.0", "id": null,
  "error": {
    "code": 0,
    "message": "Odoo Server Error",
    "data": {
      "name": "odoo.exceptions.UserError",
      "message": "The visit ended on 2026-09-12 09:55:04; a later position cannot be added.",
      "arguments": ["…"],
      "debug": "Traceback (most recent call last): …"
    }
  }
}
```

Show `error.data.message` to the user — it is already a human-readable,
translated sentence. Never show `debug`.

**Branch on `error.data.name`, not on `error.code`.** The code is not a reliable
discriminator — a `UserError` comes back as `0` while a session expiry is `100`.

| `error.data.name` | Meaning | What the app should do |
|---|---|---|
| `odoo.http.SessionExpiredException` | Not logged in / session died | Re-authenticate, then retry once |
| `odoo.exceptions.UserError` | Business rule refused the action | Show the message; do not retry |
| `odoo.exceptions.AccessError` | No rights on this record | Show the message; do not retry |
| `odoo.exceptions.ValidationError` | Field constraint violated | Show the message; fix input |

---

## 2. Authentication

### `POST /web/session/authenticate`

```json
{ "jsonrpc": "2.0", "method": "call",
  "params": {
    "db": "shawkialaddin-visits-dh-live-37916914",
    "login": "admin",
    "password": "2005"
  } }
```

Response (abridged):

```json
{ "result": {
    "uid": 2,
    "name": "Administrator",
    "username": "admin",
    "db": "shawkialaddin-visits-dh-live-37916914",
    "server_version": "19.0+e",
    "user_context": { "lang": "en_US", "tz": false, "uid": 2 }
} }
```

The response sets a **`session_id` cookie**. Persist it in your HTTP client's
cookie jar and send it on every subsequent call — that cookie *is* the auth.
There is no bearer token.

- `POST /web/session/destroy` logs out.
- When any call returns `SessionExpiredException`, re-run authenticate and retry.

> **Test credentials** above are for this dummy instance only. Do not ship them.

---

## 3. The visit object

Returned by `create`, `get` and `my`.

| Field | Type | Notes |
|---|---|---|
| `id` | int | |
| `name` | string | Reference, e.g. `VIS/2026/00052` |
| `visit_type` | `"project"` \| `"opportunity"` | |
| `project_id` | int \| `false` | Set when `visit_type = "project"` |
| `opportunity_id` | int \| `false` | Set when `visit_type = "opportunity"` |
| `partner_id` | int \| `false` | Customer, auto-filled from the target |
| `partner_name` | string | |
| `employee_id` | int | The employee the visit is *for* |
| `employee_name` | string | |
| `scheduled_datetime` | ISO datetime | |
| `purpose` | string | |
| `location` | string \| `false` | |
| `state` | enum | See lifecycle below |
| `visit_approval_state` | `pending` \| `approved` \| `rejected` | Track 1 |
| `attendee_approval_state` | `none` \| `pending` \| `approved` \| `rejected` | Track 2 roll-up |
| `outcome` | string \| `false` | |
| `start_datetime` | ISO datetime \| `false` | |
| `end_datetime` | ISO datetime \| `false` | |
| `location_log_count` | int | Points in the GPS trail |
| `tracked_distance_km` | float | Path length through the trail |
| `last_location_datetime` | ISO datetime \| `false` | Newest fix |

### Lifecycle

```
draft ──submit──▶ submitted ──approve──▶ approved ──start──▶ in_progress ──end──▶ done
                      │                      ▲
                      ├──reject──▶ rejected  │
                      └──reschedule──▶ reschedule_requested ──approve──┘

cancelled  ← cancel (any state except done)
```

`state` values: `draft`, `submitted` *(labelled "Under Approval")*, `approved`,
`rejected`, `cancelled`, `reschedule_requested`, `in_progress`, `done`.

### Two independent approval tracks

A visit is only `approved` when **both** clear:

1. **Visit approval** — any manager in the *requester's* chain approves.
2. **Attendee approval** — each attendee is approved by a manager in *their own*
   chain, independently of every other attendee.

Attendees **gate** the visit approval: `/api/visit/approve` is refused while any
attendee is still `pending`. Rejecting is never gated.

---

## 4. Endpoints

### 4.1 Read

#### `POST /api/visit/my` — list my visits

| Param | Type | Required | Default |
|---|---|---|---|
| `domain` | array | no | — extra Odoo domain, ANDed with "mine" |
| `limit` | int | no | `80` |
| `offset` | int | no | `0` |

```json
{ "params": { "limit": 5 } }
```

```json
{ "result": { "visits": [ {
  "id": 52, "name": "VIS/2026/00052", "visit_type": "project",
  "project_id": 5, "opportunity_id": false,
  "partner_id": 290, "partner_name": "Acme Corp",
  "employee_id": 1, "employee_name": "Administrator",
  "scheduled_datetime": "2026-09-13T09:55:01",
  "purpose": "Quarterly business review", "location": "Acme HQ, Riyadh",
  "state": "done", "visit_approval_state": "approved",
  "attendee_approval_state": "approved",
  "outcome": "Renewal agreed, contract to follow",
  "start_datetime": "2026-09-12T09:10:01", "end_datetime": "2026-09-12T09:55:04",
  "location_log_count": 5, "tracked_distance_km": 9.311,
  "last_location_datetime": "2026-09-12T09:55:04"
} ] } }
```

Returns visits where the caller is the **responsible employee** — including ones
a manager created on their behalf.

#### `POST /api/visit/get` — read one visit

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |

```json
{ "params": { "visit_id": 52 } }
```
→ `{ "result": { "visit": { …visit object… } } }`

---

### 4.2 Create and submit

#### `POST /api/visit/create`

| Param | Type | Required |
|---|---|---|
| `vals` | object | yes |

Only these keys inside `vals` are accepted (anything else is silently dropped):
`visit_type`, `project_id`, `opportunity_id`, `partner_id`, `employee_id`,
`scheduled_datetime`, `purpose`, `location`, `latitude`, `longitude`.

`purpose` and `scheduled_datetime` are mandatory. A `project` visit requires
`project_id`; an `opportunity` visit requires `opportunity_id` — never both.

```json
{ "params": { "vals": {
    "visit_type": "project",
    "project_id": 5,
    "employee_id": 1,
    "scheduled_datetime": "2026-09-13 09:55:01",
    "purpose": "Quarterly business review",
    "location": "Acme HQ, Riyadh"
} } }
```

```json
{ "result": { "visit": {
    "id": 52, "name": "VIS/2026/00052", "state": "draft",
    "visit_approval_state": "pending", "attendee_approval_state": "none",
    "partner_id": 290, "partner_name": "Acme Corp",
    "location_log_count": 0, "tracked_distance_km": 0.0
} } }
```

The customer (`partner_id`) is filled automatically from the project/opportunity.

#### `POST /api/visit/add_participants`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `employee_ids` | int[] | yes |

```json
{ "params": { "visit_id": 52, "employee_ids": [281] } }
```
```json
{ "result": { "participants": [
    { "id": 16, "employee_id": 281, "approval_state": "pending" } ] } }
```

> Add attendees **before** submitting. Attendees added after submission are not
> routed to their manager for approval, and will block the visit approval.

#### `POST /api/visit/submit`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |

```json
{ "params": { "visit_id": 52 } }
```
→ `{ "result": { "state": "submitted" } }`

Allowed from `draft`, `reschedule_requested` and `rejected`. Opens both approval
tracks and notifies the relevant managers.

---

### 4.3 Approvals — track 1 (the visit)

#### `POST /api/visit/approve`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |

```json
{ "params": { "visit_id": 52 } }
```
→ `{ "result": { "state": "approved", "visit_approval_state": "approved" } }`

Only a manager in the **requester's** hierarchy (at any depth) or a visit
administrator may call this. Refused while any attendee is still pending:

```
UserError: The visit cannot be approved yet: all attendees must be approved
first. Current attendee approval: Pending.
```

Calling it twice:
```
UserError: This visit cannot be approved in its current state.
```

#### `POST /api/visit/reject`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `reason` | string | no (strongly recommended) |

```json
{ "params": { "visit_id": 54, "reason": "Customer postponed the meeting" } }
```
→ `{ "result": { "state": "rejected", "visit_approval_state": "rejected" } }`

---

### 4.4 Approvals — track 2 (attendees)

#### `POST /api/visit/attendee/approve`

| Param | Type | Required |
|---|---|---|
| `participant_id` | int | yes |

```json
{ "params": { "participant_id": 16 } }
```
→ `{ "result": { "approval_state": "approved", "state": "submitted" } }`

`state` is the **visit's** state — it stays `submitted` until the visit track is
also approved.

#### `POST /api/visit/attendee/reject`

| Param | Type | Required |
|---|---|---|
| `participant_id` | int | yes |
| `reason` | string | no |

```json
{ "params": { "participant_id": 17, "reason": "Adel is on leave" } }
```
→ `{ "result": { "approval_state": "rejected", "state": "draft" } }`

The visit `state` follows the server's *Participant Rejection Policy* setting —
`draft` (default, shown above) or `rejected`.

Only a manager in **that attendee's** chain may decide, and nobody can approve
their own participation.

---

### 4.5 Reschedule

#### `POST /api/visit/reschedule`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `scheduled_datetime` | datetime | no |
| `purpose` | string | no |
| `location` | string | no |

```json
{ "params": { "visit_id": 53,
    "scheduled_datetime": "2026-09-17 09:55:41",
    "purpose": "Reschedule demo (moved)",
    "location": "Acme Annex" } }
```
→ `{ "result": { "state": "reschedule_requested" } }`

Only these three fields can change. The visit re-enters the approval track
(`visit_approval_state` → `pending`); attendee approvals already granted are
kept. Approve it with the normal `/api/visit/approve`. A `done`, `cancelled` or
`rejected` visit cannot be rescheduled.

> `scheduled_datetime` cannot be changed with a plain update once the visit
> leaves `draft` — this endpoint is the only way.

---

### 4.6 Start / End

#### `POST /api/visit/start`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `location` | string | no |
| `latitude` | float | no |
| `longitude` | float | no |

```json
{ "params": { "visit_id": 52, "location": "Acme HQ gate",
              "latitude": 24.7136, "longitude": 46.6753 } }
```
→ `{ "result": { "state": "in_progress", "start_datetime": "2026-09-12T09:55:02" } }`

Only from `approved`. If coordinates are supplied they become the **first point
of the GPS trail** (`source: "start"`).

#### `POST /api/visit/end`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `outcome` | string | **yes** (unless already set) |
| `location` | string | no |
| `latitude` | float | no |
| `longitude` | float | no |

```json
{ "params": { "visit_id": 52,
    "outcome": "Renewal agreed, contract to follow",
    "location": "Acme HQ lobby",
    "latitude": 24.7742, "longitude": 46.7386 } }
```
→ `{ "result": { "state": "done", "end_datetime": "2026-09-12T09:55:04" } }`

Only from `in_progress`. Without an outcome:
```
UserError: The visit outcome is required before ending the visit.
```
Coordinates become the **last point of the trail** (`source: "end"`), and the
outcome is posted to the linked project/opportunity chatter with attachments.

---

### 4.7 GPS trail

The trail is the continuous path between the start and the end of a visit. It is
**append-only** — points can never be edited or deleted from the app.

**Point object**

| Field | Type | Notes |
|---|---|---|
| `id` | int | |
| `visit_id` | int | |
| `logged_at` | ISO datetime | Time of the fix **on the device** |
| `latitude` | float | −90 … 90 |
| `longitude` | float | −180 … 180 |
| `accuracy` | float | metres, `0.0` if unsent |
| `altitude` | float | metres |
| `speed` | float | m/s |
| `heading` | float | degrees clockwise from true north |
| `location` | string \| `false` | optional resolved address |
| `device_id` | string \| `false` | |
| `source` | `start` \| `track` \| `end` \| `manual` | |

`source` is server-controlled: `start` and `end` are written by the start/end
actions, and anything you send is forced to `track`.

#### `POST /api/visit/log_location` — one point

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `latitude` | float | yes |
| `longitude` | float | yes |
| `logged_at` | datetime | no — defaults to now |
| `accuracy`, `altitude`, `speed`, `heading` | float | no |
| `location` | string | no |
| `device_id` | string | no |

```json
{ "params": { "visit_id": 52, "latitude": 24.73, "longitude": 46.69,
    "accuracy": 7.5, "speed": 12.0, "heading": 41.0, "altitude": 612.0,
    "device_id": "pixel-7", "logged_at": "2026-09-12 09:20:01" } }
```

```json
{ "result": {
  "log": { "id": 37, "visit_id": 52, "logged_at": "2026-09-12T09:20:01",
           "latitude": 24.73, "longitude": 46.69, "accuracy": 7.5,
           "altitude": 612.0, "speed": 12.0, "heading": 41.0,
           "location": false, "device_id": "pixel-7", "source": "track" },
  "location_log_count": 2,
  "tracked_distance_km": 2.352
} }
```

**Always send `logged_at`.** The trail is ordered and measured by fix time, not
by arrival time — that is what makes a delayed upload land in the right place.

#### `POST /api/visit/log_locations` — batch / offline flush

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `points` | object[] | yes — same fields as above, minus `visit_id` |

Points may be sent **in any order**; the server sorts them by `logged_at`.
A malformed point is rejected **individually** so one bad fix never costs you
the rest of the buffer.

```json
{ "params": { "visit_id": 52, "points": [
    { "latitude": 24.76,  "longitude": 46.72,  "logged_at": "2026-09-12 09:40:01" },
    { "latitude": 24.745, "longitude": 46.705, "logged_at": "2026-09-12 09:30:01" },
    { "latitude": 999.0,  "longitude": 46.70 },
    { "latitude": 24.77,  "longitude": 46.73,  "logged_at": "garbage" }
] } }
```

```json
{ "result": {
  "created": 2,
  "logs": [ { "id": 38, "…": "…" }, { "id": 39, "…": "…" } ],
  "rejected": [
    { "index": 2, "error": "Latitude 999.0 is out of range (-90 to 90)." },
    { "index": 3, "error": "The position timestamp is not a valid date and time." }
  ],
  "location_log_count": 4,
  "tracked_distance_km": 6.858
} }
```

`rejected[].index` is the position in the `points` array you sent — use it to
drop the accepted points from your local queue and keep or discard the rest.

#### `POST /api/visit/track` — read the trail

| Param | Type | Required | Default |
|---|---|---|---|
| `visit_id` | int | yes | |
| `limit` | int | no | all |
| `offset` | int | no | `0` |
| `date_from` | datetime | no | |
| `date_to` | datetime | no | |

```json
{ "params": { "visit_id": 52 } }
```

```json
{ "result": {
  "visit_id": 52,
  "location_log_count": 5,
  "tracked_distance_km": 9.311,
  "logs": [
    { "id": 36, "logged_at": "2026-09-12T09:10:01", "latitude": 24.7136,
      "longitude": 46.6753, "location": "Acme HQ gate", "source": "start" },
    { "id": 37, "logged_at": "2026-09-12T09:20:01", "latitude": 24.73,
      "longitude": 46.69, "accuracy": 7.5, "device_id": "pixel-7", "source": "track" },
    { "id": 39, "logged_at": "2026-09-12T09:30:01", "latitude": 24.745,  "longitude": 46.705, "source": "track" },
    { "id": 38, "logged_at": "2026-09-12T09:40:01", "latitude": 24.76,   "longitude": 46.72,  "source": "track" },
    { "id": 40, "logged_at": "2026-09-12T09:55:04", "latitude": 24.7742, "longitude": 46.7386,
      "location": "Acme HQ lobby", "source": "end" }
  ]
} }
```

Always **oldest first** — feed `logs` straight into a polyline. Note `id` 39
precedes `id` 38: they arrived out of order in a batch and the server placed
them by `logged_at`, exactly as intended.

#### When a point is accepted

| Rule | Failure message |
|---|---|
| Visit must have been started | `Visit VIS/… has not been started, so no position can be recorded for it.` |
| Not before `start_datetime` | `A position cannot predate the start of the visit (…).` |
| If the visit is `done`, not after `end_datetime` | `The visit ended on …; a later position cannot be added.` |
| Not more than 5 min in the future | `A position cannot be dated in the future.` |
| Coordinates in range | `Latitude 999.0 is out of range (-90 to 90).` |
| Timestamp parseable | `The position timestamp is not a valid date and time.` |

**Offline uploads after the visit ends are supported** — a point taken *during*
the visit but transmitted *after* it closed is accepted, as long as its
`logged_at` falls inside the start–end window. Flush your queue before the user
ends the visit whenever you can, but a late flush will not be lost.

**Who may write a point:** only the responsible employee, whoever planned the
visit, or an administrator. A manager can *read* a subordinate's trail but gets
a `UserError` if they try to add to it.

---

### 4.8 Attachments

#### `POST /api/visit/upload_attachment`

| Param | Type | Required |
|---|---|---|
| `visit_id` | int | yes |
| `filename` | string | yes |
| `data_b64` | string | yes — base64, **already encoded by the client** |

```json
{ "params": { "visit_id": 52, "filename": "site-photo.txt",
              "data_b64": "aGVsbG8gZnJvbSB0aGUgc2l0ZQ==" } }
```
→ `{ "result": { "attachment_id": 2711 } }`

Send the raw base64 only — no `data:image/jpeg;base64,` prefix. Attachments are
included in the summary posted to the project/opportunity when the visit ends.

---

### 4.9 Push notifications (FCM)

#### `POST /api/visit/register_device`

| Param | Type | Required |
|---|---|---|
| `token` | string | yes — FCM registration token |
| `platform` | `"android"` \| `"ios"` | yes |
| `device_id` | string | no — stable per-device id |

```json
{ "params": { "token": "demo-fcm-token-abc123",
              "platform": "android", "device_id": "pixel-7" } }
```
→ `{ "result": { "ok": true } }`

Call this after every login and whenever FCM rotates the token. Sending
`device_id` lets the server retire the previous token for that device, so a
reinstall does not leave a ghost registration behind.

#### `POST /api/visit/unregister_device`

| Param | Type | Required |
|---|---|---|
| `token` | string | yes |

→ `{ "result": { "ok": true } }`

Call on logout.

#### Push payload

Every push carries this `data` block (all values are **strings**):

```json
{ "type": "visit_event", "event": "approved",
  "visit_id": "52", "visit_ref": "VIS/2026/00052", "state": "approved" }
```

`event` values:

| Event | Sent to | Meaning |
|---|---|---|
| `submitted` | requester's manager | A visit needs your approval |
| `participation_approval` | attendee's manager | An attendee needs your approval |
| `ready_for_approval` | requester's manager | All attendees cleared; visit can be approved |
| `approved` | requester + employee | Visit approved |
| `rejected` | requester + employee | Visit rejected |
| `participant_rejected` | requester + employee | An attendee's manager declined |
| `reschedule_requested` | requester's manager | Reschedule needs approval |
| `reschedule_approved` | requester + employee | Reschedule approved |
| `escalated` | higher managers | 24h with no action |
| `started` | requester's manager | Visit started |
| `completed` | requester's manager | Visit completed |
| `cancelled` | requester + employee + manager | Visit cancelled |

`visit_id` is a string — parse it before using it as an int.

---

## 5. Quick reference

| Route | Purpose |
|---|---|
| `POST /web/session/authenticate` | Log in, get the session cookie |
| `POST /api/visit/my` | List my visits |
| `POST /api/visit/get` | Read one visit |
| `POST /api/visit/create` | Create a visit |
| `POST /api/visit/add_participants` | Add attendees (before submitting) |
| `POST /api/visit/submit` | Submit for approval |
| `POST /api/visit/approve` | Approve the visit |
| `POST /api/visit/reject` | Reject the visit |
| `POST /api/visit/attendee/approve` | Approve one attendee |
| `POST /api/visit/attendee/reject` | Reject one attendee |
| `POST /api/visit/reschedule` | Request a reschedule |
| `POST /api/visit/start` | Start the visit (GPS) |
| `POST /api/visit/log_location` | Record one position |
| `POST /api/visit/log_locations` | Flush a buffer of positions |
| `POST /api/visit/track` | Read the trail |
| `POST /api/visit/end` | End the visit (GPS + outcome) |
| `POST /api/visit/upload_attachment` | Upload a base64 attachment |
| `POST /api/visit/register_device` | Register an FCM token |
| `POST /api/visit/unregister_device` | Unregister an FCM token |

## 6. End-to-end example

```bash
BASE=https://visits-dhh.odoo.com
DB=shawkialaddin-visits-dh-live-37916914

# 1. log in, keep the cookie
curl -s -c cj.txt -X POST $BASE/web/session/authenticate \
  -H 'Content-Type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"call\",\"params\":
       {\"db\":\"$DB\",\"login\":\"admin\",\"password\":\"2005\"}}"

# 2. create → submit → approve
curl -s -b cj.txt -X POST $BASE/api/visit/create \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"vals":{
        "visit_type":"project","project_id":5,"employee_id":1,
        "scheduled_datetime":"2026-09-13 09:55:01",
        "purpose":"Quarterly business review"}}}'

curl -s -b cj.txt -X POST $BASE/api/visit/submit \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":52}}'

curl -s -b cj.txt -X POST $BASE/api/visit/approve \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":52}}'

# 3. start, track, end
curl -s -b cj.txt -X POST $BASE/api/visit/start \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":52,
        "latitude":24.7136,"longitude":46.6753,"location":"Acme HQ gate"}}'

curl -s -b cj.txt -X POST $BASE/api/visit/log_location \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":52,
        "latitude":24.73,"longitude":46.69,"accuracy":7.5,
        "logged_at":"2026-09-12 09:20:01","device_id":"pixel-7"}}'

curl -s -b cj.txt -X POST $BASE/api/visit/end \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":52,
        "outcome":"Renewal agreed","latitude":24.7742,"longitude":46.7386}}'

# 4. read the trail
curl -s -b cj.txt -X POST $BASE/api/visit/track \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":52}}'
```

---

## 7. Implementation checklist

- [ ] Treat `error` in the body as the failure signal, not the HTTP status.
- [ ] Decode `false` as null/empty for every string, relation and date field.
- [ ] Send datetimes as `YYYY-MM-DD HH:MM:SS` in **UTC**; parse `T`-separated
      responses as UTC and render in local time.
- [ ] Persist the `session_id` cookie; on `SessionExpiredException`,
      re-authenticate and retry the call once.
- [ ] Buffer GPS points locally with their real `logged_at` and flush via
      `log_locations`; on success, drop only the points not listed in `rejected`.
- [ ] Re-register the FCM token on every login and on token rotation; always
      send a stable `device_id`.
- [ ] Add attendees before submitting, never after.
- [ ] Parse `visit_id` from the push payload as a string, then convert.
