#!/usr/bin/env bash
# Acceptance check for a map-matching server, using the exact request shape
# the app sends (lib/core/map_matching/osrm_map_matcher.dart): a recorded
# Riyadh drive with turns, per-fix radiuses, relative timestamps, gaps=split,
# tidy=false, steps + GeoJSON.
#
#   ./smoke_test.sh https://osrm.yourcompany.com          # production check
#   POINTS=10 ./smoke_test.sh https://router.project-osrm.org --allow-demo
#
# Passes when the server answers Ok, snaps every fix, and accepts a
# production-sized trace (default 12 points; the app sends up to 90).
set -euo pipefail

BASE="${1:?usage: smoke_test.sh <base-url> [--allow-demo]}"
BASE="${BASE%/}"
POINTS="${POINTS:-12}"
if [[ "$BASE" == *project-osrm.org* || "$BASE" == *routing.openstreetmap.de* ]] && [[ "${2:-}" != "--allow-demo" ]]; then
  echo "FAIL: $BASE is a public demo server, not a production endpoint." >&2
  exit 2
fi

# lng,lat — 44 fixes recorded along real streets (turns at Al Olaya /
# As Sudah / Al Anjab), about 40 m apart, 5 s apart.
TRACE=(
  46.683047,24.716873 46.683417,24.717008 46.683746,24.717187 46.684113,24.717332
  46.684484,24.717498 46.684778,24.717508 46.684941,24.717189 46.685124,24.716866
  46.685280,24.716541 46.685405,24.716308 46.685584,24.715988 46.685755,24.715645
  46.685898,24.715337 46.686100,24.715044 46.686413,24.715123 46.686609,24.714803
  46.686868,24.714749 46.687048,24.714804 46.687397,24.714965 46.687777,24.715111
  46.688096,24.715283 46.688453,24.715394 46.688743,24.715353 46.689121,24.715538
  46.689451,24.715699 46.689834,24.715848 46.690187,24.716004 46.690469,24.716219
  46.690773,24.716374 46.691130,24.716537 46.691490,24.716689 46.691838,24.716850
  46.692028,24.716933 46.692301,24.716901 46.692476,24.716578 46.692759,24.716520
  46.693115,24.716655 46.693278,24.716751 46.693427,24.716409 46.693792,24.716572
  46.693801,24.716846 46.693632,24.717145 46.693445,24.717482 46.693219,24.717880
)
(( POINTS >= 2 && POINTS <= ${#TRACE[@]} )) || { echo "POINTS must be 2..${#TRACE[@]}" >&2; exit 2; }

coords=""; radiuses=""; stamps=""
for ((i = 0; i < POINTS; i++)); do
  sep=$([ "$i" -eq 0 ] && echo "" || echo ";")
  coords+="${sep}${TRACE[$i]}"
  radiuses+="${sep}10"
  stamps+="${sep}$((i * 5))"
done
URL="${BASE}/match/v1/driving/${coords}?overview=false&steps=true&geometries=geojson&gaps=split&tidy=false&radiuses=${radiuses}&timestamps=${stamps}"

started=$(date +%s%N)
body="$(curl -fsS --max-time 20 -A 'com.digitalharbor.location_gps smoke-test' "$URL")" || {
  echo "FAIL: request failed (network, TLS or HTTP error)" >&2; exit 1; }
elapsed_ms=$(( ($(date +%s%N) - started) / 1000000 ))

# `|| true`: grep exits 1 on "no match", which pipefail would turn into a
# silent exit of the whole script.
code="$(printf '%s' "$body" | { grep -o '"code":"[A-Za-z]*"' || true; } | head -1 | cut -d'"' -f4)"
unmatched="$(printf '%s' "$body" | { grep -o '"tracepoints":\[null\|,null' || true; } | wc -l | tr -d ' ')"
matchings="$(printf '%s' "$body" | { grep -o '"matchings_index"' || true; } | wc -l | tr -d ' ')"
echo "points=${POINTS} code=${code:-?} snapped=${matchings} unmatched=${unmatched} time=${elapsed_ms}ms"

if [ "$code" != "Ok" ]; then
  echo "FAIL: expected code Ok" >&2; exit 1
fi
if [ "$matchings" -ne "$POINTS" ]; then
  echo "FAIL: not every fix was snapped to a road — wrong map extract?" >&2; exit 1
fi
echo "PASS"
