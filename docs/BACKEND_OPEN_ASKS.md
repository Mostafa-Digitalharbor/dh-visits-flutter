# Customer Visits — Consolidated Backend Asks

**To:** Odoo Developer
**From:** Flutter Mobile Dev
**Module:** `dh_customer_visits`
**Build:** `dh-abdelrahmanwael-odoo-19-test-pros-31943069`
**Date:** 2026-05-12

This is a single, prioritized list of everything still pending on the backend
side. Previous docs (`BACKEND_ISSUES.md`, `BACKEND_SECURITY_REVIEW.md`)
are consolidated here — please use **this** as the authoritative checklist.

The mobile app is fully built and works end-to-end against what's
currently deployed (with workarounds in two places). Each item below makes
a specific mobile feature go from "works with caveat" to "works
naturally".

---

## 0. Status snapshot

| # | Ask | Severity | Status |
|---|---|---|---|
| 1 | Add `is_manager` to login response | **Blocker** for proper role gating | ✅ shipped 2026-05-12 |
| 2 | `GET /api/customers/<id>` returns 500 on every ID | **Blocker** | ✅ shipped 2026-05-12 |
| 3 | `GET /api/visits` missing GPS + range fields | High | ✅ shipped 2026-05-12 (incl. `description` rename + `check_in_state` / `check_out_state`) |
| 4 | `GET /api/customers` crashes on `customer_rank=0` records | Medium | ✅ shipped 2026-05-12 |
| 5 | "Today" filter in `customer.visit` search view | Medium (Odoo Web UX) | ✅ shipped 2026-05-12 |
| 6 | Lock `description` field on form view per state | Low | ✅ shipped 2026-05-12 |
| 7 | Harden User-group `perm_write` (optional) | Low | ❌ open |
| 8 | `GET /api/visits` missing customer location + contact | High | ❌ open |
| 9 | `GET /api/visits` `date_from`/`date_to` filter returns empty | **High** | ❌ open (worked around client-side) |
| 10 | `GET /api/visits` missing `visit_date` in response | Medium | ❌ open |
| 11 | `customer.visit.create` via `call_kw` doesn't assign `name` (stays `/`) | Medium | ❌ open |

Already shipped correctly (no action) — listed in §9.

---

## 1. Add `is_manager` to the login response — **Blocker**

The mobile branches its entire UI on whether the user is in
`Customer Visits / Manager`. Today we fall back to Odoo's built-in
`is_admin`, which works for the database admin but mis-classifies any
regular user who happens to be in the Manager group.

### Required change
In the `Session.authenticate` (or `Session.session_info`) override that
the addon already ships, add one key to the result:

```python
"is_manager": request.env.user.has_group(
    'dh_customer_visits.group_customer_visit_manager'
),
```

### Expected behavior
- User only in `Customer Visits / User` → `is_manager: false`
- User in `Customer Visits / Manager` → `is_manager: true`
- Database admin → `is_manager: true` (admin is implicitly in every group;
  `is_admin: true` also already arrives — fine to keep both)

### Why it's a blocker
The mobile shows two completely different shells:
- **Manager shell** → tabs for Visits + Customers, editable visit fields,
  full settings.
- **User shell** → a single Visits screen, read-only details, simplified
  settings, no Customers tab.

Without `is_manager` the mobile can't tell a Manager-but-not-admin user
apart from a regular field employee. The mobile is forward-compatible —
it parses the field if present and degrades to `is_admin` otherwise.

---

## 2. `GET /api/customers/<id>` returns 500 on every ID — **Blocker**

```http
GET /api/customers/7
→ 500
→ {"status":"error","error":{"code":"SERVER_ERROR","message":"Internal server error"}}
```

Verified on IDs `1, 3, 7, 8, 9, 10, 11` — every single one. The
`/api/customers` **list** endpoint works fine, so the controller can read
partner data — the bug is isolated to the single-record endpoint
(likely in the join that builds `last_visit` or another computed field).

Please check the Odoo log at the time of one of these requests; the
traceback will point straight at the offending line.

### Mobile workaround
We pass the `Customer` object via `go_router` extra from the list, so the
detail page renders instantly from cached data and never blocks on this
endpoint. Refresh fails silently. (The Nearby Map page that also relied
on this was removed from the app on 2026-09-16.) **Please still fix the endpoint** —
relying on the cached object means deep links / cold starts at a customer
URL don't work for the Manager flow.

---

## 3. `GET /api/visits` is missing the GPS + range fields — High

The `customer.visit` model stores these per-record:
- `check_in_lat`, `check_in_lng`
- `check_out_lat`, `check_out_lng`
- `check_in_state` (computed: `in_range` / `not_in_range` / `no`)
- `check_out_state` (computed: same)

We verified the data is there (via `search_read`). The JSON for
`/api/visits` just doesn't include them. Please add them to the
serializer:

```python
def _visit_to_dict(visit):
    return {
        'id': visit.id,
        'name': visit.name,
        'customer': {...},
        'employee': {...},
        'check_in_time': ...,
        'check_out_time': ...,
        'duration_minutes': visit.duration_minutes,
        'state': visit.mobile_state,
        # ADD THESE:
        'check_in_lat': visit.check_in_lat,
        'check_in_lng': visit.check_in_lng,
        'check_out_lat': visit.check_out_lat,
        'check_out_lng': visit.check_out_lng,
        'check_in_state': visit.check_in_state,
        'check_out_state': visit.check_out_state,
        'description': visit.description,
    }
```

### What unlocks for mobile
- The visit card surfaces a clear **"In range / Out of range"** badge so
  managers can spot fraudulent check-ins at a glance.
- The "Show check-in location" map dialog on each visit card lights up
  (currently disabled because the coords are null).
- Visit notes show up in the detail page from the list response without
  a second request.

---

## 4. `GET /api/customers` crashes on `customer_rank=0` records — Medium

We hit this earlier: a `res.partner` with `customer_rank=0` and non-zero
coordinates broke the entire list with a 500. We worked around it by
archiving the offending partner, but the underlying controller is fragile.

### Suggested fix
Add `('customer_rank','>',0)` to the controller's domain:

```python
partners = request.env['res.partner'].sudo().search([
    ('partner_latitude', '!=', 0),
    ('partner_longitude', '!=', 0),
    ('customer_rank', '>', 0),
    # ... existing filters
])
```

Or whatever filter makes business sense — the point is the controller
should never throw because a non-customer partner has coords.

---

## 5. "Today" filter in `customer.visit` search view — Medium

The current `customer.visit.search` only has filters for admin lifecycle
states (Draft / Submitted / Under Review / Done). There's no date filter,
so a User logging into Odoo Web sees their full history by default
instead of today's queue.

### Add to the search view
```xml
<search>
    <field name="name"/>
    <field name="partner_id"/>
    <field name="salesperson_id"/>
    <field name="visit_type_id"/>

    <filter string="Today" name="today"
            domain="[('visit_date','=', context_today().strftime('%Y-%m-%d'))]"/>
    <filter string="This Week" name="this_week"
            domain="[('visit_date','&gt;=', (context_today() - relativedelta(days=context_today().weekday())).strftime('%Y-%m-%d')),
                    ('visit_date','&lt;=', (context_today() + relativedelta(days=6-context_today().weekday())).strftime('%Y-%m-%d'))]"/>
    <filter string="This Month" name="this_month"
            domain="[('visit_date','&gt;=', (context_today().replace(day=1)).strftime('%Y-%m-%d'))]"/>
    <separator/>

    <!-- existing state filters preserved -->
    <filter string="Draft" name="draft" domain="[('state','=','draft')]"/>
    <filter string="Submitted" name="submit" domain="[('state','=','submit')]"/>
    <filter string="Under Review" name="under_review" domain="[('state','=','under_review')]"/>
    <filter string="Done" name="done" domain="[('state','=','done')]"/>

    <group>
        <filter string="Customer" name="group_customer" context="{'group_by': 'partner_id'}"/>
        <filter string="Salesperson" name="group_salesperson" context="{'group_by': 'salesperson_id'}"/>
        <filter string="Visit Type" name="group_visit_type" context="{'group_by': 'visit_type_id'}"/>
        <filter string="State" name="group_state" context="{'group_by': 'state'}"/>
    </group>
</search>
```

### Default "Today" for the User-facing action
Update the User action's context so the list opens on today:

```xml
<field name="context">{'search_default_today': 1}</field>
```

Leave the Manager action without that default. The filter is
automatically clearable — the user can deselect "Today" any time to see
the full history within their permissions.

---

## 6. Lock `description` field by state — Low

Right now the form view sets `readonly="state != 'draft'"` on
`visit_date`, `partner_id`, `visit_type_id`, and `salesperson_id`, but
**not** on `description`. So a User can still rewrite the notes of any
of their visits — even after the visit is `under_review` or `done`.

The mobile only writes `description` during check-out (which fits the
`submit` state). For consistency, lock it after submit too:

```xml
<field name="description"
       readonly="state != 'draft' and state != 'submit'"
       placeholder="Enter visit notes and observations..."/>
```

I kept `submit` editable to match the mobile flow.

If editable notes after submission is intentional (audit trail use case),
ignore this point.

---

## 7. Hard enforcement of write rules — Optional

ACL gives the User group `perm_write=true`. Field locking is done in the
form view only. A curious User could call `write` over XML-RPC and bypass
that lock entirely.

If you want hardness (not just UI), pick one:

- **`@api.constrains`** on the relevant fields that rejects writes when
  `state != 'draft'` and the writer is in the User group.
- **Set `perm_write=False`** on the User group and have the check-in /
  check-out controllers do their writes via `sudo()`.

Not a blocker — flagging for completeness.

---

## 8. `GET /api/visits` is missing customer location + contact — High

The User-role mobile UX now shows a **customer location card** on each
visit detail page: an embedded map at the customer's office, a Navigate
button that hands off to Google Maps / Waze, and a tap-to-call icon for
the phone. The data lives on `res.partner` already (`partner_latitude`,
`partner_longitude`, `phone`/`mobile`, address fields) — we just need
it inlined in the `customer` block of `/api/visits` so the mobile doesn't
have to call `/api/customers/<id>` (which is still 500-ing — see §2).

### Required change
Extend the customer block in `_visit_to_dict`:

```python
'customer': {
    'id': visit.partner_id.id,
    'name': visit.partner_id.name,
    # ADD:
    'latitude':  visit.partner_id.partner_latitude  or None,
    'longitude': visit.partner_id.partner_longitude or None,
    'address':   visit.partner_id._display_address(without_company=True) or None,
    'phone':     visit.partner_id.phone or visit.partner_id.mobile or None,
}
```

### What unlocks for mobile
- The User opens a visit assigned to them, sees the customer's office on
  a mini-map inside the page, and taps **Navigate** to get turn-by-turn
  directions.
- The phone icon dials the customer directly from the visit detail page.
- The mobile is **forward-compatible**: it parses these keys if present
  and degrades silently (no map section, no Navigate button) if absent —
  so this ship is non-blocking for the current build.

---

## 9. `GET /api/visits` — `date_from` / `date_to` filter returns empty — **High**

Verified live with admin session: passing **any** non-null `date_from` or
`date_to` returns `total: 0`, even when matching visits exist.

```http
GET /api/visits                                          → total=3 ✓
GET /api/visits?state=all                                → total=3 ✓
GET /api/visits?date_from=2026-05-12&date_to=2026-05-13  → total=0 ✗
GET /api/visits?date_from=2026-05-12 00:00:00            → total=0 ✗
GET /api/visits?date_from=2026-05-01&date_to=2026-05-31  → total=0 ✗
```

### Likely cause
The controller probably filters on `check_in_date_time` (a datetime field)
instead of `visit_date` (a date field). Draft visits have no check-in
yet, so any datetime-based filter drops them.

### Suggested fix
Switch the controller filter to `visit_date` and compare as a date:

```python
if date_from:
    domain.append(('visit_date', '>=', date_from))
if date_to:
    domain.append(('visit_date', '<=', date_to))
```

Accept `YYYY-MM-DD` (date-only) strings as the canonical format. If
clients send ISO datetimes (`2026-05-12T00:00:00Z`), strip the time
portion before comparison.

### Mobile workaround in place
The mobile now **does not send** `date_from` / `date_to` and applies the
Today/All filter client-side over the full list. This is fine for small
data volumes — please still fix so we can re-enable server-side filtering
once visits grow.

---

## 10. `GET /api/visits` missing `visit_date` field — Medium

Live response shape (admin session, today):

```json
{"id":14,"name":"/","customer":{...},"employee":{...},
 "check_in_time":null,"check_out_time":null, ...
 // no visit_date field
}
```

For draft visits the only date info is `visit_date` on the model, but
it's not serialized. The mobile can't do a precise Today filter
client-side for drafts — it currently includes **all** drafts under the
Today chip as a fallback.

### Suggested fix
Add the field to `_visit_to_dict`:

```python
'visit_date': visit.visit_date.isoformat() if visit.visit_date else None,
```

---

## 11. `customer.visit.create` via `call_kw` doesn't generate `name` — Medium

When the mobile creates a visit via:

```
POST /web/dataset/call_kw
{model: 'customer.visit', method: 'create', args: [{partner_id, salesperson_id, visit_date, ...}]}
```

…the new record's `name` stays as `/` (placeholder) instead of the
sequenced `VIS/00013`. Visits created from Odoo Web UI get the right
sequence; only mobile-created ones come out as `/`.

### Likely cause
There's probably an `action_create_visit` or a server action that's
hooked to the form's Save button which assigns `name = sequence.next_by_code(...)`.
Direct `call_kw('customer.visit', 'create')` bypasses it.

### Suggested fix
Move the sequence assignment into `create` itself (or use a `default=`
on the field):

```python
@api.model_create_multi
def create(self, vals_list):
    for vals in vals_list:
        if not vals.get('name') or vals.get('name') == '/':
            vals['name'] = self.env['ir.sequence'].next_by_code('customer.visit') or '/'
    return super().create(vals_list)
```

That way every create — UI, API, or `call_kw` — gets a proper sequence.

---

## 12. (Mobile side) — no backend change needed

For Manager edit-in-mobile (visit_date and description), the mobile uses
Odoo's standard `/web/dataset/call_kw` (`customer.visit.write`) over the
existing session cookie. This works today and respects the existing form
view / record-rule logic — no new endpoint needed unless you'd prefer one.

If you decide to add a dedicated `PUT /api/visits/<id>` later we'll
migrate the mobile to it; until then `call_kw` is fine.

---

## 13. Already deployed correctly ✅

For confidence — these are already shipped right and the mobile relies
on them:

- `POST /web/session/authenticate` returns `uid`, `username`,
  `employee_id`, `employee_name`, `partner_id`, `is_admin`, and session
  cookie. ✓
- `GET /api/customers?limit=...` returns `{status, data, total}` with
  partners that have coords. ✓
- ~~`GET /api/customers/<id>/nearby-employees`~~ — no longer used: the
  nearby-employees radar was removed from the app on 2026-09-16.
- `POST /api/visits/check-in` and `POST /api/visits/check-out` work and
  correctly transition the visit's `state` and `mobile_state`. ✓
- ~~`POST /api/employee/location`~~ — no longer used: live location
  sharing was removed from the app on 2026-09-16. The app sends location
  only for visits (start/end and the trail of a visit in progress).
- Security groups + record rules are set up correctly (Manager sees all,
  User sees own). ✓
- State machine `draft → submit → under_review → done` is correct. ✓

---

## 14. After you finish

Ping me. I'll do a single regression pass on the mobile (login flow,
visits list with Today/All, visit detail edit for both roles, in-range
badge, location dialog map). No mobile changes anticipated for any of
the asks above except removing the existing workarounds — everything is
already wired to consume the proper response shapes.

Thanks!

---

## 15. Error contract & localization (measured 2026-08-17)

Swept with `scratchpad/error_sweep.mjs` + `scratchpad/role_matrix_sweep.mjs`
against `dh-visits-new-main-35787218`, as all four visit roles. Every endpoint
is reachable or cleanly denied for every role, and every failure the app can
provoke now maps to a code it handles — so none of these block the app. They
are the things that would make the error contract stop needing client-side
compensation.

### 15.1 Errors carry no machine-readable code — **highest value**

The workflow refusals arrive only as English prose in `data.message`:

| Endpoint | What the server says |
|---|---|
| `approve` (not the approver) | `You are not authorized to approve or reject this visit. Only a manager in <name>'s management hierarchy…` |
| `start` (not approved) | `Only an approved visit can be started.` |
| `end` (not started) | `Only a visit in progress can be ended.` |
| `submit` (already submitted) | `Only draft or rescheduled visits can be submitted.` |
| `approve` (wrong state) | `This visit cannot be approved in its current state.` |
| `reject` (wrong state) | `This visit cannot be rejected in its current state.` |
| `end` (no outcome) | `The visit outcome is required before ending the visit.` |

The app now matches these sentences and substitutes its own translations
(`lib/core/api/server_message_l10n.dart`). **That match is on English text and
breaks the moment anyone rewords a message.**

**Ask:** add a stable symbol alongside the prose, e.g.

```json
{"error": {"code": "VALIDATION_ERROR",
           "data": {"rule": "visit_not_approved", "message": "Only an approved visit can be started."}}}
```

Any stable `rule` string works — the app keys off it and drops the text matching.

### 15.2 The server has only `en_US` installed

`res.lang.search_read([('active','=',true)])` → `["en_US"]`, and passing
`context: {lang: 'ar_001'}` raises `UserError: Invalid language code: ar_001`.
So the backend cannot answer an Arabic user in Arabic even when asked, which is
why the translation had to move to the client. Installing `ar_001` and
translating the module's `UserError` strings would let §15.1 be solved
server-side instead.

### 15.3 Validations that do not fire

Found while sweeping; each one lets bad data through:

- **`start` accepts no GPS at all.** `/api/visit/start` with neither `latitude`
  nor `longitude` succeeds and moves the visit to `in_progress`. The app always
  sends coordinates, so this is not currently visible — but the GPS stamp is
  the point of the check-in, and nothing on the server requires it.
- **`reschedule` accepts a date in the past** (`2020-01-01` was accepted on a
  draft *and* on a submitted visit).
- **`reject` accepts no reason** — `reject` with the `reason` key absent
  succeeds; only an *empty-string* reason is refused, and then with a
  state-machine message rather than a "reason required" one.

### 15.4 Smaller notes

- `crm.lead` is unreadable by **all four** visit roles, so the opportunity
  picker is empty for everyone. The app degrades correctly (localized "no
  permission" + retry), but an opportunity-type visit cannot be created against
  this database until the visit groups get read access to `crm.lead`.
- `add_participants` with a non-existent employee id surfaces Odoo's
  referential-integrity message, which names internal models and calls the
  record "the troublemaker". A `ValidationError` naming the bad id would be
  friendlier; the app currently replaces it wholesale.
- `/api/visit/register_device` is idempotent when the same user re-registers a
  token, but returned `Token already registered.` when a token row belonged to
  a *different* user. Registration is best-effort on the client so nothing
  breaks; an upsert keyed on the token would remove the case entirely.
