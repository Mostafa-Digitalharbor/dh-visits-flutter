# Privacy Policy — Customer Visits

**Effective date:** 14 September 2026
**Last updated:** 16 September 2026

This Privacy Policy describes how **Digital Harbor** ("we", "us", "our") collects, uses, and protects information when you use the **Customer Visits** mobile application ("the App"). The App is a field‑workforce tool: employees of our customer organisations use it to plan and record customer site visits, including where each visit started and ended and the route taken while the visit was in progress.

If you have any question about this policy, contact us at: **ai-tools@digital-harbor.net**

---

## 1. Who controls your data

The App is provided by Digital Harbor as a tool for our customer organisations (your employer). When you use the App as part of your job:

- **Your employer is the data controller** for the visit records, visit locations and visit routes you generate. Your employer decides who in their organisation can see your visit history and visit routes.
- **Digital Harbor is a data processor** — we build, host and maintain the App and its backend on behalf of your employer. We process your data only on their instructions.

If you have questions about how *your employer* uses this data (retention, access, deletion), contact your employer's HR or IT department directly.

---

## 2. Information we collect

### 2.1 Account information
When your employer creates your account on the backend (Odoo) you provide:
- Your name, email or username, and an internal user and employee ID.
- Authentication credentials (password). The password is kept only in the device's secure storage (Android Keystore / iOS Keychain) so the App can renew your session, and is never written to logs or crash reports.

### 2.2 Location information
The App collects your device's location **only for customer visits**, in the following cases:

| When | What | Why | Stored where |
| ---- | ---- | --- | ------------ |
| When you tap **Start Visit** on an approved visit | One position | To record where and when the visit started; it is the first point of the visit route | Visit record on your employer's backend |
| When you tap **End Visit** | One position | To record where and when the visit ended; it is the last point of the visit route | Visit record on your employer's backend |
| **While a visit you started is in progress** — from the moment your employer's backend confirms the start until you tap **End Visit** or sign out, **including while the App is in the background or your screen is locked** | Positions: latitude, longitude, the time each position was taken, accuracy, altitude, speed and heading, together with a random identifier generated for this installation of the App | To record the route of that visit | Visit route on your employer's backend |
| If you add a location when you create a visit | The position or address you add | To plan where the visit takes place | Visit record on your employer's backend |

**Visit route recording.** Recording starts only after your employer's backend has confirmed that the visit has started. If you tap Start Visit without a network connection, recording starts once the backend has accepted that start. While the visit is in progress, the App records a position about every 5 seconds while you are moving, and nothing while you stand still. It keeps doing so when you switch to another app or lock your screen. On Android a notification ("Visit tracking active") is shown for as long as recording runs; on iOS the system shows its blue location indicator. Recording stops as soon as you tap End Visit. Before your first Start Visit, the App shows a screen explaining what is collected, that recording continues in the background and with the screen locked while the visit is in progress, when it stops, and where the data goes.

**When the App does not collect location:**
- before you tap **Start Visit** — and, apart from the single Start Visit position, until your employer's backend has confirmed the start;
- between visits, and whenever no visit is in progress — the App does not record your movements outside a visit, and does not record a whole work day;
- after you tap **End Visit** — recording stops immediately;
- after you sign out;
- when you have not granted location permission, or have revoked it.

A push notification never starts location recording.

**Offline storage.** If there is no network, recorded positions are kept on your device, in the App's private storage, and uploaded later — even after the visit has ended — with the time each position was actually taken. Your employer's backend accepts only positions taken between the start and the end of the visit. Positions are kept separately for each signed-in account and are uploaded only for the account that recorded them. They are deleted from the device once uploaded, or once the backend has permanently refused them.

**Road matching (map display).** To draw a visit's recorded route along roads on the map, the App may send the recorded positions of that visit only (coordinates, their accuracy, heading, and time offsets relative to the first position — not the actual date and time) to a road-matching service. That service only returns a line to draw; your recorded positions are not changed. No name, employee ID, device ID, account credential or session is sent to it. In the production App this service is operated by Digital Harbor on infrastructure it controls (directly or through a hosting provider acting on its behalf), never by a public routing service; if none is configured, routes are drawn exactly as recorded and nothing is sent for road matching. The resulting map lines are cached on the device for up to 30 days and deleted when you sign out.

### 2.3 Visit content
You create visit records that include: the customer being visited, visit type, free‑text notes you choose to write, the outcome, and the visit state. You may optionally capture a photo with the camera or attach a file as proof of the visit; only what you choose at that moment is uploaded. This content is stored on your employer's backend.

### 2.4 Device & technical data
- The requests needed to call your employer's backend, over HTTPS only.
- A device-specific push notification token (Firebase Cloud Messaging) and a random identifier generated for this installation of the App, stored on your employer's backend against your account, so you can be notified about visit assignments and approvals.
- Crash reports and performance measurements sent to Sentry, configured to exclude personal information: they do not include your name, email, location or IP address, and no screenshots are attached.
- Map tiles: to display a map, the App downloads the map images for the area shown on screen from OpenStreetMap tile servers. These requests contain only the map area being displayed (and, like any internet request, your device's IP address); the App does not send your position or any identifier to them.
- Generic device locale (so the App displays in Arabic or English).

The App does **not** collect: contact lists, microphone audio, your photo library, files outside what you choose to attach, the IMEI, advertising identifiers, or any analytics fingerprint.

---

## 3. How we use the information

We use the information described above strictly to provide the App's features:

1. **Authenticate you** against your employer's backend.
2. **Record visits** and prove you were physically at the customer's location when the visit started and ended.
3. **Record the route of each visit** while it is in progress, for your employer's visit reports.
4. **Show maps** of customers and visits, with visit routes drawn along roads where road matching is available.
5. **Notify you** about visit assignments, approvals and changes.
6. **Keep working offline** — actions and recorded positions are stored on the device and sent automatically when connectivity returns.

We do **not** use your location outside customer visits, do not share your live position with anyone, and do **not** use your data for advertising, profiling, behavioural analytics, or sale to third parties.

---

## 4. Background location during an active visit

The App uses your location in the background **only while a customer visit you started is in progress**.

- **Android:** recording runs in a foreground service of type "location", started when your employer's backend confirms Start Visit, with a "Visit tracking active" notification visible for as long as it runs. The App requests location access only "while using the app" and does **not** request the Android `ACCESS_BACKGROUND_LOCATION` permission.
- **iOS:** the App declares the iOS "location" background mode. With "While Using the App" access, recording that started when you started the visit in the App continues in the background, and iOS shows the blue location indicator. The App does not ask for "Always" access. If you choose "Always" yourself in Settings, iOS may relaunch the App to continue recording a visit that is still in progress after iOS closed the App.
- **If the App is closed:** if the system stops the App during a visit, recording resumes — at the latest when you next open the App — as long as the visit is still in progress. On iOS, an App you swiped away (force-quit) is not relaunched by the system; recording resumes when you open it again.
- **Stopping:** tap **End Visit**, or sign out. You can also revoke location access at any time from Settings → Apps → Customer Visits → Permissions (Android) or Settings → Privacy & Security → Location Services → Visits (iOS). Visit locations and visit route recording then stop working until access is granted again.

---

## 5. Permissions the App requests

| Permission | Reason |
| ---------- | ------ |
| Precise and approximate location (while using the app) | Start Visit and End Visit positions, and the route of a visit in progress |
| Android: foreground service (location) | Keep recording the route of a visit in progress while the App is in the background or the screen is locked, with a visible notification |
| iOS: location background mode | Keep recording the route of a visit in progress while the App is in the background, with the blue location indicator |
| iOS: temporary precise location | Asked only if you turned Precise Location off, because a visit route cannot be recorded accurately without it |
| Notifications | Visit workflow notifications; on Android also the visible visit-tracking notification |
| Camera (and, on iOS, the photo library prompt text) | Optional proof-of-visit photos |
| Internet / network state | Talk to the backend; detect offline state to queue actions |

The App does **not** request: the Android background location permission (`ACCESS_BACKGROUND_LOCATION`), "Always" location access on iOS, microphone, contacts, calendar, SMS or phone.

---

## 6. Data sharing

We share your data only with the following parties:

- **Your employer**, who is the controller of the data. Anyone in your employer's organisation whom your employer grants manager rights can see the visit history and visit routes of the employees they manage.
- **Our hosting providers**, strictly to operate the backend and, where configured, the road-matching service. No marketing or other processing.
- **Sentry** (crash and performance reports without personal information), **Firebase Cloud Messaging** (delivery of push notifications) and **OpenStreetMap tile servers** (map images for the area displayed, without your position or any identifier).
- **Authorities**, only if we are legally compelled by a valid court order.

We do **not** sell or share your data with advertisers, analytics platforms, or data brokers.

---

## 7. Data retention

- **Session and credentials** stored on the device: deleted on sign-out.
- **Positions waiting to upload** on the device: deleted once uploaded, or once your employer's backend has permanently refused them.
- **Positions left on the device by an earlier version of the App** that recorded work-day routes: deleted from the device when the App is updated.
- **Road-matched map lines** cached on the device: up to 30 days, deleted on sign-out.
- **Visit records and visit routes** on the backend: retained according to your employer's retention schedule. Recorded positions cannot be edited or deleted from the App. Contact your employer to request deletion.

---

## 8. Security

- All traffic between the App and the backend and road-matching service is over HTTPS (TLS). Cleartext HTTP is blocked on both Android (`usesCleartextTraffic=false`) and iOS (App Transport Security).
- Credentials are stored in the device's secure storage (Android Keystore / iOS Keychain).
- Positions waiting to upload are stored in the App's private storage, and the App is excluded from Android cloud backups.
- On the backend, only the employee responsible for a visit (or whoever planned it, or an administrator) can add positions to it, only positions taken between the visit's start and end are accepted, managers can only see the employees they manage, and recorded positions cannot be changed from the App.

No system is 100% secure. If you suspect your account is compromised, change your password from your employer's portal immediately.

---

## 9. Children

The App is a workplace tool intended for adult employees of our customer organisations. It is **not** directed at children under 16, and we do not knowingly collect data from anyone under 16.

---

## 10. Your rights

Because your employer is the controller of the data:

- To request **access, correction, or deletion** of your visit history or visit routes, contact your employer's HR or IT.
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

