# الناقص فقط: إرسال FCM من الباك إند (Backend TODO)

> **الخلاصة:** كل حاجة شغّالة **ما عدا خطوة إرسال الـ push نفسها**. التطبيق بيسجّل
> التوكن صح، والباك إند بيخزّنه وبيعمل الإشعار الداخلي (`mail.activity`) — بس **مفيش
> إرسال FCM فعلي**. ده الملف بيركّز على الجزء ده بس.

---

## 1. إثبات إن ده بالظبط الناقص (اختبار حيّ 2026-07-13)

اتعمل submit لزيارة كـ `sam@test.com` (تابع لـ `mona@test.com`)، والنتيجة:

| الخطوة | الحالة |
|---|---|
| التطبيق يجيب FCM token ويبعته `/api/visit/register_device` | ✅ رجّع 200 |
| تخزين التوكن في `dh.visit.device.token` | ✅ موجود (توكن Mona، active) |
| إنشاء `mail.activity` "Approve visit …" للمدير | ✅ اتعمل |
| **وصول push للموبايل** | ❌ **صفر** (لا رسالة FCM ولا إشعار بعد أكتر من دقيقتين) |

فحص قاعدة البيانات (قراءة فقط) أكّد السبب:

```
ir.config_parameter (fcm/firebase/push/service_account)  →  فاضي
service-account JSON attachment                          →  فاضي
server logs (fcm/firebase/push)                          →  فاضي
```

**يعني: مفيش Service Account ولا أي إعداد FCM على السيرفر → دالة الإرسال مش بتشتغل.**

---

## 2. المطلوب عمله (3 خطوات)

### الخطوة 1 — Service Account من نفس مشروع التطبيق

- من Firebase Console → مشروع **`visits-app1`** (⚠️ لازم نفس المشروع، sender/`project_number` = **`1029698829865`**) → **Project Settings → Service accounts → Generate new private key** → ملف JSON.
- **مهم جدًا:** لو استخدمت Service Account من مشروع Firebase تاني، الإرسال هيروح في الفراغ (التوكنات مسجّلة على `visits-app1` بس).
- خزّنه كـ system parameter (سرّي — مايتحطّش في الـ git):

  `Settings → Technical → System Parameters`
  - **Key:** `dh_visit.fcm_service_account`
  - **Value:** محتوى ملف الـ JSON كامل.

### الخطوة 2 — دالة الإرسال (FCM HTTP v1)

> تحتاج `google-auth` (`pip install google-auth`). `requests` موجودة في Odoo.

ضيفها على موديل `dh.visit` (أو helper mixin):

```python
import json
import logging
import requests
from google.oauth2 import service_account
import google.auth.transport.requests

_logger = logging.getLogger(__name__)

FCM_PROJECT_ID = 'visits-app1'
FCM_ENDPOINT   = 'https://fcm.googleapis.com/v1/projects/%s/messages:send' % FCM_PROJECT_ID
FCM_SCOPE      = 'https://www.googleapis.com/auth/firebase.messaging'


def _fcm_access_token(self):
    """OAuth2 access token من الـ Service Account (يتجدّد كل مرة/يتكاش لو حبيت)."""
    sa_json = self.env['ir.config_parameter'].sudo().get_param('dh_visit.fcm_service_account')
    if not sa_json:
        _logger.warning('FCM: dh_visit.fcm_service_account not set — push disabled')
        return None
    creds = service_account.Credentials.from_service_account_info(
        json.loads(sa_json), scopes=[FCM_SCOPE])
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token


def _send_fcm(self, token_rec, title, body, data):
    access_token = self._fcm_access_token()
    if not access_token:
        return
    message = {
        'message': {
            'token': token_rec.token,
            'notification': {'title': title, 'body': body},
            # ⚠️ كل قيم data لازم تكون strings — والتطبيق بيعتمد على data.visit_id
            'data': {k: str(v) for k, v in data.items()},
            'android': {'priority': 'high'},
            'apns': {'headers': {'apns-priority': '10'},
                     'payload': {'aps': {'sound': 'default'}}},
        }
    }
    try:
        resp = requests.post(
            FCM_ENDPOINT,
            headers={'Authorization': 'Bearer %s' % access_token,
                     'Content-Type': 'application/json'},
            data=json.dumps(message), timeout=10)
    except Exception as e:
        _logger.warning('FCM: request failed: %s', e)
        return
    if resp.status_code == 200:
        _logger.info('FCM: sent to user %s', token_rec.user_id.id)
        return
    # تنظيف التوكنات الميتة
    try:
        status = resp.json().get('error', {}).get('status')
    except Exception:
        status = None
    if status in ('UNREGISTERED', 'NOT_FOUND', 'INVALID_ARGUMENT'):
        token_rec.sudo().active = False
    _logger.warning('FCM: send failed %s → %s', resp.status_code, resp.text)
```

### الخطوة 3 — استدعِ `_notify` بعد كل حدث في الـ workflow

```python
def _notify(self, users, title, body, event):
    """يبعت push لكل توكنات المستخدمين المستهدفين."""
    if not users:
        return
    tokens = self.env['dh.visit.device.token'].sudo().search([
        ('user_id', 'in', users.ids), ('active', '=', True)])
    for t in tokens:
        self._send_fcm(t, title, body, {
            'type': 'visit_event',
            'event': event,
            'visit_id': str(self.id),         # ⚠️ إلزامي — التطبيق بيفتح /visits/<visit_id>
            'visit_ref': self.name or '',
            'state': self.state,
        })
```

نفس الأماكن اللي بتعمل فيها `mail.activity` دلوقتي، ضيف جنبها `_notify(...)`. أهم واحد
للاختبار (submit → المدير المباشر):

```python
def action_submit(self):
    res = super().action_submit()   # أو منطقك الحالي
    manager = self.direct_manager_id.user_id
    self._notify(
        manager,
        'New visit to approve',
        '%s: %s awaits your approval' % (self.employee_id.name, self.name),
        'submitted',
    )
    return res
```

باقي الأحداث والمستلمين (approve/reject/reschedule/escalation/…) في جدول
[BACKEND_PUSH_NOTIFICATIONS.md](BACKEND_PUSH_NOTIFICATIONS.md) القسم 2.

> **ملاحظة أداء:** غلّف `_notify` في try/except (زي فوق) عشان فشل الإرسال ماياثّرش على
> الـ workflow. لو عندك `queue_job`، الأفضل `self.with_delay()._notify(...)`.

---

## 3. اختبار سريع للتأكد (curl)

بعد ضبط الـ Service Account، جرّب الإرسال مباشرة لتوكن Mona (الموبايل لازم يجيله إشعار):

```bash
# 1) هات access token من الـ service account (أو استخدم أي أداة توليد OAuth2)
ACCESS_TOKEN="<oauth2 token from the service account>"

curl -s -X POST \
  "https://fcm.googleapis.com/v1/projects/visits-app1/messages:send" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "eAbog0wwTB6ux8GlP7h6EN:APA91bE75nLDgt183wxj_TZyI_RvfolpbPPY6iwIajNYGsXlU2EcnaFCPYUeh6TS-owR-E1yG0h4ziHO0x3bUkdfT6PLoVvhnc-myIT98aQ4-x8UebR9DYg",
      "notification": { "title": "Test", "body": "Push works ✅" },
      "data": { "type": "visit_event", "visit_id": "51", "state": "submitted" },
      "android": { "priority": "high" }
    }
  }'
```

- **رد 200** = FCM شغّال، يبقى فضل بس نداء `_notify` من الـ workflow.
- **رد 403/404 SenderId mismatch / project error** = الـ Service Account من مشروع غلط
  (مش `visits-app1`).

---

## 4. Checklist

- [ ] Service Account JSON من مشروع **`visits-app1`** متخزّن في system parameter `dh_visit.fcm_service_account`.
- [ ] `google-auth` متثبّتة على السيرفر.
- [ ] دالة `_fcm_access_token` + `_send_fcm` + `_notify` مضافة.
- [ ] `_notify(...)` بتتنادى في `action_submit` (وباقي أحداث الـ workflow).
- [ ] اختبار الـ curl رجّع 200 والموبايل جاله الإشعار.
