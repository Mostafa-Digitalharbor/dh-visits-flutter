# CI/CD

Two workflows, one rule: **`ci.yml` is free, `release.yml` costs a store slot.**

| | `ci.yml` | `release.yml` |
|---|---|---|
| Fires on | every push to any branch | a `v*` tag only |
| Builds | debug APK | signed AAB + signed IPA |
| Uploads to | nothing — a GitHub artifact | Play *internal* track, TestFlight *internal* testers |
| Safe to re-run | yes, endlessly | every run consumes a build number on a real store account |

`release.yml` deliberately does **not** run on push. Store review takes hours to
days; a pipeline that uploads on every commit builds a queue that never drains.

---

## Shipping a release

```bash
# 1. bump the human-facing version (the +N build part is ignored by CI)
#    pubspec.yaml -> version: 1.0.3+6

# 2. tag it
git tag v1.0.3
git push origin v1.0.3
```

The tag is the version. `--build-name` comes from the tag with the `v` stripped,
and `--build-number` is `BUILD_NUMBER_OFFSET + github.run_number`, which is
monotonic by construction — no step reads the last versionCode back from Play,
so nothing can race or go stale.

`BUILD_NUMBER_OFFSET` is `100` because pubspec.yaml had reached `+6` before this
pipeline existed. Raise it if the workflow is ever reset; **never lower it** —
Play permanently rejects a versionCode it has already seen.

### Rehearsing without shipping

**Run workflow** on the Actions tab takes a version and a `dry_run` checkbox
that defaults to **on**. With it on, both platforms build, sign and export in
full — the whole credential path is exercised — and the two upload steps are
skipped, so no Play versionCode and no TestFlight build number are consumed.
The signed AAB and IPA are attached to the run as artifacts.

A tag ignores the checkbox and always uploads. There is exactly one way to reach
a store, and it is deliberate.

Use the dry run for the first run after any credential change, not as a habit: a
lane that is usually run in pretend mode is a lane nobody checks the output of.

---

## What happens when a platform's keys are missing

The `version` job probes for each platform's secrets and publishes
`has_android` / `has_ios` as job outputs. The platform jobs gate on those and
**skip** — they do not fail. Setting up one store therefore never blocks
shipping to the other.

This has to go through a job output because the `secrets` context is not
available in `jobs.<id>.if`; GitHub evaluates it to empty there and the job
silently never runs. `tool/validate_workflows.dart` fails the build if anyone
reintroduces `if: secrets.*`.

---

## Validating a workflow change without pushing

```bash
dart run tool/validate_workflows.dart
```

Parses every workflow and asserts the invariants above: valid YAML, every job
has `runs-on`, every step has `uses` or `run`, no `if:` reads `secrets.*`, and
no `run:` block has swallowed the step below it through bad indentation.

---

## Consoles

| | |
|---|---|
| GitHub Actions | <https://github.com/Mostafa-Digitalharbor/dh-visits-flutter/actions> |
| Secrets | <https://github.com/Mostafa-Digitalharbor/dh-visits-flutter/settings/secrets/actions> |
| Variables | <https://github.com/Mostafa-Digitalharbor/dh-visits-flutter/settings/variables/actions> |
| Play — app dashboard | <https://play.google.com/console/u/2/developers/7574373484861523453/app/4973467961658297850/app-dashboard> |
| Play — internal track | <https://play.google.com/console/u/2/developers/7574373484861523453/app/4973467961658297850/tracks/internal-testing> |
| Play — app signing | <https://play.google.com/console/u/2/developers/7574373484861523453/app/4973467961658297850/app-signing> |
| Play — bundle explorer (used versionCodes) | <https://play.google.com/console/u/2/developers/7574373484861523453/app/4973467961658297850/bundle-explorer> |
| Play — users & permissions | <https://play.google.com/console/u/2/developers/7574373484861523453/users-and-permissions> |
| App Store Connect — API keys | <https://appstoreconnect.apple.com/access/integrations/api> |

### Signing identities

The upload key in `ANDROID_KEYSTORE_BASE64` must be the certificate Play has
registered as this app's **upload key**, otherwise Play rejects the AAB after
the upload with a certificate-mismatch message. Current fingerprints of
`upload-keystore.jks` / alias `upload`
(`CN=Digital Harbor, OU=Mobile Development, O=Digital Harbor, L=Riyadh, C=sa`,
valid to 2053):

```
SHA-1   CD:F1:F6:7F:DB:CF:53:56:B9:29:3A:DB:02:EF:4A:E9:13:0C:40:E5
SHA-256 D0:85:57:BA:3C:C8:B8:B3:3B:4C:E1:4A:89:94:DA:D2:66:FB:1F:42:4B:82:FA:9E:C3:D9:11:61:17:F0:D6:74
```

Re-read them with:

```bash
keytool -list -v -keystore "C:/Users/Ninja zone/.android-keys/upload-keystore.jks" -alias upload
```

The Apple side uses `Apple Distribution: COMPANY DIGITAL HARBOR (P95FNYY2S2)`,
which expires **17 Aug 2027** — a hard deadline for the iOS lane.

The Play service account is `saqqar-ci@saqqar-app1.iam.gserviceaccount.com`. It
lives in a different Cloud project (`saqqar-app1`), which is fine: Play grants
access to the service account's *email* at the developer-account level, not per
Cloud project.

## Secrets

Set at
<https://github.com/Mostafa-Digitalharbor/dh-visits-flutter/settings/secrets/actions>.

| Secret | Used by | Notes |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | android | base64 of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | android | `storePassword` |
| `ANDROID_KEY_PASSWORD` | android | optional; falls back to `ANDROID_KEYSTORE_PASSWORD` |
| `ANDROID_KEY_ALIAS` | android | `keyAlias` |
| `PLAY_SERVICE_ACCOUNT_JSON` | android | full JSON of the Play service account |
| `IOS_DIST_CERT_P12_BASE64` | ios | base64 of the Apple Distribution `.p12` |
| `IOS_DIST_CERT_PASSWORD` | ios | export password of that `.p12` |
| `ASC_KEY_ID` | ios | App Store Connect API key id |
| `ASC_ISSUER_ID` | ios | App Store Connect issuer id |
| `ASC_KEY_P8_BASE64` | ios | base64 of `AuthKey_<id>.p8` — **must be an Admin key** |
| `API_BASE_URL` | both | optional; omit and the app opens on the setup screen |
| `ODOO_DATABASE` | both | optional, same |
| `SENTRY_DSN` | both | **not needed** — see below. Set it only to point a build at a *different* Sentry project |

`SENTRY_TRACES_PERCENT` is a repository **variable**, not a secret.

The App Store Connect key must have the **Admin** role. App Manager is enough to
*upload* a build but not to cloud-sign one, and the failure surfaces during
`exportArchive` as `Cloud signing permission error / No profiles were found` —
which reads like a provisioning problem rather than a permissions one.

---

## Traps this pipeline is built around

Each of these cost a real CI round-trip somewhere. The workflow files carry the
same notes inline; this is the index.

1. **Gradle memory.** `android/gradle.properties` asks for `-Xmx8G` — correct on
   a dev box, fatal on a 2 vCPU / 7 GB runner. The JVM gets OOM-killed, Gradle
   exits 143, and GitHub prints *"The operation was canceled"*, which looks like
   somebody pressed cancel. CI writes its own `gradle.properties` into
   `GRADLE_USER_HOME` (which overrides the project's) capping the heap at 3 GB,
   so local builds stay fast.

2. **Jetifier.** `android.enableJetifier=true` was removed. It rewrites every
   dependency archive to swap `com.android.support.*` for `androidx.*`, holding
   each in memory — and this project has **zero** legacy support dependencies,
   so it was rewriting hundreds of jars to change nothing. Under a 3 GB cap the
   debug build dies with `JetifyTransform ... Java heap space`. Before ever
   putting it back, run and get a non-zero:
   ```bash
   find ~/.gradle/caches/modules-2/files-2.1 -maxdepth 1 \
        \( -iname "com.android.support*" -o -iname "android.arch*" \) | wc -l
   ```

3. **Disk.** A release AAB needs more than the ~14 GB left once Gradle unpacks
   the NDK and CMake. Running out surfaces as
   `Could not add entry '.../transforms/...' to cache file-access.bin`, which
   reads like a corrupted cache. The android job deletes dotnet, ghc, ghcup and
   CodeQL first and prints `df -h` either side.

4. **Firebase config.** `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist` are **committed** in this repo, so
   unlike most Flutter projects there is no secret to restore. If they are ever
   removed from git, every Android build — including debug — breaks.

5. **Xcode version.** `macos-15`, and the newest installed Xcode picked with
   `sort -V`. Not a glob: a pattern like `Xcode_1[6-9]*` looks right and matches
   nothing today, because Apple went from 16.x straight to 26.x.

6. **`xcodebuild -version | head`.** Under Xcode 26 that dies on `EPIPE`
   (exit 134) *after* printing the correct version, and `pipefail` turns it into
   a failed step that looks like a bad Xcode selection. Capture the whole output
   into a variable and inspect it in memory.

7. **CocoaPods must live in fastlane's Ruby.** `ruby/setup-ruby` installs a Ruby
   that is *not* the one the runner image put CocoaPods in, and
   `flutter build ios` shells out to `pod` directly rather than through bundler
   — so it warns *"CocoaPods is installed but broken"* and then fails ~20
   minutes later. `ios/Gemfile` declares `gem "cocoapods"`, and a
   `which pod && pod --version` step fails in seconds if that ever stops
   working.

8. **No `bundler-cache: true`.** It needs a `Gemfile.lock` (not committed —
   generating one on Windows pins the wrong platforms) and it sets
   `BUNDLE_PATH=vendor/bundle`, which moves the `pod` binstub off `PATH` and
   recreates trap 7.

9. **An empty `--dart-define` is not the same as omitting it.**
   `String.fromEnvironment` falls back to its `defaultValue` only when the key
   is **absent**; an empty string is a value and wins. So passing an unset
   secret through blindly blanks `APP_FLAVOR` and — much worse — blanks
   `SENTRY_DSN`, silently shipping a store release with crash reporting off.
   Both build steps add a flag only when it has content.

   The same trap in shell form: these are written as `if`/`else`, not
   `[ -n "$X" ] && flags=...`, because under `set -e` a false test on the *last*
   line of a script exits 1 and fails the step.

10. **iOS signing.** `-allowProvisioningUpdates` plus the App Store Connect key
    lets Apple mint the App Store profile on a runner that has never seen this
    app, so no `.mobileprovision` lives in the repo. `DEVELOPMENT_TEAM` is
    passed on the `xcodebuild` command line because the checked-in project sets
    none at all.

11. **`MinimumOSVersion`.** An archive with an empty one builds, exports and
    uploads perfectly, and Apple rejects it minutes later during processing with
    `MinimumOSVersion in 'Runner.app/Frameworks/App.framework' is ''`. A guard
    step reads it out of the archive before export. It must stay in lockstep
    with `IPHONEOS_DEPLOYMENT_TARGET` and `platform :ios` in `ios/Podfile` —
    all three are `15.0` -- raised from 13.0 because firebase_core and
    firebase_messaging declare `s.ios.deployment_target = 15.0`, and CocoaPods
    refuses the whole resolution rather than warning.

12. **Play debug symbols path.** Under AGP 8.x the task name is part of the
    path: `merged_native_libs/release/mergeReleaseNativeLibs/out/lib`. The
    `.../release/out/lib` layout every blog post still shows does not exist.

13. **`--no-tree-shake-icons` everywhere.** The app draws its icons from
    `material_symbols_icons`, which ships *variable* fonts, and the release icon
    tree-shaker drops glyphs from those — producing a store build with whole
    rows of blank icons. See [ICONS_TREE_SHAKING.md](ICONS_TREE_SHAKING.md).

14. **`jarsigner -verify` cannot read an AAB.** It is a JAR utility that predates
    the APK Signature Schemes, so on a perfectly valid bundle it reports every
    entry as `signed in JarFile but is not signed in JarInputStream` and exits
    non-zero — hundreds of lines that look like a broken signature and fail the
    release on a good build. Compare certificates instead: the SHA-256 from
    `keytool -printcert -jarfile <aab>` against the one from
    `keytool -list -v -keystore`. Verified against a real signed AAB; both
    report `D0:85:57:BA:…`.

15. **Firebase sets the iOS floor.** `firebase_core` and `firebase_messaging`
    declare `s.ios.deployment_target = '15.0'`; every other plugin here asks for
    13.0 or lower. CocoaPods does not warn and degrade — it refuses the entire
    resolution with *"could not find compatible versions for pod firebase_core
    … they required a higher minimum deployment target"*, which never names the
    version it wanted. Re-derive after any plugin bump:
    ```bash
    grep -r "ios.deployment_target" ~/.pub-cache/hosted/pub.dev/*/ios/*.podspec
    ```

16. **A masked secret hides its own shape.** `ASC_KEY_ID` holding the base64 of
    the `.p8` (the thing on the clipboard right after
    `base64 -w0 AuthKey_XXXX.p8 | clip`) produced `File name too long` from a
    step that was only naming a file — eight minutes into a macOS job, with the
    value printed as `***`. The `version` job now checks the *shape* of the iOS
    secrets on ubuntu in seconds. Missing secret = platform skips; malformed
    secret = loud failure.

17. **Pinned Flutter, not `stable`.** The iOS side here is the classic
    `UIApplicationDelegate` embedding — no `SceneDelegate.swift`, no
    `UIApplicationSceneManifest`, no `FlutterImplicitEngineDelegate` — and
    `pubspec.lock` was resolved against 3.35.3. Floating on `stable` lets a
    Flutter release turn a store build red without a single commit of ours.

---

## Sentry

Wired in [lib/main.dart](../lib/main.dart), configured in
[AppEnvironment](../lib/core/config/app_environment.dart).

**The DSN is in the source, not in a secret.** A Sentry DSN is a write-only
client ingest key — it is designed to ship inside the app binary, and anyone
with the APK can read it out — so treating it as a secret buys nothing and costs
the thing that actually matters: a store build whose crash reporting was
silently off because a CI secret was never set. `--dart-define=SENTRY_DSN=` with
an *empty* value beats a `defaultValue`, so a half-configured pipeline produced
exactly that.

Resolution order in `AppEnvironment.sentryDsn`:

1. `--dart-define=SENTRY_DSN=...` — point a build at a different project.
2. otherwise a **release** build always reports to `_releaseDsn`.
3. otherwise (debug / profile) Sentry is off, so local runs don't spend the free
   quota on errors a developer is already staring at.

[test/observability_wiring_test.dart](../test/observability_wiring_test.dart)
locks this down, along with the whole noise filter — every failure mode here is
invisible at runtime, so a test is the only thing that notices.

- `release` is `<package>@<version>+<build>` read from `PackageInfo`, so a tag
  becomes a Sentry release with no second number to bump.
- `environment` is derived in `AppEnvironment.sentryEnvironment` rather than
  taken straight from `APP_FLAVOR`, so a release binary is never tagged `dev`
  and an empty `APP_FLAVOR` cannot produce an empty environment.
- `sendDefaultPii`, `attachScreenshot` and `attachViewHierarchy` are all off. A
  screenshot of this app is a customer's name, address and the rep's live
  position.
- `beforeSend` drops environmental noise via `isSentryNoise` — offline, 4xx,
  expired session, TLS failures. The same predicate runs in `SentryBlocObserver`
  so the two paths cannot drift.
