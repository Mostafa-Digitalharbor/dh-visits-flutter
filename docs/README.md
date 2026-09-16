# Customer Visits — Mobile API Reference (LEGACY)

> **Legacy reference.** This file documents the early `dh_customer_visits`
> API. The app now talks to `dh_visit_management`; the current contract is
> [API.md](API.md), and location handling is in
> [VISIT_TRACKING.md](VISIT_TRACKING.md). Live location sharing
> (`/api/employee/location`) and the nearby-employees radar were **removed
> from the app on 2026-09-16** (together with the work-day route and the
> hr.attendance mirror); the app collects location only for customer visits.

Backend: Odoo 19 module `dh_customer_visits`.
Audience: Flutter mobile developer.
Base URL (dev): `https://dh-abdelrahmanwael-odoo-19-test.odoo.com`
DB name: `dh-abdelrahmanwael-odoo-19-test`

All responses JSON. All timestamps ISO 8601 UTC (`...Z`). All distances meters.

---

## 1. Architecture

- Employee performs **check-in** at customer site → server records timestamp + coords.
- Employee performs **check-out** when done → server records timestamp + coords + duration.
- No periodic location pings and no "nearby employees" lookup: both were removed from the app (2026-09-16).

---

## 2. Authentication

Odoo session cookie based. Login once → server returns `Set-Cookie: session_id=...`. Send cookie on every subsequent request.

### Login

`POST /web/session/authenticate`
Content-Type: `application/json`

```json
{
  "jsonrpc": "2.0",
  "params": {
    "db": "dh-abdelrahmanwael-odoo-19-test",
    "login": "user@example.com",
    "password": "********"
  }
}
```

**Response:**

```json
{
  "result": {
    "uid": 7,
    "username": "Ahmed",
    "session_id": "abcdef...",
    "employee_id": 12,
    "employee_name": "Ahmed Ali",
    "company_id": 1
  }
}
```

Store `session_id` cookie + `employee_id`. `employee_id` needed for some client-side filtering.

### Logout

`POST /web/session/destroy`

```json
{"jsonrpc": "2.0", "params": {}}
```

### Session check

`POST /web/session/get_session_info` → returns current session info or empty if expired.

### Flutter client setup

Use `dio` with `CookieManager` (package `dio_cookie_manager` + `cookie_jar`). Persist cookie jar across restarts. Add interceptor that on 401 / `AUTH_REQUIRED` redirects to login screen.

---

## 3. Endpoints

All endpoints below require auth cookie. Errors follow uniform envelope (§4).

### 3.1 List customers

`GET /api/customers`

Query params:
- `search` — optional, matches partner name or phone.
- `limit` — default 80.
- `offset` — default 0.

**Response:**

```json
{
  "status": "success",
  "data": [
    {
      "id": 25,
      "name": "Acme Corp",
      "latitude": 30.044420,
      "longitude": 31.235712,
      "address": "Cairo, Egypt",
      "phone": "+201234567890"
    }
  ],
  "total": 120
}
```

Customers without coordinates excluded automatically.

### 3.2 Customer details

`GET /api/customers/<id>`

**Response:**

```json
{
  "status": "success",
  "data": {
    "id": 25,
    "name": "Acme Corp",
    "latitude": 30.044420,
    "longitude": 31.235712,
    "address": "...",
    "phone": "...",
    "mobile": "...",
    "last_visit": {
      "id": 88,
      "employee_name": "Ahmed",
      "check_in_time": "2026-05-10T09:30:00Z",
      "check_out_time": "2026-05-10T10:15:00Z"
    }
  }
}
```

`last_visit` is `null` if no prior visit.

### 3.3 Check-in

`POST /api/visits/check-in`

```json
{
  "customer_id": 25,
  "latitude": 30.044418,
  "longitude": 31.235715,
  "timestamp": "2026-05-11T09:30:00Z"
}
```

Server validation:
- User must have linked `hr.employee`.
- No open visit (state `checked_in`) on same customer.
- Customer must have coordinates.
- Coord ranges: lat `-90..90`, lng `-180..180`.

**Response (success):**

```json
{
  "status": "success",
  "data": {
    "visit_id": 101,
    "state": "checked_in",
    "check_in_time": "2026-05-11T09:30:00Z"
  }
}
```

**Response (already open):**

```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Employee already checked-in for this customer",
    "details": {"open_visit_id": 99}
  }
}
```

Cache `visit_id` locally until check-out succeeds.

### 3.4 Check-out

`POST /api/visits/check-out`

```json
{
  "visit_id": 101,
  "latitude": 30.044420,
  "longitude": 31.235710,
  "timestamp": "2026-05-11T10:15:00Z",
  "notes": "تم تسليم العرض"
}
```

`notes` optional. Server enforces: visit owner == current user, visit checked-in but not yet checked-out.

**Response:**

```json
{
  "status": "success",
  "data": {
    "visit_id": 101,
    "state": "checked_out",
    "check_out_time": "2026-05-11T10:15:00Z",
    "duration_minutes": 45
  }
}
```

### 3.5 ~~Update live location~~ — REMOVED

`POST /api/employee/location` is **not used** by the app any more (live
location sharing was removed on 2026-09-16). Do not call it. The only location
data the app sends is per visit: Start/End coordinates and the trail of a
visit in progress (`/api/visit/start`, `/api/visit/end`,
`/api/visit/log_locations` — see [API.md](API.md)).

### 3.6 ~~Nearby employees~~ — REMOVED

`GET /api/customers/<customer_id>/nearby-employees` is **not used** by the app
any more (the manager "nearby employees" radar was removed on 2026-09-16).

### 3.7 Visits history

`GET /api/visits`

Query params (all optional):
- `customer_id`
- `employee_id`
- `date_from` — ISO datetime, filters by `check_in_time >=`.
- `date_to` — ISO datetime, filters by `check_in_time <=`.
- `state` — `checked_in` | `checked_out` | omit for all.
- `limit` (default 80), `offset`.

**Response:**

```json
{
  "status": "success",
  "data": [
    {
      "id": 101,
      "name": "VIS/00101",
      "customer": {"id": 25, "name": "Acme Corp"},
      "employee": {"id": 12, "name": "Ahmed Ali"},
      "check_in_time": "2026-05-11T09:30:00Z",
      "check_out_time": "2026-05-11T10:15:00Z",
      "duration_minutes": 45,
      "state": "checked_out"
    }
  ],
  "total": 38
}
```

Record rules: standard users only see own visits; managers see all.

---

## 4. Error envelope

All non-2xx responses follow this shape:

```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human readable",
    "details": {}
  }
}
```

HTTP status + `code` mapping:

| HTTP | `code` | Meaning |
|------|--------|---------|
| 401 | `AUTH_REQUIRED` | Missing or expired session. Re-login. |
| 403 | `PERMISSION_DENIED` | User lacks permission for resource. |
| 404 | `NOT_FOUND` | Resource missing. |
| 400 | `VALIDATION_ERROR` | Bad payload, business rule violation. |
| 400 | `LOCATION_REQUIRED` | Customer has no coordinates. |
| 500 | `SERVER_ERROR` | Backend bug. Report. |

Flutter pattern:

```dart
Future<Map<String, dynamic>> _handle(Response r) async {
  final body = r.data is String ? jsonDecode(r.data) : r.data;
  if (body['status'] == 'error') {
    throw ApiError(body['error']['code'], body['error']['message'], body['error']['details']);
  }
  return body['data'];
}
```

---

## 5. State machine

Mobile sees two states only:

- `checked_in` — visit has `check_in_time` but no `check_out_time`.
- `checked_out` — visit has both.

Backend keeps additional admin states (`draft`, `submit`, `under_review`, `done`, `cancel`) — ignore from mobile. `mobile_state` field already serialized in responses.

Flow:

```
[no visit]
   |
   v
POST /api/visits/check-in
   |
   v
checked_in --(stays until check-out)
   |
   v
POST /api/visits/check-out
   |
   v
checked_out (terminal)
```

---

## 6. Data models (read-only reference)

### `customer.visit`

| Field | Type | Notes |
|-------|------|-------|
| `id` | int | |
| `name` | str | `VIS/00001`-style sequence |
| `partner_id` | many2one res.partner | customer |
| `employee_id` | many2one hr.employee | derived from salesperson_id.user.employee |
| `check_in_date_time` | datetime UTC | |
| `check_in_lat` / `check_in_lng` | float | digits(16,6) |
| `check_out_date_time` | datetime UTC | nullable |
| `check_out_lat` / `check_out_lng` | float | nullable |
| `duration_minutes` | int | computed |
| `state` (backend) | selection | draft/submit/under_review/done/cancel |
| `mobile_state` | selection | checked_in / checked_out |
| `description` | text | notes |

### `hr.employee` extensions (legacy, not used by the app)

These fields belonged to the removed live-location feature; the app neither
reads nor writes them.

| Field | Type |
|-------|------|
| `current_latitude` | float |
| `current_longitude` | float |
| `last_location_update` | datetime UTC |
| `location_sharing` | bool |

### `res.partner` (used as customer)

Existing fields: `name`, `partner_latitude`, `partner_longitude`, `street`, `city`, `phone`, `mobile`, `country_id`.

---

## 7. Flutter project skeleton (suggested)

```
lib/
  core/
    api_client.dart        # Dio + cookie manager + error mapper
    auth_service.dart      # login/logout, session restore
    location_service.dart  # geolocator + periodic send
  features/
    customers/
      models/customer.dart
      data/customer_repo.dart
      ui/customer_list_page.dart
      ui/customer_detail_page.dart
    visits/
      models/visit.dart
      data/visit_repo.dart
      ui/check_in_page.dart
      ui/visit_history_page.dart
  main.dart
```

Required packages:
- `dio` + `dio_cookie_manager` + `cookie_jar`
- `geolocator` (location)
- `flutter_map` or `google_maps_flutter` (map)
- `flutter_secure_storage` (persist session)
- `riverpod` or `bloc` (state)
- `freezed` + `json_serializable` (models)

Permissions (as shipped — see docs/VISIT_TRACKING.md):
- Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` (visit trail while a visit is in progress), `INTERNET`. `ACCESS_BACKGROUND_LOCATION` is not used: the foreground service is started from the foreground.
- iOS: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` (required because `geolocator_apple` links the Always API, and lets Settings offer "Always"; the app never asks for it), `NSLocationTemporaryUsageDescriptionDictionary`, `UIBackgroundModes` = `location` (visit trail only; "While Using" is sufficient).

Location use: only for customer visits — one fix at Start, one at End, and
the trail while the visit is in progress (sampling and upload rules in
docs/VISIT_TRACKING.md). No periodic location pings.

---

## 8. Sample Dio client

```dart
class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  Future<Map<String, dynamic>> _unwrap(Response r) async {
    final body = r.data is String ? jsonDecode(r.data) : r.data;
    if (body is Map && body['status'] == 'error') {
      final err = body['error'];
      throw ApiError(err['code'], err['message'], err['details']);
    }
    if (body is Map && body.containsKey('data')) return Map<String, dynamic>.from(body);
    return Map<String, dynamic>.from(body);
  }

  Future<List<Customer>> listCustomers({String? search, int limit = 80, int offset = 0}) async {
    final r = await _dio.get('/api/customers', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'limit': limit,
      'offset': offset,
    });
    final body = await _unwrap(r);
    return (body['data'] as List).map((e) => Customer.fromJson(e)).toList();
  }

  Future<int> checkIn(int customerId, double lat, double lng) async {
    final r = await _dio.post('/api/visits/check-in', data: {
      'customer_id': customerId,
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
    final body = await _unwrap(r);
    return body['data']['visit_id'] as int;
  }

  Future<int> checkOut(int visitId, double lat, double lng, {String? notes}) async {
    final r = await _dio.post('/api/visits/check-out', data: {
      'visit_id': visitId,
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (notes != null) 'notes': notes,
    });
    final body = await _unwrap(r);
    return body['data']['duration_minutes'] as int;
  }
}
```

---

## 9. Login example (curl)

```bash
# Login
curl -c cookies.txt -X POST https://dh-abdelrahmanwael-odoo-19-test.odoo.com/web/session/authenticate \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","params":{"db":"dh-abdelrahmanwael-odoo-19-test","login":"<login>","password":"<password>"}}'

# List customers
curl -b cookies.txt "https://dh-abdelrahmanwael-odoo-19-test.odoo.com/api/customers?limit=10"

# Check-in
curl -b cookies.txt -X POST https://dh-abdelrahmanwael-odoo-19-test.odoo.com/api/visits/check-in \
  -H "Content-Type: application/json" \
  -d '{"customer_id":25,"latitude":30.0444,"longitude":31.2357,"timestamp":"2026-05-11T09:30:00Z"}'
```

---

## 10. Edge cases to handle in mobile

- **Cold start with active visit:** on app launch, call `GET /api/visits?state=checked_in&employee_id=<self>` to detect any open visit. Resume check-out flow if found.
- **Network loss during check-in:** queue request; retry until success. Backend rejects duplicate via "already checked-in" guard, so dedupe is automatic.
- **Network loss during a visit:** trail points are buffered on the device with their real fix time and uploaded later (even after the visit ended); the server accepts them while they fall inside the visit's start–end window. See docs/VISIT_TRACKING.md.
- **Clock skew:** always send `timestamp` from device, server trusts it for `check_in_time` etc. If device clock is wrong, visit timeline will be wrong. Consider syncing via NTP / using `DateTime.now().toUtc()` only.
- **Background mode:** location is collected in the background only while a visit is in progress — through an Android foreground service (type `location`) and iOS background location updates started from the foreground (While Using is sufficient). Nothing before Start, between visits or after End. See docs/VISIT_TRACKING.md.
- **Session expiry:** intercept 401 → redirect to login, preserve in-flight check-in payload to retry after re-auth.
- **Customers without coords:** never appear in `/api/customers`. If user opens deep link to such customer, `GET /api/customers/<id>` returns full record but check-in will fail with `LOCATION_REQUIRED`.

---

## 11. Open backend questions (not yet decided)

- Min distance threshold to allow check-in (spec §7 Q1) — currently no enforcement, any distance accepted.
- Webhook on check-in / check-out — not implemented.
- (Closed 2026-09-16: the nearby-employees radius and live-location history questions no longer apply — both features were removed from the app.)

Mobile dev: assume current behavior, flag any of the above if business changes mind.

---

## 12. Install / restart backend

```bash
# in Odoo server
./odoo-bin -d dh-abdelrahmanwael-odoo-19-test -u dh_customer_visits --stop-after-init
# then restart Odoo service
```

Or via UI: Apps → Update Apps List → search "Customer Visits" → Upgrade.

---

## 13. Test credentials (dev only)

- URL: `https://dh-abdelrahmanwael-odoo-19-test.odoo.com`
- DB: `dh-abdelrahmanwael-odoo-19-test`
- Login: `<login>`
- Password: `<password>` — from the team password manager, never in Git.

The password previously written here was in Git history: treat it as exposed
and rotate it on that instance.
