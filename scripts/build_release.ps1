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
