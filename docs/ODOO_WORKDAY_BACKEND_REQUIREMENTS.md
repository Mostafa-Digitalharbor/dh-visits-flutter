# OBSOLETE — cancelled 2026-09-16

> **Do not install, review or deploy the module described here.**

This file used to be the backend work request for the work-day tracking
feature: a new Odoo 19 module `dh_workday_tracking` (models
`dh.work.session` and `dh.work.location`, JSON-RPC routes under
`/api/workday/*`, record rules and a "Work Days (GPS)" menu) that would store
the employee's whole-day route next to `dh_visit_management`. The business
cancelled the feature on 2026-09-16 and the mobile app no longer uses it; live
location sharing, the "nearby employees" radar and the hr.attendance mirror
were removed at the same time.

Production must not call `/api/workday/*`, must not install
`dh_workday_tracking`, and must not write `x_dh_work_*` or `dh.work.*` models.
The only location data the app sends is the per-visit data of the existing
`/api/visit/*` contract (`start`, `end`, `log_locations` — see
[API.md](API.md)); the app-side design is in
[VISIT_TRACKING.md](VISIT_TRACKING.md). No backend work is requested for
location beyond that contract.
