# Production map matching (OSRM) — deployment requirements

For the backend / DevOps team. The app is ready; **the server does not exist
yet**. Until it does, release builds draw routes as recorded GPS (no road
matching, nothing sent anywhere for it).

## 1. What it is for

```
recorded GPS (server, unchanged) → app → HTTPS → company OSRM /match → line drawn on the map
```

Today's Route and the visit route screens can draw a recorded route along the
roads instead of straight lines between fixes (**Roads / Raw GPS** switch).
Road matching only produces a line to draw: the recorded points, distances and
markers always come from the raw GPS. If the service is down, slow, rate
limited or disabled, the app draws the raw GPS line — a failure never breaks a
screen.

Development builds use the public demo server `router.project-osrm.org`.
Release builds **never** do: `AppEnvironment.resolveMapMatchingUrl` ignores it
and the release workflow fails if it is configured. The public server is not
allowed for production traffic, has no SLA, allows about 1 request/s and 10
points per request, and would receive employees' coordinates.

## 2. What the app sends

One GET per chunk of up to 90 fixes (`lib/core/map_matching/osrm_map_matcher.dart`):

```
GET /match/v1/driving/{lng,lat;...}?overview=false&steps=true&geometries=geojson
    &gaps=split&tidy=false&radiuses={8..40 m;...}&timestamps={0;5;11;...}[&bearings=...]
User-Agent: com.digitalharbor.location_gps
```

- Coordinates (6 decimals), each fix's accuracy as search radius, heading only
  while moving ≥ 3 m/s, and **relative** seconds since the first fix of the
  chunk (not the date or time of day).
- **No** user, employee or device identifier, no cookie, no Odoo session, no
  authorization header.
- Requests are serialised ≥ 1.1 s apart per device, cached on the device
  (30 days) so a route is matched once, and backed off for 1 minute after 429,
  5xx or a network error.
- The app expects the OSRM v5 `/match` response (`code`, `tracepoints`,
  `matchings[].legs[].steps[].geometry`). Any OSRM 5.x/6.x `osrm-routed` works.

## 3. Requirements

| Item | Requirement |
|---|---|
| Software | `osrm-routed` from `ghcr.io/project-osrm/osrm-backend` (kit pinned to `v5.27.1`), MLD algorithm, `car.lua` profile |
| Map data | OpenStreetMap extract covering every area employees work in. Default: Geofabrik `asia/gcc-states-latest.osm.pbf` (Saudi Arabia + GCC). Refresh monthly |
| Limits | `--max-matching-size 100` (the app sends ≤ 90; set `MAP_MATCHING_MAX_POINTS` to match if changed) |
| Endpoint | `https://<host>` with a **publicly trusted** TLS certificate (Android and iOS reject self-signed), HTTP/1.1 or 2, GET lines up to ~6 KB |
| Exposure | Only `GET /match/v1/{profile}/...`; everything else 404 |
| Rate limiting | Per client IP, e.g. 5 requests/s with burst 20, answering **429** (the app backs off) |
| Logging | Request paths contain coordinates: **do not log the URI/query** (the provided nginx log format omits it), or keep such logs ≤ 7 days with restricted access |
| Sizing (GCC extract) | Preprocessing: 4 vCPU, 16 GB RAM, ~20 GB disk (peaks during `osrm-extract`). Serving: 2 vCPU, 4–8 GB RAM. Verify with the real extract; Saudi-only is smaller |
| Latency target | p95 < 1 s for a 90-point match inside the region |
| Availability | Health check = `smoke_test.sh`; monitored; restart policy. Not critical-path: the app falls back to raw GPS |
| Hosting / privacy | Company-controlled, or a hosting provider under the company's data-processing agreement, in the approved region. The privacy policy must name the operator |

## 4. Deploy (kit in `deploy/osrm/`)

```bash
# on the OSRM host (Docker + compose installed)
git clone <mobile repo> && cd deploy/osrm
./prepare.sh                                  # download + extract/partition/customize → ./data
mkdir -p certs && cp /path/fullchain.pem /path/privkey.pem certs/
sed -i 's/osrm.example.com/osrm.yourcompany.com/' nginx/osrm.conf
docker compose up -d
./smoke_test.sh https://osrm.yourcompany.com            # must print PASS
POINTS=44 ./smoke_test.sh https://osrm.yourcompany.com  # larger trace, must PASS
```

`smoke_test.sh` sends the same request shape as the app over a recorded
Riyadh drive with several turns and fails unless every fix is snapped.

Map refresh: `./prepare.sh && docker compose restart osrm`.

## 5. Wire it into release builds

1. GitHub → repository **Settings → Secrets and variables → Actions → Variables**:
   - `MAP_MATCHING_URL` = `https://osrm.yourcompany.com`
   - `MAP_MATCHING_MAX_POINTS` = `90` (optional; match `--max-matching-size`)
2. `release.yml` passes both as `--dart-define` to the Android and iOS builds,
   and refuses a public demo URL. Local builds: export the same variables before
   `scripts/build_release.sh` / `build_release.ps1`.
3. Verify on a release build: Today's Route → **Roads** matches the streets;
   switch to **Raw GPS** to compare.

Without `MAP_MATCHING_URL` a release build hides the Roads switch and draws
recorded GPS.

## 6. Optional: no public endpoint

If exposing OSRM publicly is not acceptable, put it on a private network and
proxy `/match` through the Odoo backend (an authenticated JSON route that
forwards to OSRM). The app would then send coordinates only to the company
backend it already uses. That needs a small backend route and a change to
`OsrmMapMatcher` (base URL + session cookie); not implemented.

## 7. Status

| Step | State |
|---|---|
| App configuration (release never uses public OSRM; URL from build config; raw GPS fallback; cache; switch) | Done, unit-tested |
| Deployment kit (compose, nginx, prepare, smoke test) | Written; smoke test verified against the public demo server with 10 points only |
| Company OSRM server | **Not deployed** — needs infrastructure |
| Production endpoint tested | **No** |
