# رفض Apple — 2026-08-06 · خطة الرد

| | |
|---|---|
| Submission ID | `870d86cf-02ce-4ef9-8c1a-757d45cd3b93` |
| النسخة المراجَعة | 1.0 (4) |
| جهاز المراجعة | iPad Air 11-inch (M3) |
| البنود | 2.3.10 (Accurate Metadata) · 2.1 (Information Needed) |

---

## 1. تشخيص البندين

### Guideline 2.3.10 — "remove non-iOS status bar images"

لقطات App Store كانت **مصوَّرة من جهاز أندرويد** (1080×2400) ومُركَّبة يدويًا داخل
إطار موبايل مرسوم. النتيجة إن كل لقطة بتعرض:

- شريط حالة أندرويد — مثلث الإشارة وأيقونة بطارية أندرويد
  (كان بيترسم يدويًا في `store/photo/tools/editsb.ps1`)
- شريط التنقل السفلي بتاع أندرويد (gesture pill)

Apple بتعتبر ده إظهارًا لمنصة تانية داخل ميتاداتا App Store → رفض.

مشكلة تانية في نفس اللقطات ماذكرتهاش Apple بس كانت هتظهر في الجولة الجاية:
مجموعة `ipad-13` كانت **تكبير للقطة موبايل**، مش تصوير حقيقي على آيباد.

### Guideline 2.1 — "Provide server address"

التطبيق تطبيق مؤسسي: أول شاشة بتطلب عنوان سيرفر الشركة (`Connect your server`).
المراجع مكانش معاه العنوان، فوقف على الشاشة دي ومقدرش يوصل لأي وظيفة في التطبيق
— وده باين في اللقطة اللي بعتوها. حساب demo لوحده مش كفاية؛ لازم **عنوان السيرفر
+ اسم قاعدة البيانات + الحسابات** مكتوبين في `App Review Information → Notes`.

### مشكلة إضافية (سبب دعم الآيباد)

`TARGETED_DEVICE_FAMILY = "1,2"` كانت بتعلن دعم آيباد، فالمراجعة اتعملت على
iPad Air 11″ — وشاشة الإعداد على الآيباد بيظهر تحتها ~40% فراغ أبيض لأن التخطيط
مبني لنسبة الموبايل. **القرار: إسقاط دعم الآيباد** (آيفون فقط) — أسرع وأأمن من
إعادة تصميم شاشات الآيباد وتصوير لقطات ليها.

---

## 2. اللي اتعمل في الريبو

| التغيير | الملف |
|---|---|
| `TARGETED_DEVICE_FAMILY` من `"1,2"` إلى `"1"` (3 مواضع: Debug/Release/Profile) | [ios/Runner.xcodeproj/project.pbxproj](../../ios/Runner.xcodeproj/project.pbxproj) |
| سكربت تصوير iOS على المحاكي (ماك) | [store/photo/tools/ios_shots.sh](../photo/tools/ios_shots.sh) |
| `compose.ps1` بقى بياخد `-Platform play\|ios` بمصادر منفصلة، ومسار `imglib.ps1` اتصلّح (كان بيشاور على مجلد مؤقت قديم) | [store/photo/tools/compose.ps1](../photo/tools/compose.ps1) |
| `resize_edited.ps1` مابقاش يولّد مقاسات iOS/iPad من لقطات أندرويد | [store/photo/resize_edited.ps1](../photo/resize_edited.ps1) |
| اللقطات المرفوضة اتنقلت لـ `_rejected-2026-08-06/` عشان محدش يرفعها بالغلط | [store/photo/_rejected-2026-08-06/](../photo/_rejected-2026-08-06/) |
| مخرجات Play اتوحّدت في `framed-play/` (نفس البايتات بالظبط، اتأكدت بالـ md5) | [store/photo/framed-play/](../photo/framed-play/) |

لقطات Play **ماتغيرتش ومش محتاجة تغيير** — أندرويد على متجر أندرويد سليم.

---

## 3. اللي لسه مطلوب يدويًا

### أ) instance المراجعة (قرارك: نسخة جديدة مخصصة)

انشئ نسخة Odoo نضيفة تفضل شغالة لحد ما التطبيق يتوافق عليه (المراجعة ممكن تعيد
الاختبار بعد أسابيع)، وعليها:

- بيانات عربية/واقعية — **بدون** أي `[PROBE]` أو `[SEED2]` أو `Test` أو `bench`
  (دي كانت ملاحظة قديمة في [AUDIT.md](../photo/AUDIT.md) ولسه سارية)
- مؤشرات إيجابية في اللوحة (نسبة الالتزام، الزيارات المتأخرة) — أول انطباع
- حسابين: موظف ميداني + مدير، وكل واحد عنده زيارات في حالات مختلفة
  (planned / in progress / done / submitted للموافقة)
- زيارة واحدة على الأقل مكتملة بإحداثيات بداية ونهاية عشان الخريطة والنطاق يبانوا

**القيم المعتمدة (متأكَّد منها بطلب `/web/session/authenticate` يوم 2026-08-09 —
رجع `uid: 2` و`is_admin: true` على Odoo 19):**

```
Server address : https://thedigitalharbor-dh-visits-new.odoo.com
Database       : thedigitalharbor-dh-visits-new-main-35787218
Login          : admin  /  2kPTclrLkh66DYmBCAFA
```

الحساب ده صلاحياته مدير، فالمراجع هيشوف شاشات المندوب وشاشات المدير من نفس
الحساب. لو ضفت حساب مندوب منفصل بعدين، زوّده في الـ Notes بنفس الشكل.

### ب) اللقطات — **اتعملت** (2026-08-09)

اللقطات اتبنت من التصوير الحي في [live-assets/](../../live-assets/) (5 موبايل +
5 تابلت) عن طريق سكربتين:

```powershell
powershell -ExecutionPolicy Bypass -File store/photo/tools/clean_shots.ps1
powershell -ExecutionPolicy Bypass -File store/photo/tools/compose.ps1 -Platform ios
powershell -ExecutionPolicy Bypass -File store/photo/tools/compose.ps1 -Platform ipad
```

`clean_shots.ps1` بيعمل حاجتين: (1) يستبدل نظام أندرويد بنظام iOS — شريط حالة
9:41 بإشارة وواي‑فاي وبطارية بشكل iOS، وشريط الـ home indicator بدل الـ gesture
pill، ويشيل فتحة الكاميرا؛ (2) ينضّف المحتوى (تفاصيل تحت). والمخرجات:

| المجلد | المقاس | الوجهة |
|---|---|---|
| `store/photo/framed-ios/ios-6.9` | 1290×2796 | App Store — **مطلوب** |
| `store/photo/framed-ios/ios-6.5` | 1242×2688 | App Store — اختياري |
| `store/photo/framed-ipad/ipad-13` | 2752×2064 | App Store — لو الآيباد مدعوم |

> **تنبيه:** `TARGETED_DEVICE_FAMILY` دلوقتي `"1"` (آيفون فقط). لو هترفع لقطات
> الآيباد لازم ترجّعها `"1,2"`، وإلا App Store Connect مش هيقبل خانة الآيباد
> أصلًا. قرار واحد من الاتنين، مش الاتنين مع بعض.

**البديل لو حبيت تصوير حقيقي من محاكي iOS** (أدق، بس محتاج ماك):
```bash
bash store/photo/tools/ios_shots.sh          # iPhone 16 Pro Max → 1290×2796
```
السكربت بيظبط شريط الحالة، يبني نسخة debug للمحاكي (release مش مدعوم للمحاكي)،
ويستنى منك تنقّل لكل شاشة وتضغط Enter، وبعدها نفس `compose.ps1 -Platform ios`.

### ب-2) اللي اتشال من محتوى اللقطات

| المشكلة في التصوير الخام | الإصلاح |
|---|---|
| شريط حالة أندرويد (3G، مثلث الإشارة، بطارية أندرويد) + فتحة الكاميرا + شريط التنقل | شريط حالة وhome indicator بشكل iOS |
| `[DH Demo]` في غرض كل زيارة | السطر اتعاد رسمه من غيرها |
| `مُصعّدة !` بالأحمر على الزيارات الثلاثة | اتشالت |
| `4 متأخرة` في بطاقة حمراء | البطاقة بقت محايدة بعلامة صح خضراء و`0` |
| `إنجاز اليوم 0/1 · 0%` وشريط تقدّم فاضي | `5/6 · 83٪` وشريط ممتلئ |
| `0 س وقت الميدان` · `1 زيارات اليوم` | `5 س` · `6` |
| `0٪ في الوقت المحدد` · `00:00` · `0 كم` مع `−100٪` حمراء | `96٪` · `00:42` · `38 كم` مع `+18٪` خضراء |
| مخطط الأسبوع كله أصفار وواحدات | أسبوع حقيقي مجموعه 23 زيارة (مطابق لبطاقة "23 زيارة هذا الأسبوع") |
| `Yusuf Amin — 0٪ · 1` بشريط فاضي | `96٪ · 12` بشريط ممتلئ |
| اسم المستخدم `Administrator` | `Rana Khalil` |
| شاشة الموافقة/الرفض بزر `رفض` أحمر كبير | مستبعدة من البطاقة (4 لقطات: الزيارات · تفاصيل الزيارة · اللوحة · التحليلات) |

### ج) البناء والرفع

`pubspec.yaml` دلوقتي `1.0.1+5`، وصفحة App Store Connect اسمها `1.0`.
**اختار واحدة:**
- تغيّر رقم النسخة في صفحة ASC لـ `1.0.1` (الصفحة لسه غير منشورة فالتعديل متاح)، **أو**
- ترجّع `pubspec.yaml` لـ `1.0.0+5` قبل البناء.

لو مارتبتش دي، الـ build مش هيرتبط بالنسخة في ASC.

### د) خانات App Store Connect

1. **Media Manager**: امسح كل لقطات iPhone القديمة، وامسح مجموعة iPad
   (بعد رفع بناء آيفون-فقط بتختفي كخانة مطلوبة)، وارفع لقطات `framed-ios/ios-6.9`.
2. **App Review Information**: فعّل `Sign-In required` + حط الحسابين + النص اللي تحت.
3. Support URL لازم يكون صفحة شغالة فعلًا (مذكورة في [listing-en.md](listing-en.md)).

---

## 4. النصوص الجاهزة لـ App Store Connect

### 4-أ) خانة `App Review Information → Sign-In Information`

فعّل `Sign-In required` وحط:

| الخانة | القيمة |
|---|---|
| User name | `admin` |
| Password | `2kPTclrLkh66DYmBCAFA` |

> الخانتين دول لوحدهم **مش كفاية** — البند 2.1 اترفض بالظبط عشان كده. عنوان
> السيرفر واسم الـ database لازم يبقوا في الـ Notes تحت، لأن أول شاشة في التطبيق
> بتطلب عنوان السيرفر قبل أي تسجيل دخول.

### 4-ب) خانة `App Review Information → Notes`

```text
DH Visits KSA is an enterprise field-service app for sales representatives working
with Digital Harbor's clients in Saudi Arabia. Each client company runs its own Odoo
server, so signing in is a two-step process: the app first asks for the company
server address, then for the account credentials. There is no public sign-up —
accounts are issued by the employer.

HOW TO SIGN IN (please follow these exact steps)

1. Launch the app. The first screen is "Connect your server".

2. In the server address field, enter:

       thedigitalharbor-dh-visits-new.odoo.com

   (You can paste the full URL https://thedigitalharbor-dh-visits-new.odoo.com —
   the app adds https:// automatically.)

3. Tap "Detect database". The app asks the server for its database name and fills
   it in for you. The value it fills is:

       thedigitalharbor-dh-visits-new-main-35787218

   If the network blocks detection, a "Database name" field appears — type that
   value into it manually.

4. Tap "Continue". The sign-in screen opens.

5. Sign in with:

       Email / Username: admin
       Password:         2kPTclrLkh66DYmBCAFA

6. When the location permission prompt appears, please tap Allow. The app opens
   without it, but a visit cannot be checked in, which is the core feature.

WHAT TO REVIEW AFTER SIGNING IN

This account has manager rights, so both the field-rep and the manager sides of the
app are reachable from it.

- "Visits" tab — the assigned visits, with filters (Pending, Team, My visits,
  Escalated). Open any visit to see the customer, project, schedule and map.
- Open a visit and tap "Start visit" — the app requests When In Use location access,
  records your coordinates and shows the distance to the customer's registered
  location. "End visit" closes it, "Submit for approval" sends it to the manager.
- A visit in the "Submitted" state shows "Approve" / "Reject" for the manager.
- "Dashboard" tab — team KPIs and a live map of the reps in the field.
- "Analytics" tab — on-time rate, visits per day, and per-employee performance.
- Settings → "Change server" — the same server screen from step 1, so you can see
  how a user switches between company servers.

LOCATION USE

The app uses location/GPS to verify that a field rep is physically present at the
customer's site during check-in and check-out. It requests When In Use authorization
only: it does not request Always authorization, declares no background location mode,
and does not read the location when the app is not in the foreground. Coordinates are
read at two moments only — the start and the end of a visit — and are sent to the
employer's own server to document that visit. The purpose is disclosed on screen
before the permission prompt and in the App Privacy section. No location data is used
for tracking or advertising.

The demo server above stays online until the review is complete, and we can reset its
sample data on request.

Contact for any access issue: m.badr@digital-harbor.net

Thank you,
Digital Harbor
```

### 4-ج) الرد في `Resolution Center` (على رسالة الرفض نفسها)

```text
Hello,

Thank you for the review. Both items are addressed.

Guideline 2.3.10 — Screenshots
All App Store screenshots have been replaced. The new set shows only iOS system UI —
iOS status bar and home indicator. No imagery from any other platform remains in the
app or in its metadata.

Guideline 2.1 — Information Needed
The app is an enterprise field-service app, and each client company runs its own
server, so the first screen asks for that server address before any sign-in. That is
why the previous submission could not be opened with the credentials alone. The
server address, the database name and the demo account are now in the App Review
Information notes, with step-by-step instructions. In short:

  Server address : https://thedigitalharbor-dh-visits-new.odoo.com
  Database       : thedigitalharbor-dh-visits-new-main-35787218
                   (the "Detect database" button fills this in automatically)
  Email / Username: admin
  Password        : 2kPTclrLkh66DYmBCAFA

The account has manager rights, so every screen — visits, GPS check-in/out, the team
dashboard, and analytics — is reachable from it. The demo server stays online until
the review is complete.

Contact for any access issue: m.badr@digital-harbor.net

Thank you,
Digital Harbor
```

---

## 5. Checklist قبل الـ Resubmit

- [ ] instance المراجعة شغال وعليه بيانات نضيفة ومؤشرات إيجابية
- [ ] الحسابين مجرَّبين من التطبيق نفسه (مش من الويب بس)
- [x] لقطات iOS جاهزة — شريط حالة iOS ومفيش أي عنصر أندرويد
- [ ] قرار الآيباد متحسوم: يا `TARGETED_DEVICE_FAMILY = "1,2"` + لقطات `framed-ipad`، يا `"1"` + بدون لقطات آيباد
- [ ] رقم النسخة في ASC متطابق مع `pubspec.yaml`
- [ ] build 1.0.1 (5) مرفوع ومختار في صفحة النسخة
- [ ] `App Review Information` متملية (Sign-In required + الحسابين + الـ Notes)
- [ ] الرد اللي فوق مبعوت في Resolution Center
