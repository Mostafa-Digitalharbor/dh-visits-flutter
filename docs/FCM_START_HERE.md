# الإشعارات — الباج كلمة واحدة في الكود

## الخلاصة في سطرين

الحقل `fcm_service_account_json` معرّف **`fields.Text`** مع **`config_parameter=`**.
**Odoo مايدعمش `Text` مع `config_parameter`** → **صفحة Settings بترمي Exception أول ما تفتحها**
→ مستحيل تحفظ الـ Service Account → دالة الإرسال بتلاقيه فاضي وبتخرج بصمت → مفيش إشعارات.

**كودك سليم.** المشكلة كلمة `Text` بس.

---

## 1️⃣ اتأكد بنفسك (٥ ثواني في Odoo shell)

```python
env['res.config.settings'].default_get(['fcm_service_account_json'])
```

**النتيجة الحالية:**

```
NotImplementedError: Field res.config.settings.fcm_service_account_json
must have type 'boolean', 'integer', 'float', 'char', 'selection', 'many2one' or 'datetime'
```

`Text` مش في اللستة. وده معناه إن **صفحة Visit Management في الإعدادات مابتفتحش أصلاً**.

---

## 2️⃣ الحل — غيّر كلمة واحدة

```python
# قبل ❌
fcm_service_account_json = fields.Text(config_parameter='...')

# بعد ✅
fcm_service_account_json = fields.Char(config_parameter='...')
```

**سيب `config_parameter` زي ما هو بالظبط** — نفس المفتاح، ونفس دالة الإرسال، مفيش أي حاجة تانية تتغير.
(`fields.Char` في Odoo من غير حد أقصى للطول، فالـ JSON هيتحفظ كامل.)

ثم: **Upgrade للموديول**.

> **بديل أنضف لو عايز خانة إدخال كبيرة:** سيب `fields.Text` بس **شيل `config_parameter`**
> واعمل `get_values()` / `set_values()` يقروا ويكتبوا بـ `ir.config_parameter` على **نفس المفتاح**.
> الطريقتين شغالين — الأولى أسرع وأأمن.

---

## 3️⃣ بعد الـ Upgrade

**أ)** Settings → **Visit Management** → **Push Notifications** → الزق الـ JSON كامل في
**Firebase Service Account JSON** → **Save**.

الملف من: Firebase Console → مشروع **`visits-app1`** → Project Settings → Service accounts →
**Generate new private key**.

**ب)** اتأكد إنه اتحفظ فعلاً:

```python
env['ir.config_parameter'].sudo().search([('key', 'ilike', 'fcm')]).mapped('key')
```

لازم يرجّع المفتاح بتاعك. **لو رجّع `[]` يبقى الحفظ لسه مش شغال** — قوللنا.

---

## ⚡ لو عايز تتأكد إن الباقي كله شغال قبل ما تعدّل الكود

تقدر تحقن القيمة يدويًا من الـ shell وتجرّب فورًا من غير أي تعديل.

**الأول اعرف اسم المفتاح اللي كودك بيقرا منه:**

```python
print(env['res.config.settings']._fields['fcm_service_account_json'].config_parameter)
```

**بعدين احقن الـ JSON على نفس المفتاح:**

```python
env['ir.config_parameter'].sudo().set_param('<المفتاح اللي طلع فوق>', open('/path/service-account.json').read())
env.cr.commit()
```

بعدها جرّب أي submit/approve — لو الإشعار وصل يبقى **كل كودك تمام** والباقي مجرد إصلاح الحقل
عشان الواجهة تشتغل. إحنا جاهزين نجرب من عندنا في نفس اللحظة.

---

## ⚠️ نقطة مهمة: المفتاح اللي في ملفاتنا القديمة كان **غلط**

الملفات اللي بعتناهالك قبل كده كانت بتقول `dh_visit.fcm_service_account` — **ده كان تخمين مننا،
اتجاهله**. المفتاح الحقيقي هو اللي مكتوب في `config_parameter=` في كودك إنت.

لو كنت جرّبت تضيف باراميتر بالاسم بتاعنا، فده مايشتغلش لأن دالة الإرسال بتقرا من مفتاح تاني.
(فحصنا: مفيش أي باراميتر فيه كلمة `fcm` على الداتابيز حاليًا.)

---

## ⚠️ وحاجة أخيرة لما توصل لمرحلة الإرسال

الرسالة لازم يكون فيها **البلوكين مع بعض**:

```json
"notification": { "title": "...", "body": "..." },
"data":         { "visit_id": "42" }
```

**ماتبعتش `data` لوحده** — في الخلفية نظام الأندرويد هو اللي بيعرض بلوك `notification`؛
لو مش موجود، الإشعار **مش هيظهر** حتى لو الإرسال رجّع `200`. ده هيوفّر عليك جولة تانية.

---

## ليه إنت شايف إن كل حاجة تمام؟

عشان **كل باقي الأجزاء فعلاً تمام** — دي نتايج اختبار عملناه النهاردة (١٨ يوليو) بنفسنا:

| الحلقة | النتيجة |
|---|---|
| تسجيل التوكن `register_device` | ✅ شغال — التوكن اتحدّث على صف Sam (upsert بالـ `device_id` مظبوط) |
| التوكنات على الداتابيز | ✅ ٣ توكنات نشطة مستنية |
| الـ workflow hook | ✅ شغال — submit لـ `VIS/2026/00072` عمل `mail.activity` رقم 174 لمونا |
| إرسال FCM | ❌ **صفر** — شغّلنا submit + approve + reject وسجّلنا ١١٧٣ سطر من الموبايل: مفيش أي رسالة FCM وصلت |
| الجهاز نفسه | ✅ سليم — الصلاحية ممنوحة، قناة `visit_events` شغالة، وإشعار تجريبي محلي ظهر |

**الحتة الواقعة الوحيدة** هي إن دالة الإرسال بتلاقي الـ Service Account فاضي فبتخرج **بصمت**:
مفيش error، مفيش لوج، ومفيش أي حاجة تلفت نظرك. وده بالظبط سبب إن كل حاجة تبان تمام من عندك.

والسبب إنه فاضي هو باج الـ `Text` اللي فوق 🙏
