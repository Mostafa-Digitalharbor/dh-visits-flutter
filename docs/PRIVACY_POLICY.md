# Privacy Policy — Customer Visits

**Effective date:** _<!-- Replace with the date you publish this policy, e.g. 1 June 2026 -->_
**Last updated:** _<!-- Same as effective date for the first version -->_

This Privacy Policy describes how **Digital Harbor** ("we", "us", "our") collects, uses, and protects information when you use the **Customer Visits** mobile application ("the App"). The App is a field‑workforce tool: employees of our customer organisations use it to check in and out of customer site visits, and to share their live work location with their direct manager during working hours.

If you have any question about this policy, contact us at: **ai-tools@digital-harbor.net**

---

## 1. Who controls your data

The App is provided by Digital Harbor as a tool for our customer organisations (your employer). When you use the App as part of your job:

- **Your employer is the data controller** for the visit records and live‑location data you generate. Your employer decides who in their organisation can see your location and visit history.
- **Digital Harbor is a data processor** — we build, host and maintain the App and its backend on behalf of your employer. We process your data only on their instructions.

If you have questions about how *your employer* uses this data (retention, access, deletion), contact your employer's HR or IT department directly.

---

## 2. Information we collect

### 2.1 Account information
When your employer creates your account on the backend (Odoo) you provide:
- Your name, email or username, and an internal employee ID.
- Authentication credentials (password). Passwords are never stored on the device in plain text; only an authenticated session token is kept in the device's secure storage.

### 2.2 Location information
The App collects your device's GPS coordinates (latitude, longitude, accuracy radius and timestamp) in the following cases:

| When | Why | Stored where |
| ---- | --- | ------------ |
| When you tap "Check‑in" or "Check‑out" of a visit | To prove you were at the customer site and to record arrival/departure times | Visit record on your employer's Odoo backend |
| Approximately every 30 seconds **while the App is open on your screen** | To share your live position with your manager so they know where the field team is during the work day | "Live employee location" record on your employer's Odoo backend, overwriting the previous value |

**The App does not collect or transmit your location when it is in the background, closed, or when you are not logged in.** Live sharing pauses automatically the moment you leave the App and resumes when you return to it. There is no persistent background tracking.

### 2.3 Visit content
You create visit records that include: the customer being visited, visit type, free‑text notes you choose to write, and the visit state (draft / submitted / under review / done / cancelled). This content is stored on your employer's Odoo backend.

### 2.4 Device & technical data
For diagnostics, the App may transmit:
- The HTTP request needed to call the backend API (URL, headers, JSON body), over HTTPS only.
- Generic device locale (so the App displays in Arabic or English).

The App does **not** collect: contact lists, photos, microphone audio, files outside its own sandbox, the IMEI, ad identifiers, or any analytics fingerprint.

---

## 3. How we use the information

We use the information described above strictly to provide the App's features:

1. **Authenticate you** against your employer's Odoo instance.
2. **Record visits** and prove you were physically at the customer's location.
3. **Share your live location with your manager** during the work day.
4. **Show maps** of customers, nearby employees and your own position.
5. **Queue offline actions** (a check‑in performed while offline is stored locally and re‑sent automatically when connectivity returns).

We do **not** use your data for advertising, profiling, behavioural analytics, or sale to third parties.

---

## 4. No background tracking

The App **does not** track your location in the background.

- The App requests only "While Using the App" location access — both on iOS (`When In Use`) and on Android (`Precise location, only while using the app`).
- The App does not declare the Android `ACCESS_BACKGROUND_LOCATION` permission, and does not declare the iOS `location` background mode.
- The instant you switch to another app, lock your screen, or close the App, the live‑location ticker stops. It restarts automatically when you bring the App back to the foreground.
- You can revoke location access at any time from Settings → Apps → Customer Visits → Permissions (Android) or Settings → Privacy → Location → Visits (iOS). If you do, check‑in/out and live sharing will both stop working until you re‑grant it.

---

## 5. Permissions the App requests

| Permission | Reason |
| ---------- | ------ |
| Precise location (foreground / "while using") | Record visit check‑in/out coordinates; share live position with manager while App is open |
| Internet / network state | Talk to the backend; detect offline state to queue actions |

The App does **not** request: background location, foreground service, camera, microphone, contacts, calendar, SMS, phone, or files/photos.

---

## 6. Data sharing

We share your data only with the following parties:

- **Your employer**, who is the controller of the data. Anyone in your employer's organisation that your employer has granted manager privileges to can see your live location and visit history.
- **Our cloud hosting provider** (Odoo SH / equivalent), strictly to operate the backend. No marketing or third‑party processing.
- **Authorities**, only if we are legally compelled by a valid court order.

We do **not** sell or share your data with advertisers, analytics platforms, or data brokers.

---

## 7. Data retention

- **Session token** stored on the device: cleared automatically on logout, or when the OS evicts the secure storage.
- **Live location** on the backend: overwrites the previous value, so we keep only your *most recent* live position, not a track history. Older values are not retained.
- **Visit records**: retained according to your employer's retention schedule. Contact your employer to request deletion.

---

## 8. Security

- All traffic between the App and the backend is over HTTPS (TLS). Cleartext HTTP is blocked at the OS level on both Android (`usesCleartextTraffic=false`) and iOS (App Transport Security).
- The session token is stored using the device's secure storage (Android KeyStore / iOS Keychain).
- The App is excluded from automatic Android cloud backups so the session secret is never copied to a different device.

No system is 100% secure. If you suspect your account is compromised, change your password from your employer's Odoo portal immediately.

---

## 9. Children

The App is a workplace tool intended for adult employees of our customer organisations. It is **not** directed at children under 16, and we do not knowingly collect data from anyone under 16.

---

## 10. Your rights

Because your employer is the controller of the data:

- To request **access, correction, or deletion** of your visit history or live‑location record, contact your employer's HR or IT.
- For complaints about how Digital Harbor (the processor) handles your data, contact us at **ai-tools@digital-harbor.net**.
- Depending on your country, you may also have the right to lodge a complaint with your local data protection authority.

---

## 11. Changes to this policy

We may update this policy when we add features, change subprocessors, or comply with new regulations. We will publish the updated policy at the same URL where you found this document and update the "Last updated" date at the top. Material changes will additionally be communicated via the App on next launch.

---

## 12. Contact

**Digital Harbor**
Email: **ai-tools@digital-harbor.net**
Website: **https://digital-harbor.net** _<!-- replace with the real public URL if different -->_

---

_This policy is provided as a template tailored to the Customer Visits App's actual data flows. Please review it with your legal counsel before publishing publicly. Replace all italic placeholder text (effective date, company address if you want to publish one, etc.) before going live._
