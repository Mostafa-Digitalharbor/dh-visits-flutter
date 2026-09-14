#!/usr/bin/env bash
# Downloads the OpenStreetMap extract and builds the OSRM (MLD, car) data set
# into ./data. Run on the OSRM host before the first start and on each map
# refresh (then `docker compose restart osrm`).
#
#   REGION_URL  default: Geofabrik GCC states (Saudi Arabia, UAE, Kuwait, Qatar,
#               Bahrain, Oman). Use a smaller extract only if every employee
#               works inside it.
#
# Preprocessing needs far more memory than serving; see
# docs/MAP_MATCHING_DEPLOYMENT.md for sizing.
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="ghcr.io/project-osrm/osrm-backend:v5.27.1"
REGION_URL="${REGION_URL:-https://download.geofabrik.de/asia/gcc-states-latest.osm.pbf}"

mkdir -p data
echo "Downloading ${REGION_URL}"
curl -fL --retry 3 -o data/region.osm.pbf.part "${REGION_URL}"
curl -fsL "${REGION_URL}.md5" | awk '{print $1"  data/region.osm.pbf.part"}' | md5sum -c -
mv data/region.osm.pbf.part data/region.osm.pbf

run() { docker run --rm -t -v "$PWD/data:/data" "$IMAGE" "$@"; }
# The car profile: employees drive between customers; the app requests the
# `driving` profile name, which osrm-routed serves from whatever data it loaded.
run osrm-extract -p /opt/car.lua /data/region.osm.pbf
run osrm-partition /data/region.osrm
run osrm-customize /data/region.osrm
echo "OSRM data ready in ./data. Start with: docker compose up -d"
