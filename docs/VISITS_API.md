# Visit Management — Mobile / JSON API

HTTP/JSON API for the `dh_visit_management` module, intended for mobile clients.

- **Transport:** Odoo JSON-RPC 2.0 (`type='json'` controllers).
- **Auth:** `auth='user'` — every call runs **as the logged-in user**, so all
  Odoo access rights and record rules apply automatically. A user only ever
  sees/acts on records they are allowed to.
- **Base URL:** `https://<your-odoo-host>`
- **Content-Type:** `application/json`

> All endpoints are `POST`. Parameters go inside the JSON-RPC `params` object
> (see *Request envelope* below), **not** in the URL or query string.

---

## 1. Authentication

JSON (`type='json'`) routes are **session-based**. First authenticate to obtain
a `session_id` cookie, then send that cookie on every subsequent call.

### 1.1 Log in

`POST /web/session/authenticate`

```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "db": "YOUR_DATABASE",
    "login": "sam@test.com",
    "password": "the-password"
  }
}
```

The response sets a `session_id` cookie. Capture it and resend it as:

```
Cookie: session_id=<value>
```

### 1.2 Log out

`POST /web/session/destroy` (standard Odoo route).

---

## 2. Request / Response envelope

Every endpoint uses the JSON-RPC 2.0 envelope.

**Request**

```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": { /* endpoint-specific arguments go here */ }
}
```

**Success response**

```json
{
  "jsonrpc": "2.0",
  "id": null,
  "result": { /* endpoint-specific payload */ }
}
```

**Error response** (validation error, permission denied, etc.)

```json
{
  "jsonrpc": "2.0",
  "id": null,
  "error": {
    "code": 200,
    "message": "Odoo Server Error",
    "data": {
      "name": "odoo.exceptions.UserError",
      "message": "You are not allowed to approve or reject this visit.",
      "debug": "Traceback ..."
    }
  }
}
```

Always check for the `error` key. The human-readable text is in
`error.data.message`.

---

## 3. The Visit object

Read endpoints return visits in this shape (`_visit_to_dict`):

| Field                | Type           | Notes                                   |
|----------------------|----------------|-----------------------------------------|
| `id`                 | int            | Visit record id                         |
| `name`               | string         | Reference, e.g. `VIS/2026/00001`        |
| `visit_type`         | string         | `project` or `opportunity`              |
| `project_id`         | int            | `0`/false if not a project visit        |
| `opportunity_id`     | int            | `0`/false if not an opportunity visit   |
| `partner_id`         | int            | Customer id (auto-filled)               |
| `partner_name`       | string         | Customer display name                   |
| `employee_id`        | int            | Responsible employee id                 |
| `employee_name`      | string         |                                         |
| `scheduled_datetime` | string (ISO)   | e.g. `2026-07-01T09:00:00`              |
| `purpose`            | string         |                                         |
| `location`           | string         |                                         |
| `state`              | string         | See *State values*                      |
| `outcome`            | string         |                                         |
| `start_datetime`     | string (ISO)   | null until started                      |
| `end_datetime`       | string (ISO)   | null until ended                        |

### State values

`draft`, `submitted`, `waiting_participant_manager_approval`,
`waiting_direct_manager_approval`, `escalated`, `approved`, `rejected`,
`cancelled`, `reschedule_requested`, `in_progress`, `done`.

---

## 4. Endpoints

### 4.1 List my visits

`POST /api/visit/my`

Returns visits **created by the current user**.

| Param    | Type  | Required | Default | Description                          |
|----------|-------|----------|---------|--------------------------------------|
| `domain` | list  | no       | `[]`    | Extra Odoo domain, ANDed with mine   |
| `limit`  | int   | no       | `80`    | Max records                          |
| `offset` | int   | no       | `0`     | Pagination offset                    |

**params example**

```json
{ "domain": [["state", "=", "approved"]], "limit": 20, "offset": 0 }
```

**result**

```json
{ "visits": [ { "id": 1, "name": "VIS/2026/00001", "...": "..." } ] }
```

---

### 4.2 Get one visit

`POST /api/visit/get`

| Param      | Type | Required | Description |
|------------|------|----------|-------------|
| `visit_id` | int  | yes      | Visit id    |

**result**

```json
{ "visit": { "id": 1, "name": "VIS/2026/00001", "...": "..." } }
```

Returns a permission error if the user may not read that visit.

---

### 4.3 Create a visit

`POST /api/visit/create`

Creates a visit in **draft**. Only the whitelisted keys below are accepted in
`vals`; anything else is ignored.

Accepted `vals` keys: `visit_type`, `project_id`, `opportunity_id`,
`partner_id`, `employee_id`, `scheduled_datetime`, `purpose`, `location`,
`latitude`, `longitude`.

> `partner_id` is auto-filled from the project/opportunity, so you normally
> don't send it. `employee_id` defaults to the caller's employee.

| Param  | Type | Required | Description              |
|--------|------|----------|--------------------------|
| `vals` | dict | yes      | Field values (see above) |

**params example**

```json
{
  "vals": {
    "visit_type": "project",
    "project_id": 12,
    "scheduled_datetime": "2026-07-01 09:00:00",
    "purpose": "Kickoff meeting",
    "location": "Client HQ, Riyadh"
  }
}
```

**result**

```json
{ "visit": { "id": 5, "name": "VIS/2026/00005", "state": "draft", "...": "..." } }
```

---

### 4.4 Submit for approval

`POST /api/visit/submit`

Moves a draft (or rescheduled) visit into the approval flow. If the visit has
pending participants it goes to participant-manager approval first; otherwise
straight to direct-manager approval.

| Param      | Type | Required | Description |
|------------|------|----------|-------------|
| `visit_id` | int  | yes      | Visit id    |

**result** — `{ "state": "waiting_direct_manager_approval" }`

---

### 4.5 Approve

`POST /api/visit/approve`

Caller must be an allowed approver (manager in the chain / project manager on an
escalated visit / admin). Users cannot approve their own visit.

| Param      | Type | Required | Description |
|------------|------|----------|-------------|
| `visit_id` | int  | yes      | Visit id    |

**result** — `{ "state": "approved" }`

---

### 4.6 Reject

`POST /api/visit/reject`

| Param      | Type   | Required | Description        |
|------------|--------|----------|--------------------|
| `visit_id` | int    | yes      | Visit id           |
| `reason`   | string | yes*     | Rejection reason   |

\* The backend stores whatever is passed; always send a reason.

**result** — `{ "state": "rejected" }`

---

### 4.7 Request reschedule

`POST /api/visit/reschedule`

Updates only the reschedulable fields and re-routes to the manager for approval.
Sending `null` for a field leaves it unchanged.

| Param                | Type   | Required | Description            |
|----------------------|--------|----------|------------------------|
| `visit_id`           | int    | yes      | Visit id               |
| `scheduled_datetime` | string | no       | New schedule           |
| `purpose`            | string | no       | New purpose            |
| `location`           | string | no       | New location           |

**result** — `{ "state": "reschedule_requested" }`

---

### 4.8 Add participants

`POST /api/visit/add_participants`

Adds additional employees. Each participant's own manager must approve before
the main approval proceeds. The participant manager is auto-derived.

| Param          | Type        | Required | Description                |
|----------------|-------------|----------|----------------------------|
| `visit_id`     | int         | yes      | Visit id                   |
| `employee_ids` | list[int]   | yes      | `hr.employee` ids to add   |

**params example** — `{ "visit_id": 5, "employee_ids": [7, 9] }`

**result**

```json
{
  "participants": [
    { "id": 1, "employee_id": 7, "approval_state": "pending" },
    { "id": 2, "employee_id": 9, "approval_state": "pending" }
  ]
}
```

---

### 4.9 Start visit (with GPS)

`POST /api/visit/start`

Allowed only when the visit is **approved**.

| Param       | Type   | Required | Description           |
|-------------|--------|----------|-----------------------|
| `visit_id`  | int    | yes      | Visit id              |
| `location`  | string | no       | Reverse-geocoded text |
| `latitude`  | float  | no       | GPS latitude          |
| `longitude` | float  | no       | GPS longitude         |

**result** — `{ "state": "in_progress", "start_datetime": "2026-07-01T09:05:11" }`

---

### 4.10 End visit (with GPS + outcome)

`POST /api/visit/end`

Allowed only when **in progress**. `outcome` is **required** (either passed here
or already set on the visit). On success the outcome is posted to the linked
project/opportunity chatter.

| Param       | Type   | Required | Description         |
|-------------|--------|----------|---------------------|
| `visit_id`  | int    | yes      | Visit id            |
| `outcome`   | string | yes      | Visit outcome       |
| `location`  | string | no       | Reverse-geocoded    |
| `latitude`  | float  | no       | GPS latitude        |
| `longitude` | float  | no       | GPS longitude       |

**result** — `{ "state": "done", "end_datetime": "2026-07-01T10:30:00" }`

---

### 4.11 Upload attachment

`POST /api/visit/upload_attachment`

| Param      | Type   | Required | Description                          |
|------------|--------|----------|--------------------------------------|
| `visit_id` | int    | yes      | Visit id                             |
| `filename` | string | yes      | File name incl. extension            |
| `data_b64` | string | yes      | **Base64-encoded** file contents     |

**result** — `{ "attachment_id": 42 }`

---

## 5. End-to-end example (curl)

```bash
HOST="https://odoo.example.com"
DB="mydb"
COOKIES=cookies.txt

# 1) Authenticate (stores session_id cookie)
curl -s -c $COOKIES -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"db":"'"$DB"'","login":"sam@test.com","password":"secret"}}' \
  $HOST/web/session/authenticate >/dev/null

# 2) Create a project visit
curl -s -b $COOKIES -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"vals":{"visit_type":"project","project_id":12,"scheduled_datetime":"2026-07-01 09:00:00","purpose":"Kickoff"}}}' \
  $HOST/api/visit/create

# 3) Submit it (use the id returned above, e.g. 5)
curl -s -b $COOKIES -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":5}}' \
  $HOST/api/visit/submit

# 4) Start with GPS
curl -s -b $COOKIES -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":5,"latitude":24.7136,"longitude":46.6753}}' \
  $HOST/api/visit/start

# 5) End with outcome + GPS
curl -s -b $COOKIES -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{"visit_id":5,"outcome":"Signed off","latitude":24.7136,"longitude":46.6753}}' \
  $HOST/api/visit/end
```

---

## 6. Endpoint summary

| Method | Route                          | Purpose                       |
|--------|--------------------------------|-------------------------------|
| POST   | `/api/visit/my`                | List my visits                |
| POST   | `/api/visit/get`               | Read one visit                |
| POST   | `/api/visit/create`            | Create a draft visit          |
| POST   | `/api/visit/submit`            | Submit for approval           |
| POST   | `/api/visit/approve`           | Approve                       |
| POST   | `/api/visit/reject`            | Reject (with reason)          |
| POST   | `/api/visit/reschedule`        | Request reschedule            |
| POST   | `/api/visit/add_participants`  | Add additional participants   |
| POST   | `/api/visit/start`             | Start visit with GPS          |
| POST   | `/api/visit/end`               | End visit with GPS + outcome  |
| POST   | `/api/visit/upload_attachment` | Upload a base64 attachment    |

---

## 7. Notes & gotchas

- **Permissions are enforced server-side.** A `Visit User` only sees their own
  visits via `/api/visit/my`; a manager sees their hierarchy; an admin sees all.
  No special API flag bypasses record rules.
- **Datetimes** are interpreted in UTC by the server. Send
  `"YYYY-MM-DD HH:MM:SS"`; ISO strings are returned on read.
- **Outcome is mandatory to end** a visit (`/api/visit/end`) — the call errors
  otherwise.
- **`start` requires `approved`**, **`end` requires `in_progress`** — calling out
  of order returns a `UserError`.
- All routes require a valid `session_id`; an expired session returns a session
  error (re-authenticate via `/web/session/authenticate`).
