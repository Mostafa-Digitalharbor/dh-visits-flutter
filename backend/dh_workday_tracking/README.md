# dh_workday_tracking (Odoo 19)

Whole-workday GPS route for the Visits mobile app: Start Work Day → movement →
visits → End Work Day, with dedicated `/api/workday/*` routes and server-side
rules. It replaces the temporary no-code models `x_dh_work_session` /
`x_dh_work_location` that exist only on the dummy server.

**Status:** reference implementation. The `dh_visit_management` source was not
available, so this is a separate addon depending on it (security groups and
`dh.visit`). Install it next to `dh_visit_management`, or move `models/`,
`controllers/`, `security/` and `views/` into that module. **Not installed on
any company server yet.**

The contract and rules are documented in
[docs/WORKDAY_TRACKING.md §2](../../docs/WORKDAY_TRACKING.md). `/api/visit/*`
and `dh.visit.location.log` are not touched.

## Install

1. Put this directory on the Odoo addons path (Odoo.sh: commit it to the
   custom-addons repository branch).
2. Update the apps list, install **DH Workday Tracking** (depends on `hr` and
   `dh_visit_management`).
3. Check as an employee: `POST /api/workday/active` → `{"session": false}`.
4. The app switches to the dedicated API by itself on the next sign-in (it probes
   `/api/workday/active`).

Every visit user needs an `hr.employee` linked to their user; without one the
routes answer "Your user is not linked to an employee".

## Security summary

| Group | Work days | Points |
|---|---|---|
| `group_visit_user` | read/start/end **own** | read/add to **own active** day |
| `group_visit_manager` (+ project manager) | + read the team below them (`hr.employee` hierarchy) | + read the team's |
| `group_visit_admin` | read all, close an open day | read all |
| `base.group_system` | full, incl. delete (retention) | read, create, delete (never write) |

Python guards apply on top of the rules to every caller (API and `call_kw`):
ownership, no reopening, immutable start, append-only points, validation. SQL:
partial unique index for one active day per employee, unique client uids,
coordinate and time CHECK constraints.

## Tests

```bash
odoo-bin -d <test_db> --addons-path=<odoo>/addons,<path containing dh_visit_management>,<repo>/backend \
  -i dh_workday_tracking --test-tags /dh_workday_tracking --stop-after-init
```

- `tests/test_workday_models.py` — lifecycle, one active day (DB index),
  idempotency, validation, append-only, no point after the end, ownership,
  visit visibility, record rules for employee / manager / outsider / admin.
- `tests/test_workday_api.py` — the HTTP routes end to end as employee,
  another employee and manager.

The visit fixture (`WorkdayFixture.visit`) sets what the real
`dh_visit_management` 19.0.2.1.0 requires, read over RPC from the regression
server (Odoo 19.0+e) on 2026-09-14: `visit_type`, `employee_id`,
`scheduled_datetime`, `purpose`, and a `project_id` for a project visit (the
module rejects one without: "A project is required for a project visit").
`test_record_rules` only requires the administrator to see the test's own days,
so the suite also runs on a database that already holds work days.

Compatibility with the real module, checked read-only on that server: the
group xml ids `group_visit_user` / `group_visit_manager` /
`group_visit_project_manager` / `group_visit_admin` exist; `dh.visit` has
`employee_id`, `user_id`, `manager_user_ids`, `company_id`. Its team rule uses
`manager_user_ids`, while this module's manager rule follows the `hr.employee`
hierarchy (`child_of`) — the same people when managers are set as the
employee's `parent_id`, as on that server.

Verified 2026-09-14 on Odoo 19.0 community (nightly 20260913, Python 3.12,
PostgreSQL 16) with a test stub of `dh_visit_management` reproducing those
groups, `dh.visit` required fields, the project constraint and the record rules:
**17 tests, 0 failures**, plus 22 concurrency checks against the running server
and the Flutter `WorkdayRepository` integration test. **Not installed or run on
the real module** — its source is not available here and the servers are
Odoo.sh / odoo.com instances this environment cannot deploy to.
