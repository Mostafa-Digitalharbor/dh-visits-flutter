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
```

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

- Privacy policy URL (REQUIRED for apps requesting location). See
  `docs/PRIVACY_POLICY.md` — host on the company website and paste the URL
  into Play Console → App content → Privacy Policy.
- Data safety form — declare: precise location (collected + shared with the
  user's employer / manager), app activity (visit history). The location is
  collected **only while the user is using the app** (foreground); no
  background tracking, no analytics, no third-party sharing.
- The app does NOT request `ACCESS_BACKGROUND_LOCATION`, so no special
  background-location justification form is needed.

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

- Privacy policy URL.
- App Privacy questionnaire: declare precise location + linked to user.
- Encryption export compliance: `ITSAppUsesNonExemptEncryption=false` is set
  in `Info.plist` (uses only HTTPS / standard secure storage).
- Demo account credentials for review.

---

## 5. Per-release checklist

Run through this every time you cut a release:

- [ ] Bump `version` in `pubspec.yaml` (both name `1.0.x` and code `+N`).
- [ ] `flutter analyze` — must be clean.
- [ ] `flutter test` — must pass.
- [ ] Manual smoke test on a real Android device (login, check-in, background
      location, logout).
- [ ] Manual smoke test on a real iOS device — same flow.
- [ ] Verify `.env.production` is loaded (not the trial Odoo URL).
- [ ] Tag the commit: `git tag v1.0.x && git push --tags`.
- [ ] Upload AAB to Play Console internal track first → promote after QA.
- [ ] Upload IPA to TestFlight first → promote to App Store after review.

---

## 6. Known compliance items

| Item                                 | Status      | Notes |
| ------------------------------------ | ----------- | ----- |
| Privacy policy URL                   | **TODO**    | `docs/PRIVACY_POLICY.md` ready — host before submission. |
| App icon (1024×1024 PNG)             | Recommended | Regenerated from `assets/icon/visit-logo-master.png`. To replace: drop in a higher-res master, then run `pwsh tool/generate_icons.ps1` followed by `dart run flutter_launcher_icons`. |
| Crash reporting (Crashlytics/Sentry) | Not added   | Strongly recommended before first public release. |
| Cert pinning                         | Not added   | Optional hardening for v1.1. |
| Real foreground service for bg track | Not added   | V1 ships foreground-only by design. To add real background tracking later, integrate `flutter_foreground_task` and re-add `ACCESS_BACKGROUND_LOCATION` + `FOREGROUND_SERVICE_LOCATION` in `AndroidManifest.xml` and `UIBackgroundModes=location` in `Info.plist`. |

---

## 7. Versioning

- `versionName` (e.g. `1.2.3`) is what users see.
- `versionCode` (the `+N` after the name) must strictly increase for every Play
  Store upload, including re-uploads of the same `versionName`.
- iOS uses `CFBundleShortVersionString` (= name) and `CFBundleVersion` (= code).
