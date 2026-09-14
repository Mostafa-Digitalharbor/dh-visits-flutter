# App Store Connect — App Privacy answers

Derived from what the code actually does, not from guesses. Re-check this file
whenever a new SDK is added or a new permission is requested.

## Data Collection

**Yes, we collect data from this app.**

The app sends location, identity, and visit content to the employer's Odoo server,
and crash/performance events to Sentry. All of that is "collect" under Apple's
definition.

---

## Tracking

**No** — for every data type below, answer **"No, we do not use this data for tracking."**

Nothing here is shared with data brokers or joined with third-party data for
advertising. There are no ad SDKs. This means no ATT prompt is required.

---

## Data types to select

| Data type | Purpose | Linked to identity | Tracking | Why |
|---|---|---|---|---|
| **Precise Location** | App Functionality | **Yes** | No | GPS captured at check-in/out, visit routes, and the work-day route (also in the background between Start and End work day), tied to the employee record |
| **Coarse Location** | App Functionality | **Yes** | No | `ACCESS_COARSE_LOCATION` is requested alongside fine |
| **Name** | App Functionality | **Yes** | No | Employee name shown in profile and manager views |
| **Email Address** | App Functionality | **Yes** | No | Sign-in identifier |
| **User ID** | App Functionality | **Yes** | No | Odoo user / employee ID on every request |
| **Device ID** | App Functionality | **Yes** | No | FCM push token, stored server-side against the user |
| **Photos or Videos** | App Functionality | **Yes** | No | Proof-of-visit photos ([visit_action_bar.dart:112](../../lib/features/visits/view/visit_action_bar.dart#L112)) |
| **Other User Content** | App Functionality | **Yes** | No | Visit notes and file attachments |
| **Crash Data** | App Functionality | **No** | No | Sentry, `sendDefaultPii = false`, no `setUser` call |
| **Performance Data** | App Functionality | **No** | No | Sentry tracing ([main.dart:29](../../lib/main.dart#L29)) |

### Do NOT select

- **Phone Number / Physical Address** — the app *displays* customer phone numbers and
  addresses, but those come down from the employer's server. They are not collected
  from the user or the device.
- **Contacts** — the device address book is never read.
- **Advertising Data, Purchases, Browsing History, Search History** — none apply.
- **Product Interaction** — there is no analytics SDK. The in-app Analytics tab is
  computed server-side from visit records already covered above.

---

## Privacy Policy URL

The field on this page is empty and it is **required** — the Publish button stays
disabled without it. It must be a public, reachable URL (not a Google Doc, not a
login-gated page), and it must actually describe the location collection above.

Use `https://digitalharbor.com.sa/ar/visit-app` — **after** replacing its content with
docs/PRIVACY_POLICY.md. As checked on 2026-09-14 the page still says "No background
tracking", which contradicts the work-day build (see privacy-policy-fixes.md § 0).

---

## Privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy` (Runner target, Resources phase):

- `NSPrivacyTracking = false`, no tracking domains.
- Required-reason API used by the app's own code: `UserDefaults`, reason `CA92.1`
  (`WorkdayLocation.swift` stores the open work day's capture state in the app's own
  defaults). No other required-reason API (file timestamps, boot time, disk space,
  active keyboards) is called from `ios/Runner`.
- `NSPrivacyCollectedDataTypes` = the table above, same linked/tracking/purpose values.

Plugins declare their own usage: geolocator_apple, permission_handler_apple,
shared_preferences_foundation, path_provider_foundation, flutter_secure_storage,
url_launcher_ios, image_picker_ios, package_info_plus, file_picker,
firebase_messaging and flutter_local_notifications ship a `PrivacyInfo.xcprivacy`;
Firebase and Sentry declare theirs in the native pods (`Firebase/CoreOnly`,
`Sentry/HybridSDK` 8.46.0). `open_filex` ships none and calls no required-reason API.
Re-check this list when a plugin is added.
