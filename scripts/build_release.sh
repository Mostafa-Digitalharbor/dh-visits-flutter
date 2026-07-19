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
# Usage:  scripts/build_release.sh [apk|aab]   (default: apk)
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-apk}"

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
