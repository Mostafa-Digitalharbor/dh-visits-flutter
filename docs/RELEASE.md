# Release Guide — Customer Visits

Step-by-step instructions for building and shipping the app to Google Play
and Apple App Store. Read end-to-end the first time.

---

## 1. One-time setup

### 1.1 Bundle / package IDs (already configured)

| Platform | Identifier               |
| -------- | ------------------------ |
| Android  | `net.digitalharbor.visits` |
| iOS      | `net.digitalharbor.visits` |

If you need a different ID, change it in **both** places:

- Android: `android/app/build.gradle.kts` → `namespace` + `applicationId`,
  and the path of `android/app/src/main/kotlin/net/digitalharbor/visits/MainActivity.kt`
  (rename the package directory **and** the `package` line inside the file).
- iOS: `ios/Runner.xcodeproj/project.pbxproj` → every `PRODUCT_BUNDLE_IDENTIFIER`
  occurrence (Debug, Release, Profile, plus the RunnerTests variants).

### 1.2 Android signing key (one-time, keep secret)

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Back up the `.jks` file in a password manager / secure vault. **If you lose
  it, you cannot publish updates to the same app** — Play Store will reject
  re-signed APKs.
- Copy `android/key.properties.template` → `android/key.properties` and fill in
  the four values. This file is git-ignored.

### 1.3 Apple developer account

- Enroll at <https://developer.apple.com/programs/> (US$99/yr).
- In App Store Connect, create the app record with bundle ID `net.digitalharbor.visits`.
- Generate a signing certificate + provisioning profile via Xcode → Signing & Capabilities.

### 1.4 Google Play console

- Pay the one-time US$25 developer registration.
- Create the app entry; the package name `net.digitalharbor.visits` will be locked in
  permanently after the first upload — there is **no way** to change it later.

---

## 2. Build environments

Build-time config is injected with `--dart-define`. We define three flavours:

| Flavour     | API base URL                          | Database                                    |
| ----------- | ------------------------------------- | ------------------------------------------- |
| dev         | trial Odoo (default)                  | trial DB (default — expires 2026-06-07)     |
| staging     | `https://odoo-staging.digitalharbor…` | your staging DB                             |
| production  | `https://odoo.digitalharbor…`         | your production DB                          |

Create `.env.production` (git-ignored) from `.env.example`:

```
API_BASE_URL=https://odoo.digitalharbor.net
ODOO_DATABASE=visits_production
APP_FLAVOR=production
SENTRY_DSN=https://<key>@o<org>.ingest.sentry.io/<project>
SENTRY_TRACES_PERCENT=10
MAP_MATCHING_URL=https://osrm.digitalharbor.net   # company OSRM; empty = raw GPS only
MAP_MATCHING_MAX_POINTS=90
```

A release build ignores `MAP_MATCHING_URL` when it points at a public demo
server (`router.project-osrm.org`), and `release.yml` fails on it.

Leave `SENTRY_DSN` empty in `.env.dev` so local hot-reload exceptions
don't burn your Sentry quota.

Then build with:

```bash
flutter build appbundle --release \
  --dart-define-from-file=.env.production \
  --obfuscate --split-debug-info=build/symbols
```

---

## 3. Android release build

```bash
# Clean
flutter clean && flutter pub get

# Regenerate launcher icons (only if logo changed)
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# Build the AAB (Play Store format)
flutter build appbundle --release \
  --dart-define-from-file=.env.production \
  --obfuscate --split-debug-info=build/symbols/android
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Upload via Play Console → Release → Production → Create new release.

Keep `build/symbols/android/` — upload to Play Console for crash de-obfuscation.

### Play Console required metadata

Full answers: [store/play/location-and-foreground-service-declarations.md](../store/play/location-and-foreground-service-declarations.md).

- Privacy policy URL (REQUIRED for apps requesting location). See
  `docs/PRIVACY_POLICY.md` (paste-ready `docs/PRIVACY_POLICY.html`) — host on
  the company website and paste the URL into Play Console → App content →
  Privacy Policy. The hosted page must include the section "Background
  location during an active visit".
- **Foreground service permissions** (App content): the app declares
  `FOREGROUND_SERVICE_LOCATION` for `VisitLocationService`. Justification:
  records the GPS trail of a customer visit the employee started, while the
  visit is in progress; stops when the visit ends. Provide a demo video of
  Start Visit → background / locked screen → End Visit with the "Visit
  tracking active" notification visible, then gone.
- Data safety form — precise and approximate location collected (not shared,
  required, app functionality), plus the other types in the declarations file.
  Location is collected only for customer visits; in the background **only
  during an active visit**, through the foreground service, with the
  while-in-use permission.
- The app does NOT request `ACCESS_BACKGROUND_LOCATION` (the service is always
  started from the foreground), so the separate background-location
  declaration is not needed. The in-app prominent disclosure is shown before
  the first Start Visit.

---

## 4. iOS release build

```bash
# Pod install (first time + after dependency changes)
cd ios && pod install --repo-update && cd ..

# Build the IPA
flutter build ipa --release \
  --dart-define-from-file=.env.production \
  --obfuscate --split-debug-info=build/symbols/ios
```

Output: `build/ios/ipa/*.ipa`

Upload via `xcrun altool` or open in Transporter app.

### App Store Connect required metadata

- Privacy policy URL (with the "Background location during an active visit"
  section).
- App Privacy questionnaire: declare precise location + linked to user, not
  used for tracking ([store/appstore/app-privacy.md](../store/appstore/app-privacy.md)).
- **Background location:** `UIBackgroundModes` contains `location`, used only
  for the trail of a visit in progress; `Info.plist` has
  `NSLocationWhenInUseUsageDescription`,
  `NSLocationAlwaysAndWhenInUseUsageDescription` (required by Apple's static
  check because `geolocator_apple` links the Always API, and lets a user
  choose "Always" in Settings — the app never requests it) and
  `NSLocationTemporaryUsageDescriptionDictionary` (key `VisitRoute`; localized in en/ar
  `InfoPlist.strings`); all purpose strings must describe visit-only use. App Review Notes must explain that background
  location runs only while a visit is in progress and how to see it — text in
  [store/appstore/apple-review-2026-08-06.md § 4-ب](../store/appstore/apple-review-2026-08-06.md).
- Encryption export compliance: `ITSAppUsesNonExemptEncryption=false` is set
  in `Info.plist` (uses only HTTPS / standard secure storage).
- Demo account credentials for review — typed into App Store Connect's
  Sign-In Information only, never committed. The account needs visits in the
  Approved state so the reviewer can start one.

---

## 5. Per-release checklist

Run through this every time you cut a release:

- [ ] Bump `version` in `pubspec.yaml` (both name `1.0.x` and code `+N`).
- [ ] `flutter analyze` — must be clean.
- [ ] `flutter test` — must pass.
- [ ] Manual smoke test on a real Android device: login, Start Visit on an
      approved visit (disclosure → permission → notification appears only
      after the server confirms), movement with the app in the background and
      the screen locked, visit trail (road-matched and raw), End Visit
      (notification gone, nothing recorded afterwards), no location activity
      between visits, logout during a visit stops capture.
- [ ] Manual smoke test on a real iPhone — same flow (blue location indicator
      instead of the notification; no "Always" prompt), plus: permission
      changed to "Never" while a visit is in progress (no crash).
- [ ] Offline: Start Visit offline → no tracking until the queued Start is
      accepted; points recorded offline upload later with their original times.
      Checklist: [VISIT_TRACKING.md § 11](VISIT_TRACKING.md).
- [ ] Verify `.env.production` is loaded (not the trial Odoo URL).
- [ ] `MAP_MATCHING_URL` points at the company OSRM server (never
      `router.project-osrm.org`), or is deliberately empty (optional — visit
      trails are then drawn as recorded); see
      [MAP_MATCHING_DEPLOYMENT.md](MAP_MATCHING_DEPLOYMENT.md).
- [ ] The build never calls `/api/workday/*` (the work-day feature was
      cancelled on 2026-09-16; `dh_workday_tracking` must not be installed).
- [ ] Tag the commit: `git tag v1.0.x && git push --tags`.
- [ ] Upload AAB to Play Console internal track first → promote after QA.
- [ ] Upload IPA to TestFlight first → promote to App Store after review.

---

## 6. Known compliance items

| Item                                 | Status      | Notes |
| ------------------------------------ | ----------- | ----- |
| Privacy policy URL                   | **TODO (manual)** | `https://digitalharbor.com.sa/ar/visit-app` exists but still carries the old text ("No background tracking", checked 2026-09-14). Replace it with `docs/PRIVACY_POLICY.md` / `.html` (last updated 16 September 2026) before submitting a build with background visit tracking. |
| iOS privacy manifest                 | Added       | `ios/Runner/PrivacyInfo.xcprivacy` in the Runner Resources phase: `UserDefaults` (`CA92.1`) + the collected data types of store/appstore/app-privacy.md. Not yet verified in an Xcode archive (no Mac). |
| App icon (1024×1024 PNG)             | Recommended | Regenerated from `assets/icon/visit-logo-master.png`. To replace: drop in a higher-res master, then run `pwsh tool/generate_icons.ps1` followed by `dart run flutter_launcher_icons`. |
| Crash reporting (Sentry)             | Added       | `sentry_flutter`, `sendDefaultPii = false`; DSN in `AppEnvironment`. |
| Cert pinning                         | Not added   | Optional hardening for v1.1. |
| Background visit tracking            | Implemented | Only while a visit is in progress. Android: `VisitLocationService` (foreground service type `location`, `FOREGROUND_SERVICE_LOCATION`, no `ACCESS_BACKGROUND_LOCATION`). iOS: `VisitLocation.swift`, `UIBackgroundModes=location`. Needs the Play foreground-service declaration + demo video and the App Review notes. See docs/VISIT_TRACKING.md. |
| Work-day tracking                    | **Cancelled 2026-09-16** | Removed from the app, with live location sharing, the nearby-employees radar and the hr.attendance mirror. Do not install `dh_workday_tracking`; see docs/WORKDAY_TRACKING.md (obsolete notice). |
| Production map-matching server       | Optional    | Company-controlled OSRM not deployed yet; release builds draw visit trails as recorded until `MAP_MATCHING_URL` is set. docs/MAP_MATCHING_DEPLOYMENT.md. |

---

## 7. Versioning

- `versionName` (e.g. `1.2.3`) is what users see.
- `versionCode` (the `+N` after the name) must strictly increase for every Play
  Store upload, including re-uploads of the same `versionName`.
- iOS uses `CFBundleShortVersionString` (= name) and `CFBundleVersion` (= code).
