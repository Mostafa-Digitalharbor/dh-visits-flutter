# Backend TODO — إثبات بالأدلة إن الشغل لسه **مش مكتمل** (المحاولة الرابعة)

**التاريخ:** 2026-07-15 · **الخادم:** `https://thedigitalharbor-dh-visits-new.odoo.com`
**قاعدة البيانات:** `thedigitalharbor-dh-visits-new-main-34241330`
**الموديول:** `dh_visit_management` — `19.0.2.0.0` (آخر تعديل `2026-07-14 14:30:51`)

---

## اقرأ ده الأول — ليه بنبعت نفس الملف للمرة الرابعة

اتقال لنا **3 مرات** إن الشغل خلص. **مخلصش.** الملف ده مش رأي ولا انطباع — كل نقطة تحتها
**أمر تقدر تنسخه وتجربه بنفسك** والنتيجة اللي طلعت معانا بالظبط.

**أهم نقطة، وياريت تتقرأ بتركيز:**

> تحديث كود الموديول **لوحده مش كفاية**. أهم بند (الإشعارات) محتاج **قيمة إعداد على قاعدة
> البيانات** (System Parameter). لو الكود اتظبط والـ Service Account **مش متسجّل**، الدالة
> بترجع `None` و **الإرسال بيتوقف بصمت من غير أي رسالة خطأ** — يعني الشغل "يبان" إنه تمام
> في الكود، والإشعارات **مش بتوصل ولا واحد**. ده بالظبط اللي حاصل دلوقتي.

**"خلصت" معناها إيه في الملف ده:** إن **سكربت التحقق** في آخر الملف يطلع **PASS** على كل
البنود. لو مطلعش PASS، يبقى لسه مخلصش. من فضلك **ابعتلنا مخرجات السكربت** مع ردّك بدل
كلمة "تم".

---

## ملخص الحالة (اتقاس النهاردة 2026-07-15)

| # | المشكلة | الخطورة | الحالة |
|---|---|---|---|
| 1أ | Service Account بتاع FCM **مش متسجّل** → مفيش أي إشعار بيوصل | 🔴 قاتلة | ❌ مفتوحة |
| 1ب | لازم شكل الرسالة يكون `notification` **+** `data` (مش data-only) — **فخّ هيكسرها حتى بعد إصلاح 1أ** (قسم 1.4) | 🔴 قاتلة | ⚠️ للتنبيه |
| 2 | `/api/visit/my` بيفلتر بـ `create_uid` مش `employee_id` → الموظف **مش بيشوف زيارات مديره** | 🔴 قاتلة | ❌ مفتوحة |
| 3 | `/api/visit/my` مش بيرجّع `latitude`/`longitude` → تبويب "مسار اليوم" **فاضي دايمًا** | 🟠 عالية | ❌ مفتوحة |
| 4 | زيارات الفرص مستحيلة (مفيش صلاحية `crm.lead`، و`/api/visit/opportunities` = 404) | 🟠 عالية | ❌ مفتوحة |
| 5 | `/api/visit/create` **بيتجاهل الحقول المجهولة بصمت** → بيانات بتضيع من غير خطأ | 🟡 متوسطة | ❌ مفتوحة |
| 6 | توكنات قديمة فاضلة `active` | ⚪ منخفضة | ℹ️ **هتتحل لوحدها مع رقم 1** |

---

# 🔴 المشكلة 1 — الإشعارات: الـ Service Account مش متسجّل

## 1.1 الدليل القاطع

### دليل (أ) — البارامتر مش موجود أصلاً

عدّينا **كل** الـ 28 بارامتر على قاعدة البيانات. **مفيش ولا مفتاح** فيه `fcm` أو `firebase` أو `push`:

```python
# نفّذ ده بنفسك في Odoo shell:
params = env['ir.config_parameter'].sudo().search([])
print('TOTAL:', len(params))                      # -> 28
for p in params:
    if any(k in p.key.lower() for k in ('fcm', 'firebase', 'push', 'service_account')):
        print('FOUND:', p.key)
# النتيجة عندنا: مفيش ولا سطر اتطبع. صفر نتائج.

print(env['ir.config_parameter'].sudo().get_param('dh_visit.fcm_service_account'))
# النتيجة عندنا: False   ← ده سبب المشكلة كلها
```

ومفيش كمان أي attachment للـ service account:

```python
env['ir.attachment'].sudo().search_count([('name', 'ilike', 'service')])   # -> 0
env['ir.attachment'].sudo().search_count([('name', 'ilike', 'firebase')])  # -> 0
```

### دليل (ب) — الـ workflow شغّال، الإرسال بس هو اللي مش شغّال

عملنا submit لزيارة حقيقية من التطبيق (`VIS/2026/00056`, من Sam لمديرته Mona):

| الخطوة | النتيجة |
|---|---|
| تسجيل توكن الجهاز (Mona + Sam) | ✅ اتسجّل (`dh.visit.device.token` فيه صفوف `active`) |
| `action_submit` اشتغلت | ✅ الحالة بقت `submitted` |
| `mail.activity` اتعملت | ✅ `"Approve visit VIS/2026/00056"` لـ Mona |
| **وصول الـ push للموبايل** | ❌ **صفر** |

> يعني الـ hooks بتتنفّذ. المشكلة **مش** في الـ workflow — المشكلة إن `_send_fcm` بترجع
> بدري لأن مفيش Service Account.

### دليل (ج) — قِسناها على الموبايل نفسه (مش تخمين)

اختبرنا على **الدورين** (مدير + موظف) على جهاز حقيقي:

```
# 1) مدير: Sam يعمل submit  →  المفروض إشعار لـ Mona (جهازها متسجّل ومفتوح)
adb logcat | grep -i "FirebaseMessaging\|FCM"     -> صفر سطور
adb shell dumpsys notification | grep NotificationRecord.*net.digitalharbor.visits  -> 0
شريط الإشعارات على الموبايل: "No notifications"

# 2) موظف: Mona تعمل approve لزيارة Sam  →  المفروض إشعار لـ Sam (توكنه id=6 active)
adb logcat | grep -i "FirebaseMessaging\|FCM"     -> صفر سطور
adb shell dumpsys notification | grep NotificationRecord.*net.digitalharbor.visits  -> 0
```

**الخلاصة: مفيش أي إشعار بيوصل لأي دور. ولا واحد.**

### دليل (هـ) — أعدنا الاختبار يوم 2026-07-16 وأثبتنا إن الجهاز **قادر يستقبل** (عشان نستبعد إن العيب في الموبايل)

قبل ما نقول "مفيش إشعار"، تأكدنا إن جهاز الاختبار سليم تمامًا:

| فحص على الجهاز | النتيجة |
|---|---|
| Google Play Services متثبّتة | ✅ نسخة `26.19.34` |
| صلاحية `POST_NOTIFICATIONS` | ✅ `granted=true` |
| Firebase بتتهيّأ جوّه التطبيق | ✅ `FirebaseApp initialization successful` + `FLTFireMsgService started` (من اللوج) |
| التطبيق بياخد توكن FCM صالح من Google | ✅ `[push] token registered` + التوكن اتخزّن على السيرفر (`id=8`, `last_seen=2026-07-16`) |
| شريط الإشعارات نفسه شغّال | ✅ بعتنا إشعار تجريبي بـ `cmd notification post` وظهر فورًا |

ثم شغّلنا **3 أحداث workflow حقيقية** (Sam يعمل submit → Mona؛ Mona توافق → Sam؛ Mona ترفض → Sam)
مع **تسجيل لوج متواصل 90 ثانية** والتطبيق في الخلفية:

```
# النتيجة من ملف اللوج (410 سطر خلال النافذة 10:36:25 → 10:37:49):
grep -iE "FirebaseMessaging|onMessageReceived|c2dm|GcmReceiver" capture.log   -> صفر
grep -iE "NotificationRecord.*digitalharbor"                    capture.log   -> صفر
# شريط الإشعارات دلوقتي: 3 إشعارات، كلهم pkg=com.android.shell (اختباراتنا)، ولا واحد من التطبيق.
```

**يعني: الجهاز يستقبل، والتوكن صالح، والأحداث اتنفّذت — ومفيش أي رسالة FCM خرجت من السيرفر أصلاً.
المشكلة على السيرفر 100%، مش في الموبايل ولا في التطبيق.**

### دليل (د) — التطبيق سليم 100% (عشان منلفّش ونضيّع وقت)

| بند العميل | الحالة |
|---|---|
| قناة الأندرويد `visit_events` (importance=4 HIGH) | ✅ متسجّلة — متأكدين من `dumpsys notification` |
| `POST /api/visit/register_device` بعد كل تسجيل دخول | ✅ رجّع 200 |
| توكنات فعلية مخزّنة في `dh.visit.device.token` | ✅ (Sam id=6 active، Mona id=1,2 active) |
| `unregister_device` عند الخروج | ✅ بيعمل التوكن `active=False` |
| `device_id` ثابت بيتبعت مع كل تسجيل | ✅ بيتبعت (شوف المشكلة 6) |
| التعامل مع `onTokenRefresh` | ✅ متعمول |

**مفيش أي حاجة ناقصة في التطبيق.** كل المطلوب على السيرفر.

## 1.2 الحل — 3 خطوات (مفيش رابعة)

### الخطوة 1 — سجّل الـ Service Account ⚠️ **دي الخطوة اللي اتنسيت 3 مرات**

1. افتح **Firebase Console** → مشروع **`visits-app1`**
   ⚠️ **لازم نفس المشروع بالظبط**. الـ `project_number` لازم يكون **`1029698829865`**.
   لو استخدمت Service Account من مشروع تاني، الإرسال هيرجّع خطأ `SenderId mismatch`
   والتوكنات المسجّلة عندنا كلها على `visits-app1` بس.
2. **Project Settings → Service accounts → Generate new private key** → هينزّل ملف JSON.
3. سجّله كـ System Parameter:
   - **Settings → Technical → Parameters → System Parameters → New**
   - **Key:** `dh_visit.fcm_service_account`
   - **Value:** **محتوى ملف الـ JSON كامل** (من `{` لـ `}`) — مش مسار الملف، ومش جزء منه.

أو بالكود:

```python
env['ir.config_parameter'].sudo().set_param(
    'dh_visit.fcm_service_account',
    r'''{ ...الصق محتوى الـ JSON كامل هنا... }''')
```

**اتأكد إنه اتسجّل صح:**

```python
import json
raw = env['ir.config_parameter'].sudo().get_param('dh_visit.fcm_service_account')
assert raw, '❌ لسه مش متسجّل'
j = json.loads(raw)
print('project_id =', j['project_id'])      # لازم يطلع: visits-app1
print('client_email =', j['client_email'])
print('type =', j['type'])                   # لازم يطلع: service_account
```

### الخطوة 2 — اتأكد إن `google-auth` متثبّتة

```bash
pip install google-auth
python -c "import google.oauth2.service_account; print('OK')"
```

> على Odoo.sh: ضيف `google-auth` في `requirements.txt` بتاع الـ repo واعمل redeploy.
> لو المكتبة مش متثبّتة، الـ `import` هيقع و`_send_fcm` **هترمي استثناء متبلعّ** = برضو مفيش إشعارات.

### الخطوة 3 — الكود (لو مش موجود بالظبط كده)

```python
import json, logging, requests
from google.oauth2 import service_account
import google.auth.transport.requests

_logger = logging.getLogger(__name__)
FCM_PROJECT_ID = 'visits-app1'
FCM_ENDPOINT = 'https://fcm.googleapis.com/v1/projects/%s/messages:send' % FCM_PROJECT_ID
FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'


def _fcm_access_token(self):
    sa_json = self.env['ir.config_parameter'].sudo().get_param('dh_visit.fcm_service_account')
    if not sa_json:
        # ⚠️ ده بالظبط اللي بيحصل دلوقتي — بيخرج من غير ما يبعت أي حاجة
        _logger.warning('FCM: dh_visit.fcm_service_account NOT SET — push disabled')
        return None
    creds = service_account.Credentials.from_service_account_info(
        json.loads(sa_json), scopes=[FCM_SCOPE])
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token


def _send_fcm(self, token_rec, title, body, data):
    access_token = self._fcm_access_token()
    if not access_token:
        return
    message = {'message': {
        'token': token_rec.token,
        'notification': {'title': title, 'body': body},
        # ⚠️ كل قيم data لازم تكون strings — والتطبيق بيعتمد على data.visit_id
        'data': {k: str(v) for k, v in data.items()},
        'android': {'priority': 'high'},
        'apns': {'headers': {'apns-priority': '10'},
                 'payload': {'aps': {'sound': 'default'}}},
    }}
    try:
        resp = requests.post(FCM_ENDPOINT, headers={
            'Authorization': 'Bearer %s' % access_token,
            'Content-Type': 'application/json',
        }, data=json.dumps(message), timeout=10)
    except Exception as e:
        _logger.warning('FCM: request failed: %s', e)
        return
    if resp.status_code == 200:
        _logger.info('FCM: sent to user %s', token_rec.user_id.id)
        return
    try:
        status = resp.json().get('error', {}).get('status')
    except Exception:
        status = None
    if status in ('UNREGISTERED', 'NOT_FOUND', 'INVALID_ARGUMENT'):
        token_rec.sudo().active = False     # نضّف التوكنات الميتة
    _logger.warning('FCM: send failed %s → %s', resp.status_code, resp.text)


def _notify(self, users, title, body, event):
    if not users:
        return
    tokens = self.env['dh.visit.device.token'].sudo().search([
        ('user_id', 'in', users.ids), ('active', '=', True)])
    for t in tokens:
        self._send_fcm(t, title, body, {
            'type': 'visit_event',
            'event': event,
            'visit_id': str(self.id),     # ⚠️ إلزامي — التطبيق بيفتح /visits/<visit_id>
            'visit_ref': self.name or '',
            'state': self.state,
        })
```

ونادِ `_notify` **جنب كل مكان بيعمل `mail.activity` دلوقتي**:

```python
def action_submit(self):
    res = super().action_submit()
    self._notify(self.direct_manager_id.user_id,
                 'New visit to approve',
                 '%s: %s awaits your approval' % (self.employee_id.name, self.name),
                 'submitted')
    return res

def action_approve(self):
    res = super().action_approve()
    self._notify(self.employee_id.user_id,
                 'Visit approved',
                 '%s was approved' % self.name, 'approved')
    return res

def action_reject(self):   # وكمان reschedule / escalation ...
    res = super().action_reject()
    self._notify(self.employee_id.user_id,
                 'Visit rejected',
                 '%s was rejected' % self.name, 'rejected')
    return res
```

## 1.3 اختبار مباشر تقدر تعمله دلوقتي (من غير التطبيق)

```python
# نفّذ ده في Odoo shell — لازم يوصل إشعار على موبايل Sam فعليًا
tok = env['dh.visit.device.token'].sudo().search([('active','=',True)], limit=1)
print('sending to:', tok.user_id.name)
visit = env['dh.visit'].sudo().search([], limit=1)
visit._send_fcm(tok, 'اختبار', 'الإشعارات اشتغلت ✅', {'type':'visit_event','visit_id':visit.id})
```

- **الموبايل جاله إشعار** = تمام ✅
- **مفيش + في اللوج `dh_visit.fcm_service_account NOT SET`** = الخطوة 1 لسه ناقصة
- **رجّع 403 / SenderId mismatch** = الـ Service Account من مشروع **غلط** (مش `visits-app1`)

## 1.4 ⚠️ فخّ تاني هيوقعكم حتى بعد ما تظبطوا الـ Service Account — شكل الحمولة (Payload)

> **اقروا ده كويس — دي غالبًا هي "الحاجة التانية" اللي بتخلّي الشغل يبان تمام والإشعار مايوصلش.**
> ممكن تظبطوا الـ Service Account، والإرسال يرجّع **200 OK**، وبرضو **مفيش إشعار يظهر** في الخلفية.
> السبب: **شكل الرسالة**.

**القاعدة (إلزامية):** كل رسالة FCM لازم تبعتوا فيها **بلوك `notification` (فيه `title` و `body`)
+ بلوك `data`** — **مع بعض**. **ممنوع** ترسلوا `data` لوحده (data-only).

**ليه:**

| حالة التطبيق | مين اللي بيعرض الإشعار | لو مفيش `notification` block |
|---|---|---|
| الخلفية / مقفول (background/terminated) | **نظام أندرويد بنفسه** بيعرض بلوك `notification` تلقائيًا | ❌ **مفيش إشعار يظهر خالص** |
| مفتوح قدّامك (foreground) | التطبيق بيعرضه بنفسه | بيحاول يعرض من `data.title/body` لو موجودين، وإلا مفيش |

يعني لو بعتّوا **data-only**، هيشتغل بس والتطبيق مفتوح، وفي الخلفية (اللي هو 99% من الوقت
الحقيقي) **مايظهرش** — وده بالظبط نفس عرض المشكلة اللي بنحاول نحلها، فتفتكروا إنها لسه مش شغّالة.

**الشكل الصح بالظبط (انسخوه زي ما هو):**

```json
{
  "message": {
    "token": "<device-token>",
    "notification": {                      // ⬅️ إلزامي — من غيره مفيش إشعار في الخلفية
      "title": "Visit approved",
      "body":  "Your visit VIS/2026/00042 was approved"
    },
    "data": {                              // ⬅️ إلزامي كمان — التطبيق بيفتح الزيارة منه
      "type": "visit_event",
      "event": "approved",
      "visit_id": "42",                    // ⬅️ لازم موجود (string) — التطبيق بيفتح /visits/42
      "visit_ref": "VIS/2026/00042",
      "state": "approved"
    },
    "android": { "priority": "high" },
    "apns": { "headers": { "apns-priority": "10" }, "payload": { "aps": { "sound": "default" } } }
  }
}
```

**شروط لازم تتأكدوا منها:**
- بلوك `notification` **موجود** فيه `title` و `body` (نص للمستخدم).
- بلوك `data` **موجود** وكل قيمه **strings** (شرط FCM — حتى `visit_id` لازم `"42"` مش `42`).
- `data.visit_id` **موجود دايمًا** — التطبيق بيستخدمه يفتح شاشة الزيارة عند الضغط.
- `android.priority = "high"` عشان يوصل فورًا حتى والجهاز في وضع توفير الطاقة.

> **ملاحظة:** دالة `_send_fcm` في قسم 1.2 بتعمل الشكل ده صح بالفعل. المهم **ماتغيّروهاش**
> لـ data-only، وأي مثال قديم كان بيقول "data-only مُوصى به" هو **غلط** واتصحّح.

---

# 🔴 المشكلة 2 — `/api/visit/my` بيفلتر بالمُنشئ مش بالموظف

**الأثر:** **الموظف مش بيشوف الزيارات اللي مديره خطّطها له.** ودي وظيفة أساسية في التطبيق كله —
المدير يخطّط زيارة لمندوب، والمندوب **عمره ما هيشوفها**.

## 2.1 الدليل بالأرقام (Sam Sales, employee_id=6)

```python
# 1) الحقيقة: كل الزيارات اللي Sam هو الموظف بتاعها
env['dh.visit'].sudo().search_count([('employee_id','=',6)])
# -> 45

# 2) اللي الـ endpoint بيرجّعه لـ Sam (بنفس الجلسة بتاعته)
#    POST /api/visit/my  {"domain":[], "limit":200, "offset":0}
# -> 43   ← ناقص 2
```

الاتنين الناقصين **بالظبط**:

| الزيارة | الحالة | `employee_id` | `create_uid` | في `/my`؟ |
|---|---|---|---|---|
| `VIS/2026/00055` | `done` | Sam Sales | **Mona Manager** | ❌ **مختفية** |
| `VIS/2026/00057` | `draft` | Sam Sales | **Mona Manager** | ❌ **مختفية** |

## 2.2 استبعدنا كل التفسيرات التانية

- **مش فلتر حالة (state):** الاتنين الناقصين في حالتين مختلفتين تمامًا (`done` و `draft`).
- **مش فلتر مسودات:** Sam عنده **11 مسودة من عملها بنفسه** — وبتظهر **كلها 11/11**.
- **مفيش زيارات زيادة:** الـ endpoint مرجّعش ولا زيارة مش بتاعة Sam (0 extra).
- **القاسم المشترك الوحيد بين المختفيتين:** `create_uid = Mona` (100%).

> **الاستنتاج قاطع: الفلتر شغّال على `create_uid` (المُنشئ) مش على `employee_id` (الموظف).**

## 2.3 الحل

في الـ controller بتاع `/api/visit/my` — الـ domain المفروض يكون على الموظف مش المُنشئ:

```python
# ❌ الغلط الحالي (أو ما يعادله)
domain = [('create_uid', '=', request.env.user.id)]

# ✅ الصح
employee = request.env.user.employee_id
domain = [('employee_id', '=', employee.id)]

# ✅ أحسن: يشمل كمان الزيارات اللي هو مشارك فيها
domain = ['|', ('employee_id', '=', employee.id),
               ('participant_ids.employee_id', '=', employee.id)]
```

## 2.4 التحقق بعد الإصلاح

```python
# لازم الرقمين يتساووا
n_truth = env['dh.visit'].sudo().search_count([('employee_id','=',6)])
# و POST /api/visit/my كـ sam@test.com لازم يرجّع نفس العدد (45)
# ولازم VIS/2026/00055 و VIS/2026/00057 يبقوا موجودين فيه
```

---

# 🟠 المشكلة 3 — `/api/visit/my` مش بيرجّع الإحداثيات

**الأثر:** تبويب **"مسار اليوم"** (خريطة مسار المندوب + ترتيب المحطات + المسافة) **فاضي على طول**
لكل المناديب. التطبيق بيحتاج `latitude`/`longitude` عشان يرسم المحطات، ومش بيلاقيهم.

## 3.1 الدليل

الحقول اللي `/api/visit/my` بيرجّعها فعليًا (نسخناها من الرد الحقيقي):

```
id, name, visit_type, project_id, opportunity_id, partner_id, partner_name,
employee_id, employee_name, scheduled_datetime, purpose, location, state,
visit_approval_state, attendee_approval_state, outcome, start_datetime, end_datetime
```

- `latitude` → ❌ **مش موجود**
- `longitude` → ❌ **مش موجود**

مع إن الحقلين **موجودين على الموديل** (`dh.visit.latitude` و `dh.visit.longitude` — نوع `float`).
يعني مجرد إضافتهم لقائمة الحقول في الـ serializer.

## 3.2 الحل

```python
# في الـ serializer بتاع /api/visit/my — ضيف السطرين دول:
'latitude': v.latitude or 0.0,
'longitude': v.longitude or 0.0,
```

---

# 🟠 المشكلة 4 — زيارات الفرص (Opportunity) مستحيلة

## 4.1 الدليل

```python
# كـ sam@test.com (عضو مجموعة Visit User, group id=41):
env['crm.lead'].search_read([], ['id','name'], limit=3)
# ❌ odoo.exceptions.AccessError:
#    "You are not allowed to access 'Lead' (crm.lead) records."
```

```
POST /api/visit/opportunities   →   HTTP 404 (صفحة HTML، الـ route مش موجود أصلاً)
```

**النتيجة:** المستخدم يختار "فرصة" في شاشة إنشاء زيارة → التطبيق يقع في خطأ صلاحيات.
"مشروع" شغّال تمام (`project.project` مقروء).

## 4.2 الحل — اختار واحد وبلّغنا بيه

**(أ) endpoint مخصص (الأفضل)** — نفس أسلوب باقي الـ API:

```python
@http.route('/api/visit/opportunities', type='json', auth='user')
def opportunities(self, **kw):
    leads = request.env['crm.lead'].sudo().search(
        [('type', '=', 'opportunity')], limit=200)
    return {'opportunities': [
        {'id': l.id, 'name': l.display_name,
         'partner_id': l.partner_id.id, 'partner_name': l.partner_id.name}
        for l in leads]}
```

**(ب) صلاحية قراءة:** ادِّي `group_visit_user` صلاحية read على `crm.lead` (ir.model.access + record rule).

**(ج) قرار منتج:** لو الفرص مش مطلوبة أصلاً — قول لنا وإحنا **نخفي الاختيار من التطبيق**.

---

# 🟡 المشكلة 5 — `create` بيتجاهل الحقول المجهولة بصمت

## 5.1 الدليل

بعتنا `visit_date` (اسم غلط — الصح `scheduled_datetime`):

```
POST /api/visit/create
{"vals": {"project_id": 3, "visit_date": "2026-07-20 10:00:00", "purpose": "test"}}

→ 200 OK، الزيارة **اتعملت**… بس **من غير أي تاريخ**. مفيش خطأ. مفيش تحذير.
```

**ليه دي مشكلة:** أي غلطة إملائية في اسم حقل من أي عميل (موبايل/تكامل) = **بيانات بتضيع في صمت**
والزيارة بتتخزن ناقصة. ده بيخلّي أخطاء الإنتاج شبه مستحيلة الاكتشاف.

## 5.2 الحل

```python
ALLOWED_CREATE_FIELDS = {
    'project_id', 'opportunity_id', 'partner_id', 'employee_id',
    'scheduled_datetime', 'purpose', 'location', 'latitude', 'longitude',
    'visit_type', 'participant_ids',
}

def create_visit(self, vals, **kw):
    unknown = set(vals) - ALLOWED_CREATE_FIELDS
    if unknown:
        return {'status': 'error',
                'message': 'Unknown field(s): %s' % ', '.join(sorted(unknown))}
    ...
```

---

# 🟡 المشكلة 6 — توكنات قديمة فاضلة `active` للأبد (أولوية منخفضة)

> **ملاحظة أمانة:** البند ده **هيتحل لوحده** أول ما المشكلة 1 تتظبط (شوف 6.3). حطّيناه
> للعلم بس، مش مطلوب شغل منفصل. وسجّلناه هنا عشان منقولش حاجة غير دقيقة.

## 6.1 الملاحظة (بيانات حقيقية النهاردة)

```python
env['dh.visit.device.token'].sudo().with_context(active_test=False).search_read(
    [], ['id','user_id','active','device_id','last_seen'])
```

| id | user | active | device_id | last_seen |
|---|---|---|---|---|
| 1 | Mona Manager | **True** | `4e3dd573…` | 2026-07-13 10:10 ← 🧟 بقاله 3 أيام |
| 2 | Mona Manager | **True** | `45078ea3…` | 2026-07-13 11:42 ← 🧟 بقاله 3 أيام |
| 8 | Sam Sales | True | `88ee0d95…` | 2026-07-16 07:26 ← ✅ الحالي |

**السبب:** التوكن مبيتلغّيش غير لما المستخدم يعمل logout **بنفس التوكن بالظبط**. لو التطبيق
اتمسح/اتعمله clear data، أو المستخدم عمره ما عمل logout، الصف بيفضل `active` للأبد.

**تصحيح مهم (كنا هنقول معلومة غلط):** الـ `device_id` **بيتبعت من التطبيق وبيتخزّن على
السيرفر فعلاً** (شايفينه في الجدول فوق). والصفوف القديمة بتاعة Mona **لكل واحد `device_id`
مختلف** — لأن التطبيق بيولّد واحد جديد بعد مسح بيانات التطبيق. يعني الـ dedupe بالـ`device_id`
**مكانش هيدمج الصفوف دي أصلاً**. المشكلة مش dedupe — المشكلة إن **مفيش حاجة بتنضّف
التوكنات الميتة**.

## 6.2 التأثير الحقيقي

محدود: FCM هيرجّع `UNREGISTERED` للتوكنات الميتة والإرسال ليها هيفشل بهدوء. يعني مجرد
صفوف زيادة + نداءات HTTP ضايعة — **مش بيمنع أي إشعار عن مستخدم شغّال**.

## 6.3 الحل — **موجود أصلاً في كود المشكلة 1**

الجزء ده في `_send_fcm` (قسم 1.2 خطوة 3) بينضّف نفسه أوتوماتيك:

```python
if status in ('UNREGISTERED', 'NOT_FOUND', 'INVALID_ARGUMENT'):
    token_rec.sudo().active = False     # ← ده بيحل المشكلة 6 لوحده
```

> عشان ده مش بيشتغل دلوقتي، لأن `_send_fcm` **عمرها ما بتوصل لمرحلة الإرسال** (مفيش
> Service Account). أول ما المشكلة 1 تتظبط، التوكنات الميتة هتتقفل لوحدها من أول محاولة إرسال.

**(اختياري)** حماية زيادة لو حابين — نفس الجهاز لما يجدّد توكنه:

```python
def register_device(self, token, platform, device_id=None, **kw):
    Token = request.env['dh.visit.device.token'].sudo()
    user = request.env.user
    if device_id:   # نفس المستخدم + نفس الجهاز = صف شغّال واحد بس
        Token.with_context(active_test=False).search([
            ('user_id', '=', user.id), ('device_id', '=', device_id),
            ('token', '!=', token),
        ]).write({'active': False})
    existing = Token.with_context(active_test=False).search([('token', '=', token)], limit=1)
    vals = {'user_id': user.id, 'token': token, 'platform': platform,
            'device_id': device_id, 'active': True, 'last_seen': fields.Datetime.now()}
    existing.write(vals) if existing else Token.create(vals)
    return {'status': 'ok'}
```

---

# ✅ سكربت التحقق النهائي — **ابعتلنا مخرجاته**

نفّذ ده في **Odoo shell** وابعت **الناتج كامل** بدل ما تقول "تم":

```python
import json
print('='*60)

# 1) FCM Service Account
raw = env['ir.config_parameter'].sudo().get_param('dh_visit.fcm_service_account')
if not raw:
    print('1) FCM SA .......... ❌ FAIL — البارامتر مش متسجّل')
else:
    j = json.loads(raw)
    ok = j.get('project_id') == 'visits-app1'
    print('1) FCM SA .......... %s project_id=%s' % ('✅ PASS' if ok else '❌ FAIL (مشروع غلط)', j.get('project_id')))

# 2) google-auth
try:
    import google.oauth2.service_account
    print('2) google-auth ..... ✅ PASS')
except ImportError:
    print('2) google-auth ..... ❌ FAIL — مش متثبّتة')

# 3) /my يفلتر بالموظف
sam = env['res.users'].search([('login','=','sam@test.com')], limit=1)
truth = env['dh.visit'].sudo().search_count([('employee_id','=',sam.employee_id.id)])
print('3) /my domain ...... زيارات Sam الحقيقية = %d  → قارنها بردّ /api/visit/my (لازم نفس الرقم)' % truth)

# 4) الإحداثيات في /my
print('4) coords in /my ... افتح POST /api/visit/my وشوف latitude/longitude موجودين ولا لأ')

# 5) الفرص
try:
    env['crm.lead'].with_user(sam).search_read([], ['id'], limit=1)
    print('5) opportunities ... ✅ PASS')
except Exception as e:
    print('5) opportunities ... ❌ FAIL — %s' % str(e)[:60])

# 6) dedupe التوكنات
T = env['dh.visit.device.token'].sudo().with_context(active_test=False)
dupes = {}
for t in T.search([('active','=',True)]):
    dupes.setdefault((t.user_id.id, t.device_id), []).append(t.id)
bad = {k: v for k, v in dupes.items() if len(v) > 1}
print('6) token dedupe .... %s %s' % ('✅ PASS' if not bad else '❌ FAIL — توكنات مكررة:', bad or ''))
print('='*60)
```

## اختبار القبول النهائي (لازم يعدّي بالكامل)

1. سجّل `dh_visit.fcm_service_account` من مشروع **`visits-app1`**.
2. نفّذ اختبار `_send_fcm` المباشر (قسم 1.3) → **الموبايل جاله إشعار فعلًا**.
3. تأكّد إن الرسالة اللي بتتبعت فيها بلوك `notification` **+** `data` (قسم 1.4) — **مش data-only**،
   وجرّب والتطبيق **في الخلفية** (مش مفتوح) عشان تتأكد إن الإشعار بيظهر في الخلفية.
4. Sam يعمل submit → **Mona موبايلها يرن**. Mona تعمل approve → **Sam موبايله يرن**.
5. `POST /api/visit/my` كـ `sam@test.com` → **45 زيارة** وفيهم `VIS/2026/00055` و `VIS/2026/00057`.
6. نفس الرد فيه `latitude` و `longitude`.
7. Sam يقدر يقرا الفرص (أو تبلّغنا نخفيها).
8. `create` بحقل غلط → **يرجّع خطأ** مش 200.
9. مفيش أكتر من توكن `active` لنفس (user, device_id).

**من فضلك ابعت مخرجات سكربت التحقق + نتيجة اختبار الـ push المباشر.** لو أي بند لسه ❌
قول لنا **إيه اللي واقف** بالظبط وإحنا نساعد — بس من فضلك **متقولش "تم"** والسكربت مطلعش
PASS، لأن ده حصل 3 مرات وضيّع علينا وقت كتير.

---

## ملحق — بيانات الاختبار

- **حسابات:** `sam@test.com` (مندوب) · `mona@test.com` (مديرة Sam و Carl) · `dora@test.com` (مديرة Mona) — كلهم باسورد `Test@12345`
- **الهيكل:** Sam(emp 6) → Mona(emp 5) → Dora(emp 4) · Carl(emp 7) → Mona
- **زيارات موجودة للاختبار:** Sam: 13 draft / 11 submitted / 6 approved / 3 in_progress / 11 done / 2 rejected / 3 cancelled · Carl: 3 draft / 2 submitted / 2 approved / 1 done
- **مشروع Firebase:** `visits-app1` · **sender / project_number:** `1029698829865`
