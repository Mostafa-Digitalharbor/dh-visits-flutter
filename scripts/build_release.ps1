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
#   A RELEASE build always reports, using the project DSN baked into
#   AppEnvironment._releaseDsn. This script no longer carries its own copy -
#   two copies drift, and the one that drifts is always the one that mattered.
#   Point a build at a different Sentry project with:
#     $env:SENTRY_DSN = 'https://...'
#   There is deliberately no "disable Sentry" switch for a release build: a
#   store binary with no crash reporting is a silent regression nobody notices
#   until they need a stack trace and there isn't one.
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

# Left empty unless the caller overrides it: AppEnvironment owns the default.
# Note the emptiness test - passing `--dart-define=SENTRY_DSN=` with an EMPTY
# value would NOT fall back to the code's default, it would WIN over it, because
# String.fromEnvironment only uses its defaultValue when the key is absent.
$sentryDsn = $env:SENTRY_DSN
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

# Road matching for route display: the company-controlled OSRM server
# (docs/MAP_MATCHING_DEPLOYMENT.md). Unset = routes drawn as recorded GPS.
# A release build never uses a public demo router, so refuse one here.
#   $env:MAP_MATCHING_URL = 'https://osrm.yourcompany.com'
if ($env:MAP_MATCHING_URL -match 'project-osrm\.org|routing\.openstreetmap\.de') {
    throw 'MAP_MATCHING_URL points at a public OSRM demo server; use the company server.'
}
if ($env:MAP_MATCHING_URL) {
    $defines += "--dart-define=MAP_MATCHING_URL=$($env:MAP_MATCHING_URL)"
    Write-Host "Road matching -> $($env:MAP_MATCHING_URL)" -ForegroundColor Cyan
} else {
    Write-Host "Road matching -> off (no MAP_MATCHING_URL); routes show recorded GPS." -ForegroundColor Yellow
}
if ($env:MAP_MATCHING_MAX_POINTS) { $defines += "--dart-define=MAP_MATCHING_MAX_POINTS=$($env:MAP_MATCHING_MAX_POINTS)" }

# Flavour tags every Sentry event, so keep it alongside the DSN.
$defines += "--dart-define=APP_FLAVOR=$appFlavor"
$defines += "--dart-define=SENTRY_TRACES_PERCENT=$tracesPct"
if ($sentryDsn) {
    $defines += "--dart-define=SENTRY_DSN=$sentryDsn"
    Write-Host "Sentry -> overridden project (environment=$appFlavor)." -ForegroundColor Cyan
} else {
    Write-Host "Sentry -> project default from AppEnvironment (environment=$appFlavor)." -ForegroundColor Cyan
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
