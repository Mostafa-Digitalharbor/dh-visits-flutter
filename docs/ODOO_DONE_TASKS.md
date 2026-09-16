# Odoo Task — Visits Mobile APP

**Task name:** Visits Mobile App — Delivered Features (v1.0.2)
**Project:** Visits Mobile APP
**Assignees:** Mustafa Badr
**Tags:** Mobile, Backend, Maps, DevOps, Release
**Deadline:** 2026-09-14
**Stage:** Done

---

## Description

### 1. Secure employee sign-in
Odoo login with a saved secure session, auto sign-out on session expiry.

### 2. Connect the app to any company server
First-run setup for the Odoo server URL and database, changeable later from Profile.

### 3. Show each user only what their role allows
Separate Employee and Manager interfaces based on Odoo visit groups.

### 4. Find customers quickly
Customer search, list/map view, and a details page with call, email and directions.

### 5. Plan visits from the app
Create project or opportunity visits with a schedule, purpose, owner and participants.

### 6. Control visits through approvals
Submit, approve, reject, reschedule, cancel, escalate, and participant approvals.

### 7. Prove the employee was really at the customer
GPS check-in/out with a distance check, arrival signature, and fake-GPS detection logged to Odoo.

### 8. Keep evidence on every visit
Camera photos and file attachments: upload, view and download.

### 9. Track visit history
Visits list with date/status filters and a full visit details page.

### 10. Let managers close visits fast
Review queue: approve to finish a visit, reject to send it back.

### 11. ~~See the team in the field live~~ — OBSOLETE (cancelled 2026-09-16)
~~Live employee location while the app is open, plus employees near a customer.~~
Live location sharing and the "nearby employees" radar were removed from the app.

### 12. Give managers a daily overview
Dashboard with KPIs, a map of the visits in progress (at their Start Visit positions) and an on-time leaderboard.

### 13. Measure team performance
Analytics: visit count, on-time rate, field km, average duration, weekly chart.

### 14. Alert users to visit updates
In-app notifications and Firebase push that opens the related visit.
*Pending: the push sending on the Odoo side.*

### 15. Keep working without internet
Offline check-in/out saved on the device and synced automatically when back online.

### 16. Show the route of each visit
GPS trail recorded only while a visit is in progress — also in the background and with the screen locked (native Android foreground service and iOS background location), with the required privacy disclosure — uploaded through `/api/visit/log_locations` and shown on a map. Design: docs/VISIT_TRACKING.md.

### 17. ~~Record the full workday route~~ — OBSOLETE (cancelled 2026-09-16)
~~Start/End Work Day tracking in the background (native Android and iOS), with the required privacy disclosure.~~
Removed from the app; background location is used only during an active visit (item 16).

### 18. Draw visit routes on real roads
Visit trail drawn along roads (OSRM map matching of that visit's points only), raw GPS stays authoritative. Optional.
*Pending: the production OSRM server.*

### 19. ~~Store workday routes in Odoo~~ — OBSOLETE (cancelled 2026-09-16)
~~New Odoo 19 module `dh_workday_tracking`: API, role-based access and tests.~~
Not to be installed; production must not call `/api/workday/*` or write `x_dh_work_*` / `dh.work.*` models.

### 20. Fit every user's preferences
Profile screen, Arabic/English, and light/dark theme.

### 21. Deliver a consistent, fast UI
New company design system, phone and tablet support, and performance improvements.

### 22. Catch crashes early
Sentry crash and error reporting in production builds.

### 23. Protect quality with tests
26 automated test files plus an end-to-end visit test against a real Odoo server.

### 24. Automate builds and releases
CI on every push, and tag-based upload to Google Play and TestFlight.

### 25. Get the app ready for the stores
Store listings (AR/EN), screenshots, privacy policy, and Apple/Google compliance.
