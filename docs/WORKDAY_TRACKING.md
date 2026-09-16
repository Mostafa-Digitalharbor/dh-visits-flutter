# OBSOLETE — cancelled 2026-09-16

> **Do not implement, deploy or document anything from this feature.**

This file used to describe "whole work-day route tracking": a Start Work Day /
End Work Day bar, a native background capture (`WorkdayLocationService` on
Android, `WorkdayLocation.swift` on iOS) that recorded the employee's movement
for the entire day — including travel between visits — a "Today's Route"
screen, and storage through `/api/workday/*` (module `dh_workday_tracking`,
models `dh.work.session` / `dh.work.location`) or, on the test server only,
the no-code models `x_dh_work_session` / `x_dh_work_location`. The business
cancelled the feature on 2026-09-16 and it has been removed from the app,
together with live location sharing, the manager "nearby employees" radar and
the hr.attendance mirror of visit start/end.

Production must not call `/api/workday/*` and must not write any
`x_dh_work_*` or `dh.work.*` model. The app now collects location only for
customer visits (Start Visit, End Visit, and the trail while a visit is in
progress); the current design is in [VISIT_TRACKING.md](VISIT_TRACKING.md). The
previous content of this file remains available in Git history.
