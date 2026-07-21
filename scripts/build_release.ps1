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
#   one customer (or to keep your own test loop flag-free), set these first:
#
#     $env:API_BASE_URL  = 'https://yourcompany.odoo.com'
#     $env:ODOO_DATABASE = 'yourcompany-main-12345678'
#
# Crash reporting:
#   Sentry is compiled in only when SENTRY_DSN is non-empty (see AppEnvironment),
#   so the DSN below is what turns crash reporting ON for store builds. A Sentry
#   DSN is a write-only, client-side ingest key - it is designed to ship inside
#   the app binary and is not a secret. Override per-build with:
#     $env:SENTRY_DSN = 'https://...'   # different project
#     $env:SENTRY_DSN = ''              # disable Sentry for this build
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1          # APK
#   powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1 aab      # App Bundle

param(
    [ValidateSet('apk', 'aab')]
    [string]$Target = 'apk'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

# Default production Sentry project (Digital Harbor / visits). Test for the
# variable's *existence* rather than truthiness, so setting it to '' explicitly
# disables Sentry while leaving it unset picks up the default.
if (Test-Path env:SENTRY_DSN) {
    $sentryDsn = $env:SENTRY_DSN
} else {
    $sentryDsn = 'https://e1c8ae84f3d415fa15d41ec6436c54b5@o4511426995617792.ingest.de.sentry.io/4511485485973584'
}
if ($env:APP_FLAVOR) { $appFlavor = $env:APP_FLAVOR } else { $appFlavor = 'production' }
if ($env:SENTRY_TRACES_PERCENT) { $tracesPct = $env:SENTRY_TRACES_PERCENT } else { $tracesPct = '10' }

# Pass the backend through only when it was supplied. Absent = the built app
# starts on the server-setup screen, which is the correct multi-tenant default.
$defines = @()
if ($env:API_BASE_URL)  { $defines += "--dart-define=API_BASE_URL=$($env:API_BASE_URL)" }
if ($env:ODOO_DATABASE) { $defines += "--dart-define=ODOO_DATABASE=$($env:ODOO_DATABASE)" }

if ($defines.Count -gt 0) {
    Write-Host "Seeding backend from environment ($($defines.Count) define(s))." -ForegroundColor Cyan
} else {
    Write-Host "No backend seeded - the app will open on the server-setup screen." -ForegroundColor Yellow
}

# Flavour tags every Sentry event, so keep it alongside the DSN.
$defines += "--dart-define=APP_FLAVOR=$appFlavor"
if ($sentryDsn) {
    $defines += "--dart-define=SENTRY_DSN=$sentryDsn"
    $defines += "--dart-define=SENTRY_TRACES_PERCENT=$tracesPct"
    Write-Host "Sentry ENABLED (environment=$appFlavor)." -ForegroundColor Cyan
} else {
    Write-Host "Sentry DISABLED (SENTRY_DSN is empty)." -ForegroundColor Yellow
}

# Required, not hygiene. `flutter_native_splash` is a dev_dependency, so its
# Android module is on the debug classpath but excluded from release builds.
# GeneratedPluginRegistrant.java left behind by a previous debug build still
# registers it, and the release compile then dies with the very unhelpful
#   "package net.jonhanson.flutter_native_splash does not exist".
# Cleaning forces the registrant to be regenerated for the release variant.
Write-Host "Cleaning (stale debug plugin registrant breaks release builds)..." -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host "Generating localizations..." -ForegroundColor Cyan
flutter gen-l10n

if ($Target -eq 'aab') {
    Write-Host "Building release App Bundle (--no-tree-shake-icons)..." -ForegroundColor Cyan
    flutter build appbundle --release --no-tree-shake-icons @defines
} else {
    Write-Host "Building release APK (--no-tree-shake-icons)..." -ForegroundColor Cyan
    flutter build apk --release --no-tree-shake-icons @defines
}

Write-Host "Done. NEVER build the release without --no-tree-shake-icons." -ForegroundColor Green
