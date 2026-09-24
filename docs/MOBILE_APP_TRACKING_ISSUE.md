# Mobile App Issue: Workday GPS Points Are Not Reaching Odoo

## Summary

The Odoo visit form and workday tracking backend are installed and active, but
the production database currently contains **zero** `dh.work.location` GPS
points. Consequently, no continuous route appears in a visit's **Start / End
Tracking → Continuous GPS Tracking** section.

This is not an Odoo view issue. The mobile app must start a workday session and
upload GPS batches to the workday API. Points recorded while a visit is active
must include that visit's numeric Odoo ID in `visit_id`.

Observed on `dhv19` on 2026-09-20:

- Workday tracking view installed and active: yes
- Total stored workday GPS points: `0`
- GPS points linked to visits: `0`

## Required Mobile Flow

All routes below are authenticated Odoo JSON-RPC controller routes. Use the
authenticated Odoo session cookie and send `POST` requests with
`Content-Type: application/json`.

### 1. Start or recover the workday

Start the day with `POST /api/workday/start`:

```json
{
  "jsonrpc": "2.0",
  "params": {
    "client_uid": "workday-2026-09-20-user-33",
    "started_at": "2026-09-20 06:00:00",
    "latitude": 24.7136,
    "longitude": 46.6753,
    "device_id": "phone-device-id"
  }
}
```

Save `result.session.id` locally. `client_uid` must remain stable across
retries; this endpoint is idempotent.

After an app restart, call `POST /api/workday/active`. If it returns an active
session, resume uploads using that session ID rather than creating another
session.

### 2. Upload location batches

Send batches to `POST /api/workday/log_locations`:

```json
{
  "jsonrpc": "2.0",
  "params": {
    "session_id": 123,
    "points": [
      {
        "client_uid": "phone-device-id:1726812300000",
        "logged_at": "2026-09-20 06:05:00",
        "latitude": 24.7137,
        "longitude": 46.6755,
        "accuracy": 8.4,
        "altitude": 612.0,
        "speed": 1.5,
        "heading": 92.0,
        "device_id": "phone-device-id",
        "source": "track",
        "visit_id": 456
      }
    ]
  }
}
```

Rules:

- Send no more than 500 points per request.
- `logged_at` is UTC in `YYYY-MM-DD HH:MM:SS` format.
- Use a stable, unique `client_uid` for every recorded point. Retried uploads
  with the same ID are safely reported as duplicates.
- While no visit is active, omit `visit_id` or send `false`.
- While a visit is active, send its numeric Odoo record ID as `visit_id` on
  every point. This is what makes the route visible on that visit form.
- Queue points offline and retry them until Odoo confirms them as created or
  duplicates.
- Inspect `result.rejected`; HTTP 200 does not by itself mean every point was
  accepted because business errors and per-point rejections are returned in
  the JSON-RPC body.

Expected response:

```json
{
  "jsonrpc": "2.0",
  "result": {
    "session_id": 123,
    "created": 1,
    "duplicates": [],
    "rejected": [],
    "location_count": 1,
    "tracked_distance_km": 0.0
  }
}
```

### 3. End the workday

Flush all queued locations first, then call `POST /api/workday/end`:

```json
{
  "jsonrpc": "2.0",
  "params": {
    "session_id": 123,
    "ended_at": "2026-09-20 15:00:00",
    "latitude": 24.7138,
    "longitude": 46.6758
  }
}
```

No points can be added after the session has ended.

## Visit Linkage Requirement

Starting and ending a visit through `/api/visit/start` and `/api/visit/end`
only fills the visit's start/end coordinates. It does not automatically tag
continuous workday points.

The app must retain the active visit's Odoo ID and attach it as `visit_id` to
each workday location point collected during that visit. When the visit ends,
clear the active visit ID for subsequent workday-only points.

## Separate Deprecated API Issue

The app currently calls Odoo's legacy root `/jsonrpc` endpoint for login,
`res.users.search_read`, and `calendar.event.search_read`. Those calls still
work in Odoo 19, and their server warning has been suppressed, but the endpoint
is scheduled for removal in Odoo 22.

This does **not** prevent GPS tracking today. It should nevertheless be placed
on the mobile backlog and migrated to Odoo's `/json/2/<model>/<method>` API
before upgrading to Odoo 22. Do not replace the custom `/api/workday/*` routes;
they are separate application endpoints.

## Acceptance Criteria

1. Starting a workday returns and locally persists a valid `session.id`.
2. A test batch returns `created > 0` with an empty `rejected` array.
3. Retrying the same batch reports point indexes in `duplicates` and does not
   create duplicate database rows.
4. Points outside a visit are visible under **Employees → Work Days (GPS)**.
5. Points sent with `visit_id` appear on the corresponding visit under
   **Start / End Tracking → Continuous GPS Tracking**.
6. Offline points are uploaded after connectivity returns.
7. All queued points are flushed before ending the workday.

## Backend Reference

- Workday routes: `dh_workday_tracking/controllers/workday_api.py`
- GPS point validation: `dh_workday_tracking/models/work_location.py`
- Batch persistence and response: `dh_workday_tracking/models/work_session.py`
