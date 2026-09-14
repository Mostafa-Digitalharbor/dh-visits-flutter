#!/usr/bin/env bash
# Canonical release build for the Visits app.
#
# IMPORTANT: always build with --no-tree-shake-icons.
# The app renders its icons from the `material_symbols_icons` package, which
# ships VARIABLE icon fonts. Flutter's release icon tree-shaker corrupts/drops
# some variable-font glyphs, so a plain `flutter build apk` silently produces
# an app where random icons (settings, groups, analytics KPIs, trend arrows,
# nav icons, ...) render BLANK. Disabling icon tree-shaking keeps every glyph.
# See docs/ICONS_TREE_SHAKING.md for the full write-up.
#
# Backend seeding:
#   A release build does NOT bake in any company's server address — the app is
#   multi-tenant and asks for it on the setup screen. To pre-seed a build for
#   one customer (or to keep your own test loop flag-free), export these first:
#
#     export API_BASE_URL='https://yourcompany.odoo.com'
#     export ODOO_DATABASE='yourcompany-main-12345678'
#
# Crash reporting:
#   A RELEASE build always reports, using the project DSN baked into
#   AppEnvironment._releaseDsn. This script no longer carries its own copy —
#   two copies drift, and the one that drifts is always the one that mattered.
#   Point a build at a different Sentry project with:
#     export SENTRY_DSN='https://...'
#   There is deliberately no "disable Sentry" switch for a release build: a
#   store binary with no crash reporting is a silent regression nobody notices
#   until they need a stack trace and there isn't one.
#
# Usage:  scripts/build_release.sh [apk|aab]   (default: apk)
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-apk}"

# Left empty unless the caller overrides it: AppEnvironment owns the default.
# Note the emptiness test further down — passing `--dart-define=SENTRY_DSN=`
# with an EMPTY value would NOT fall back to the code's default, it would WIN
# over it, because String.fromEnvironment only uses its defaultValue when the
# key is absent.
SENTRY_DSN="${SENTRY_DSN:-}"
APP_FLAVOR="${APP_FLAVOR:-production}"

# Pass the backend through only when it was supplied. Absent = the built app
# starts on the server-setup screen, which is the correct multi-tenant default.
defines=()
[ -n "${API_BASE_URL:-}" ] && defines+=("--dart-define=API_BASE_URL=${API_BASE_URL}")
[ -n "${ODOO_DATABASE:-}" ] && defines+=("--dart-define=ODOO_DATABASE=${ODOO_DATABASE}")

if [ ${#defines[@]} -gt 0 ]; then
  echo "Seeding backend from environment (${#defines[@]} define(s))."
else
  echo "No backend seeded - the app will open on the server-setup screen."
fi

# Road matching for route display: the company-controlled OSRM server
# (docs/MAP_MATCHING_DEPLOYMENT.md). Unset = routes drawn as recorded GPS.
# A release build never uses a public demo router, so refuse one here.
#   export MAP_MATCHING_URL='https://osrm.yourcompany.com'
case "${MAP_MATCHING_URL:-}" in
  *project-osrm.org*|*routing.openstreetmap.de*)
    echo "MAP_MATCHING_URL points at a public OSRM demo server; use the company server." >&2
    exit 1 ;;
esac
if [ -n "${MAP_MATCHING_URL:-}" ]; then
  defines+=("--dart-define=MAP_MATCHING_URL=${MAP_MATCHING_URL}")
  echo "Road matching -> ${MAP_MATCHING_URL}"
else
  echo "Road matching -> off (no MAP_MATCHING_URL); routes show recorded GPS."
fi
[ -n "${MAP_MATCHING_MAX_POINTS:-}" ] && defines+=("--dart-define=MAP_MATCHING_MAX_POINTS=${MAP_MATCHING_MAX_POINTS}")

# Flavour tags every Sentry event, so keep it alongside the DSN.
defines+=("--dart-define=APP_FLAVOR=${APP_FLAVOR}")
defines+=("--dart-define=SENTRY_TRACES_PERCENT=${SENTRY_TRACES_PERCENT:-10}")
if [ -n "${SENTRY_DSN}" ]; then
  defines+=("--dart-define=SENTRY_DSN=${SENTRY_DSN}")
  echo "Sentry -> overridden project (environment=${APP_FLAVOR})."
else
  echo "Sentry -> project default from AppEnvironment (environment=${APP_FLAVOR})."
fi

# Required, not hygiene. `flutter_native_splash` is a dev_dependency, so its
# Android module is on the debug classpath but excluded from release builds.
# GeneratedPluginRegistrant.java left behind by a previous debug build still
# registers it, and the release compile then dies with the very unhelpful
#   "package net.jonhanson.flutter_native_splash does not exist".
# Cleaning forces the registrant to be regenerated for the release variant.
echo "Cleaning (stale debug plugin registrant breaks release builds)..."
flutter clean
flutter pub get

echo "Generating localizations..."
flutter gen-l10n

if [ "$target" = "aab" ]; then
  echo "Building release App Bundle (--no-tree-shake-icons)..."
  flutter build appbundle --release --no-tree-shake-icons "${defines[@]}"
else
  echo "Building release APK (--no-tree-shake-icons)..."
  flutter build apk --release --no-tree-shake-icons "${defines[@]}"
fi

echo "Done. NEVER build the release without --no-tree-shake-icons."
