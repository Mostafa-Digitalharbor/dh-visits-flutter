# Push Notifications — Backend Requirements (dh_visit_management)

> **الهدف:** يوصل للموبايل **إشعار فوري (push)** عند كل حدث في دورة حياة الزيارة —
> حتى والتطبيق مقفول أو في الخلفية — لكل الأطراف المعنيين (المندوب / المدير /
> مدير المشارك / مدير المشروع).
>
> هذا المستند موجّه لفريق الباك إند (Odoo). التطبيق (Flutter) جاهز لاستقبال الـ push
> بمجرد ما الباك إند يوفّر الـ endpoints والإرسال الموضّح تحت.

---

## 0. الوضع الحالي (شغّال بدون أي تغيير باك إند)

التطبيق **بالفعل** بيعرض إشعارات داخلية (in-app) عن طريق قراءة `mail.activity`
الموجودة اللي الموديول بيعملها للمدير:

- شاشة **Notifications** + جرس فيه **badge** بعدد الأنشطة المعلّقة.
- المصدر: `mail.activity` حيث `res_model='dh.visit'` و `user_id = <current user>`.

ده **pull** (لمّا يفتح التطبيق / يرجع للـ foreground). الناقص هو **push** الحقيقي
(لمّا التطبيق مقفول) — وده اللي محتاج شغل باك إند + Firebase.

---

## 1. المعمارية المطلوبة (نظرة عامة)

```
[Flutter app]  --register token-->  [Odoo: /api/visit/register_device]  --store-->  dh.visit.device.token
      ^                                                                                     |
      |                                                                                     | on each workflow event
      |  FCM / APNs push  <----------------  [Odoo sends to FCM HTTP v1]  <-----------------+
```

مكوّنان مطلوبان في الباك إند:
1. **تخزين توكن الجهاز** لكل مستخدم (endpoint + model).
2. **إرسال push** عبر FCM (HTTP v1) عند كل انتقال حالة، للمستلمين الصح.

---

## 2. جدول الأحداث والمستلمين (Event Matrix)

لكل حدث: مين يستقبل، وعنوان/نص الإشعار المقترح. المستلمون يتحدّدوا من حقول الزيارة
(`employee_id.user_id`, `direct_manager_id.user_id`, `higher_manager_id.user_id`,
`participant_ids.manager_id.user_id`, ومجموعة `group_visit_project_manager`).

| الحدث (method / cron) | من → إلى (user) | العنوان | النص |
|---|---|---|---|
| `action_submit` (فيه مشاركون) | → مدير كل مشارك | Participation approval | Approve {employee} for {ref} |
| `action_submit` (بدون مشاركين) | → المدير المباشر | New visit to approve | {employee}: {ref} awaits your approval |
| موافقة كل المشاركين | → المدير المباشر | Visit ready for approval | {ref} awaits your approval |
| رفض مشارك | → صاحب الزيارة | Participant rejected | {employee} was rejected for {ref} |
| `action_approve` | → صاحب الزيارة | Visit approved | Your visit {ref} was approved |
| `action_reject` | → صاحب الزيارة | Visit rejected | {ref} rejected: {reason} |
| Escalation cron (24h) | → المدير الأعلى + Project Managers | Visit escalated | {ref} escalated — needs approval |
| `action_open_reschedule_wizard` (طلب) | → المدير المباشر | Reschedule requested | {employee} requested a reschedule for {ref} |
| موافقة إعادة الجدولة | → صاحب الزيارة | Reschedule approved | {ref} reschedule approved |
| `action_start_visit` | → المدير المباشر (اختياري) | Visit started | {employee} started {ref} |
| `action_end_visit` | → المدير المباشر (اختياري) | Visit completed | {employee} completed {ref} |
| `action_cancel` | → المدير / صاحب الزيارة | Visit cancelled | {ref} was cancelled |

> النصوص مقترحة — عدّلوها زي ما تحبوا. المهم يكون فيه `data` payload ثابت (تحت).

---

## 3. Endpoint: تسجيل توكن الجهاز

نفس نمط باقي الـ API (`type='json'`, `auth='user'`, JSON-RPC envelope).

### 3.1 `POST /api/visit/register_device`
يخزّن/يحدّث توكن FCM للمستخدم الحالي.

| Param | Type | Required | Description |
|---|---|---|---|
| `token` | string | yes | FCM registration token |
| `platform` | string | yes | `android` \| `ios` |
| `device_id` | string | no | معرّف ثابت للجهاز (لمنع التكرار) |

**result:** `{ "ok": true }`

### 3.2 `POST /api/visit/unregister_device`
يمسح التوكن (عند تسجيل الخروج).

| Param | Type | Required |
|---|---|---|
| `token` | string | yes |

**result:** `{ "ok": true }`

---

## 4. Model: `dh.visit.device.token`

```python
class VisitDeviceToken(models.Model):
    _name = 'dh.visit.device.token'
    _description = 'Mobile push token'

    user_id   = fields.Many2one('res.users', required=True, index=True, ondelete='cascade')
    token     = fields.Char(required=True, index=True)
    platform  = fields.Selection([('android', 'Android'), ('ios', 'iOS')])
    device_id = fields.Char()
    active    = fields.Boolean(default=True)
    last_seen = fields.Datetime(default=fields.Datetime.now)

    _sql_constraints = [('token_uniq', 'unique(token)', 'Token already registered')]
```

عند `register_device`: upsert بالـ `token` (لو موجود حدّث `user_id`/`last_seen`).
عند إرسال push بيرجّع FCM خطأ `UNREGISTERED`/`NOT_FOUND` → امسح التوكن (`active=False`).

---

## 5. الإرسال عبر FCM (HTTP v1)

- استخدموا **FCM HTTP v1 API** (مش الـ legacy). Auth عن طريق **Service Account JSON**
  من Firebase project (scope: `https://www.googleapis.com/auth/firebase.messaging`).
- iOS: لازم **APNs Auth Key (.p8)** مرفوع في نفس Firebase project.
- لكل حدث: هاتوا كل توكنات المستلمين (`dh.visit.device.token` بالـ `user_id`) وابعتوا لكل واحد.

### الحمولة (Payload) — ⚠️ **لازم** يكون فيها بلوك `notification` **+** بلوك `data` معًا (مش data-only):

> **تصحيح مهم:** أي نسخة قديمة من الكلام ده كانت بتقول "data-only مُوصى به" — **ده غلط
> ويكسر الإشعارات**. التطبيق في حالة الخلفية/الإنهاء بيعتمد على إن **النظام** يعرض بلوك
> `notification` تلقائيًا؛ لو بعتّوا `data` بس (من غير `notification`) الإشعار **مش هيظهر خالص**
> في الخلفية — نفس عرض المشكلة اللي بنحاول نحلها. لازم الاتنين مع بعض زي المثال تحت بالظبط.

```json
POST https://fcm.googleapis.com/v1/projects/<PROJECT_ID>/messages:send
Authorization: Bearer <oauth2-access-token-from-service-account>

{
  "message": {
    "token": "<device-token>",
    "notification": { "title": "Visit approved", "body": "Your visit VIS/2026/00042 was approved" },
    "data": {
      "type": "visit_event",
      "event": "approved",
      "visit_id": "42",
      "visit_ref": "VIS/2026/00042",
      "state": "approved"
    },
    "android": { "priority": "high" },
    "apns": { "headers": { "apns-priority": "10" }, "payload": { "aps": { "sound": "default" } } }
  }
}
```

### أيقونة الإشعار

**مش محتاجة أي حاجة من الباك إند** — التطبيق بيحدّد الأيقونة واللون في الـ manifest
(`default_notification_icon` + `default_notification_color`)، فالنظام بيستخدمهم تلقائيًا
في إشعارات الخلفية/الإنهاء.

⚠️ **متبعتوش `android.notification.icon` في الحمولة.** لو بعتّوها هتـ override إعداد
التطبيق، ولازم تكون اسم drawable موجود جوّه الـ APK (`ic_notification`) — أي اسم تاني
بيخلّي الإشعار يظهر من غير أيقونة خالص.

خلفية مهمة: أندرويد بيرمي ألوان أيقونة شريط الحالة ويستخدم **قناة الشفافية بس**، عشان كده
الأيقونة لازم تفضل صورة ظلّية بيضاء على خلفية شفافة (`ic_notification`)، واللوجو الملوّن
بيوصل كـ **large icon** جنب النص.

لو عايزين اللوجو الملوّن يظهر في إشعارات الخلفية كمان، ضيفوا `image` (بيتعرض كصورة كبيرة):

```json
"android": {
  "priority": "high",
  "notification": { "image": "https://<host>/visit-logo.png" }
}
```

> **مهم:** حقل `data.visit_id` لازم يكون موجود دايمًا — التطبيق بيستخدمه يفتح شاشة الزيارة
> مباشرة (`/visits/<visit_id>`). كل القيم في `data` لازم تكون **strings** (شرط FCM).

### أين تُستدعى دالة الإرسال (hooks):
داخل ميثودات الـ workflow في `dh.visit` بعد نجاح الانتقال:
`action_submit`, `action_approve`, `action_reject`, `action_start_visit`,
`action_end_visit`, `action_cancel`, ميثودات المشارك `action_approve/action_reject`
على `dh.visit.participant`, وميثود الـ **escalation cron**. اعملوا helper واحد:
```python
def _notify(self, users, title, body, event):
    tokens = self.env['dh.visit.device.token'].search([('user_id','in',users.ids),('active','=',True)])
    for t in tokens:
        _send_fcm(t, title, body, {'type':'visit_event','event':event,
                                   'visit_id':str(self.id),'visit_ref':self.name or '','state':self.state})
```

---

## 6. (اختياري) endpoints للإشعارات — مش ضروري

التطبيق دلوقتي بيقرأ `mail.activity` مباشرة بـ `call_kw` (شغّال). لو تحبوا تغلّفوها
في REST بدل ما التطبيق يلمس الموديل مباشرة، ممكن (اختياري):
- `POST /api/visit/notifications` → قائمة أنشطة المستخدم.
- `POST /api/visit/notifications/count` → العدد.
- `POST /api/visit/notification/mark_done` `{activity_id}`.

مش مطلوبة — بس بتنضّف العقد لو حبيتوا.

---

## 7. مُلخّص المطلوب من الباك إند (Checklist)

- [ ] موديل `dh.visit.device.token`.
- [ ] `POST /api/visit/register_device` + `POST /api/visit/unregister_device`.
- [ ] دالة `_send_fcm` (FCM HTTP v1 + Service Account + refresh للـ OAuth token).
- [ ] استدعاء `_notify(...)` في كل ميثودات الـ workflow + الـ cron (جدول القسم 2).
- [ ] تنظيف التوكنات الميتة عند رد `UNREGISTERED` من FCM.
- [ ] (اختياري) endpoints الإشعارات في القسم 6.

---

## 8. المطلوب من العميل / منك (Client-side prerequisites)

عشان الـ push يشتغل، محتاجين الحاجات دي (مرة واحدة) — **وهي مسؤوليتك مع الباك إند**:

1. **مشروع Firebase** واحد للتطبيق (اسم الـ package: `net.digitalharbor.visits`).
2. **Android:** ملف `google-services.json` يتضاف في `android/app/`.
3. **iOS:**
   - `GoogleService-Info.plist` يتضاف في مشروع Xcode.
   - **APNs Auth Key (.p8)** من Apple Developer، يترفع في إعدادات Firebase Cloud Messaging.
   - تفعيل **Push Notifications** + **Background Modes → Remote notifications** في الـ capabilities.
4. **Service Account JSON** من Firebase (Project Settings → Service accounts) → يتسلّم
   **لفريق الباك إند** عشان يبعت منه (سرّي — مايتحطّش في الـ repo).
5. الموافقة على إضافة حزمتين للتطبيق: `firebase_messaging` + `flutter_local_notifications`
   (لعرض الإشعار والتطبيق في foreground).

> بعد ما توفّر (1)–(4)، أنا بظبّط الجزء بتاع التطبيق: أضيف الحزمتين، آخد التوكن من
> `firebase_messaging`، أبعته لـ `/api/visit/register_device` بعد اللوجين، وأعمل
> deep-link من الإشعار لشاشة الزيارة (`data.visit_id`). كل ده جاهز أعمله بمجرد ما
> بيانات Firebase تكون متاحة.

---

## 9. اللي التطبيق (Flutter) وفّره — ✅ مُنفّذ

الجزء بتاع التطبيق **اتعمل بالكامل** (build ناجح على أندرويد). الكود:

- **`lib/core/push/push_notification_service.dart`** — كل دورة حياة الـ FCM:
  الأذونات، الـ foreground banner (عبر `flutter_local_notifications` على channel
  `visit_events`)، جلب الـ token، وتحويل الضغط على الإشعار لـ `visit_id`.
- **`lib/core/push/push_repository.dart`** — بيكلّم `/api/visit/register_device`
  و `/api/visit/unregister_device`.
- **`lib/app/app.dart`** — بيسجّل الـ token بعد كل authenticate (لوجين أو استئناف
  جلسة)، بيمسحه *قبل* تدمير الجلسة عند اللوجاوت، وبيعمل deep-link لـ
  `/visits/<visit_id>` عند الضغط على الإشعار (foreground / background / cold-launch).
- **`lib/main.dart`** — `Firebase.initializeApp` + تسجيل الـ background handler.

السلوك:
- يجيب FCM token ويبعته عبر `/api/visit/register_device` بعد كل لوجين + عند تغيّر التوكن.
- يمسحه عبر `/api/visit/unregister_device` عند تسجيل الخروج.
- يستقبل الـ `data` payload، ويفتح `/visits/<visit_id>` عند الضغط على الإشعار.
- foreground: يعرض إشعار محلي عبر `flutter_local_notifications`.
- background/terminated: النظام يعرض `notification` تلقائيًا.

### إعدادات Firebase الفعلية (للباك إند)

| Key | Value |
|---|---|
| `PROJECT_ID` | `visits-app1` |
| `project_number` (FCM sender) | `1029698829865` |
| Android package | `net.digitalharbor.visits` (+ `net.digitalharbor.visits.debug` لبناء الـ debug) |
| iOS bundle | `net.digitalharbor.visits` |
| Endpoint الإرسال | `https://fcm.googleapis.com/v1/projects/visits-app1/messages:send` |

> **ملاحظة عن الـ debug build:** بياخد لاحقة `.debug`. عشان الـ Gradle plugin
> يعدّي من غير تسجيل تطبيق تاني في Firebase، فيه ملف
> `android/app/src/debug/google-services.json` بنفس بيانات المشروع بالـ package
> المسبوق بـ `.debug`. الـ runtime بياخد إعداداته من `lib/firebase_options.dart`
> (مش من google-services.json)، فالإشعارات بتشتغل على نفس المشروع عادي.

### الناقص لسه (مسؤولية خارج الكود):
- **iOS:** رفع **APNs Auth Key (.p8)** في Firebase → Cloud Messaging، وتفعيل
  **Push Notifications** + **Background Modes → Remote notifications** في Xcode.
- **الباك إند:** **Service Account JSON** من Firebase عشان يبعت عبر FCM HTTP v1
  (القسم 5) + تنفيذ الـ endpoints والموديل (القسم 7).
```
