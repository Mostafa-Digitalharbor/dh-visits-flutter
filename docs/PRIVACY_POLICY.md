# Privacy Policy — Customer Visits

**Effective date:** 14 September 2026
**Last updated:** 14 September 2026

This Privacy Policy describes how **Digital Harbor** ("we", "us", "our") collects, uses, and protects information when you use the **Customer Visits** mobile application ("the App"). The App is a field‑workforce tool: employees of our customer organisations use it to plan and record customer site visits, to record their route during a work day, and to share their work location with their manager during working hours.

If you have any question about this policy, contact us at: **ai-tools@digital-harbor.net**

---

## 1. Who controls your data

The App is provided by Digital Harbor as a tool for our customer organisations (your employer). When you use the App as part of your job:

- **Your employer is the data controller** for the visit records, work-day routes and location data you generate. Your employer decides who in their organisation can see your location, routes and visit history.
- **Digital Harbor is a data processor** — we build, host and maintain the App and its backend on behalf of your employer. We process your data only on their instructions.

If you have questions about how *your employer* uses this data (retention, access, deletion), contact your employer's HR or IT department directly.

---

## 2. Information we collect

### 2.1 Account information
When your employer creates your account on the backend (Odoo) you provide:
- Your name, email or username, and an internal employee ID.
- Authentication credentials (password). The password is kept only in the device's secure storage (Android Keystore / iOS Keychain) so the App can renew your session, and is never written to logs or crash reports.

### 2.2 Location information
The App collects your device's location — latitude, longitude, accuracy, and, for route recording, altitude, speed, heading and the time of each position — in the following cases:

| When | Why | Stored where |
| ---- | --- | ------------ |
| When you start or end a customer visit | To prove you were at the customer site and record arrival/departure times | Visit record on your employer's backend |
| While a visit you started is in progress | To record the visit's route | Visit route on your employer's backend |
| About every 30 seconds **while the App is open on your screen** | To share your current position with your manager | Your "live location" record on your employer's backend (the previous value is overwritten) |
| **During an active work day** — from the moment you tap **Start work day** until you tap **End work day** or sign out, **including while the App is in the background, closed from the screen, or while your screen is locked** | To record your work-day route: the whole day, including the movement between visits, and the part of it that belongs to each visit | Work-day route on your employer's backend |

**Work-day route recording.** While your work day is active, the App records a position about every 5 seconds while you are moving (at least 5 metres apart, and nothing while you stand still). It keeps doing so when you switch to another app or lock your screen. On Android a notification ("Workday tracking active") is shown for as long as recording runs; on iOS the system shows its location indicator. Before the first work day, the App explains this on screen and asks for your agreement before any permission prompt.

**When the App does not collect location:**
- when no work day is active and the App is not open on your screen;
- after you tap **End work day** — recording stops immediately, and positions are no longer recorded;
- after you sign out;
- when you have not granted location permission, or have revoked it.

**Offline storage.** If there is no network, recorded positions are kept on your device, in the App's private storage, until they can be uploaded to your employer's backend. They are removed from the device once uploaded. Positions from a work day that belongs to a different account on the same device are deleted, not uploaded.

**Road matching (map display).** To draw your recorded routes along roads on the map, the App may send recorded positions (coordinates, their accuracy, heading, and time offsets relative to the first position — not the actual date and time) to a road-matching service. That service only returns a line to draw; your recorded positions are not changed. No name, employee ID, device ID, account credential or session is sent to it. In the production App this service is operated by Digital Harbor on infrastructure it controls (directly or through a hosting provider acting on its behalf), never by a public routing service; if none is configured, routes are drawn exactly as recorded and nothing is sent for road matching. The resulting map lines are cached on the device for up to 30 days and deleted when you sign out.

### 2.3 Visit content
You create visit records that include: the customer being visited, visit type, free‑text notes you choose to write, the outcome, and the visit state. You may optionally capture a photo with the camera or attach a file as proof of the visit; only what you choose at that moment is uploaded. This content is stored on your employer's backend.

### 2.4 Device & technical data
- The requests needed to call your employer's backend, over HTTPS only.
- A device-specific push notification token (Firebase Cloud Messaging), stored on your employer's backend against your account, so you can be notified about visit assignments and approvals.
- Crash reports and performance measurements sent to Sentry, configured to exclude personal information: they do not include your name, email, location or IP address.
- Generic device locale (so the App displays in Arabic or English).

The App does **not** collect: contact lists, microphone audio, your photo library, files outside what you choose to attach, the IMEI, advertising identifiers, or any analytics fingerprint.

---

## 3. How we use the information

We use the information described above strictly to provide the App's features:

1. **Authenticate you** against your employer's backend.
2. **Record visits** and prove you were physically at the customer's location.
3. **Record your work-day route** between Start work day and End work day, including travel between visits, for your employer's work-day and visit reports.
4. **Share your live location with your manager** while the App is open.
5. **Show maps** of customers, routes and positions, with routes drawn along roads where road matching is available.
6. **Keep working offline** — actions and recorded positions are stored on the device and sent automatically when connectivity returns.

We do **not** use your data for advertising, profiling, behavioural analytics, or sale to third parties.

---

## 4. Background location during an active work day

The App uses your location in the background **only while a work day you started is active**.

- **Android:** recording runs in a foreground service of type "location", started when you tap Start work day, with a notification visible for as long as it runs. The App requests location access "while using the app" and does **not** request the Android `ACCESS_BACKGROUND_LOCATION` permission.
- **iOS:** the App declares the iOS "location" background mode. With "While Using the App" access, recording continues in the background once you started the work day in the App. The App may also ask you to allow access "Always"; this is optional and only lets recording resume if iOS closes the App during your work day. No route is recorded outside an active work day.
- **Stopping:** tap **End work day**, or sign out. You can also revoke location access at any time from Settings → Apps → Customer Visits → Permissions (Android) or Settings → Privacy & Security → Location Services → Visits (iOS). Visit check-in/out, live sharing and work-day recording then stop working until access is granted again.

---

## 5. Permissions the App requests

| Permission | Reason |
| ---------- | ------ |
| Precise and approximate location (while using the app) | Visit start/end coordinates, visit routes, live sharing while the App is open, and the work-day route |
| Android: foreground service (location) | Keep recording the work-day route while the App is in the background or the screen is locked, with a visible notification |
| iOS: location background mode; optional "Always" access | Keep recording the work-day route in the background; "Always" lets recording resume if iOS closes the App during a work day |
| iOS: temporary precise location | Asked only if you turned Precise Location off, because a route cannot be recorded accurately without it |
| Notifications | Visit workflow notifications; on Android also the visible work-day recording notification |
| Camera (and, on iOS, the photo library prompt text) | Optional proof-of-visit photos |
| Internet / network state | Talk to the backend; detect offline state to queue actions |

The App does **not** request: the Android background location permission (`ACCESS_BACKGROUND_LOCATION`), microphone, contacts, calendar, SMS or phone.

---

## 6. Data sharing

We share your data only with the following parties:

- **Your employer**, who is the controller of the data. Anyone in your employer's organisation whom your employer grants manager rights can see the live location, work-day routes and visit history of the employees they manage.
- **Our hosting providers**, strictly to operate the backend and, where configured, the road-matching service. No marketing or other processing.
- **Sentry** (crash and performance reports without personal information) and **Firebase Cloud Messaging** (delivery of push notifications).
- **Authorities**, only if we are legally compelled by a valid court order.

We do **not** sell or share your data with advertisers, analytics platforms, or data brokers.

---

## 7. Data retention

- **Session and credentials** stored on the device: deleted on sign-out.
- **Positions waiting to upload** on the device: removed once uploaded; the device keeps at most about 8,000 waiting work-day positions and discards the oldest beyond that.
- **Road-matched map lines** cached on the device: up to 30 days, deleted on sign-out.
- **Live location** on the backend: only your most recent position is kept.
- **Visit records, visit routes and work-day routes** on the backend: retained according to your employer's retention schedule. Work-day positions cannot be edited or deleted from the App. Contact your employer to request deletion.

---

## 8. Security

- All traffic between the App and the backend and road-matching service is over HTTPS (TLS). Cleartext HTTP is blocked on both Android (`usesCleartextTraffic=false`) and iOS (App Transport Security).
- Credentials are stored in the device's secure storage (Android Keystore / iOS Keychain).
- Positions waiting to upload are stored in the App's private storage (on iOS, protected until the device is first unlocked after a restart), and the App is excluded from Android cloud backups.
- On the backend, employees can only add positions to their own active work day, managers can only see the employees they manage, and recorded positions cannot be changed.

No system is 100% secure. If you suspect your account is compromised, change your password from your employer's portal immediately.

---

## 9. Children

The App is a workplace tool intended for adult employees of our customer organisations. It is **not** directed at children under 16, and we do not knowingly collect data from anyone under 16.

---

## 10. Your rights

Because your employer is the controller of the data:

- To request **access, correction, or deletion** of your visit history, work-day routes or live-location record, contact your employer's HR or IT.
- For complaints about how Digital Harbor (the processor) handles your data, contact us at **ai-tools@digital-harbor.net**.
- Depending on your country, you may also have the right to lodge a complaint with your local data protection authority.

---

## 11. Changes to this policy

We may update this policy when we add features, change subprocessors, or comply with new regulations. We will publish the updated policy at the same URL where you found this document and update the "Last updated" date at the top. Material changes will additionally be communicated via the App on next launch.

---

## 12. Contact

**Digital Harbor**
Email: **ai-tools@digital-harbor.net**
Website: **https://digitalharbor.com.sa**

