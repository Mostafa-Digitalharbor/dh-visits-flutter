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
#   Sentry is compiled in only when SENTRY_DSN is non-empty (see AppEnvironment),
#   so the DSN below is what turns crash reporting ON for store builds. A Sentry
#   DSN is a write-only, client-side ingest key — it is designed to ship inside
#   the app binary and is not a secret. Override per-build with:
#     export SENTRY_DSN='https://...'      # different project
#     export SENTRY_DSN=''                 # disable Sentry for this build
#
# Usage:  scripts/build_release.sh [apk|aab]   (default: apk)
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-apk}"

# Default production Sentry project (Digital Harbor / visits). `${VAR-default}`
# (no colon) so an explicitly-exported empty string disables Sentry, while an
# unset variable still gets the default.
SENTRY_DSN="${SENTRY_DSN-https://e1c8ae84f3d415fa15d41ec6436c54b5@o4511426995617792.ingest.de.sentry.io/4511485485973584}"
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

# Flavour tags every Sentry event, so keep it alongside the DSN.
defines+=("--dart-define=APP_FLAVOR=${APP_FLAVOR}")
if [ -n "${SENTRY_DSN}" ]; then
  defines+=("--dart-define=SENTRY_DSN=${SENTRY_DSN}")
  defines+=("--dart-define=SENTRY_TRACES_PERCENT=${SENTRY_TRACES_PERCENT:-10}")
  echo "Sentry ENABLED (environment=${APP_FLAVOR})."
else
  echo "Sentry DISABLED (SENTRY_DSN is empty)."
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
