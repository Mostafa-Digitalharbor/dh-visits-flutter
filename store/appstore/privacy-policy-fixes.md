# تعديلات مطلوبة على صفحة سياسة الخصوصية

الصفحة: https://digitalharbor.com.sa/ar/visit-app

الصفحة جيدة في تغطية الموقع، لكنها تناقض إعلان App Privacy المنشور في App Store Connect
في ثلاث نقاط. المراجع لدى Apple يقارن الاثنين، والتناقض سبب رفض مباشر.

---

## 1. الصور — تناقض صريح (الأهم)

**السطر الحالي يقول إن التطبيق لا يجمع الصور:**

> The App does not collect: contact lists, **photos**, microphone audio, files outside its own sandbox

هذا غير صحيح. التطبيق يلتقط صور إثبات الزيارة ويرفعها إلى الخادم
([visit_action_bar.dart:112](../../lib/features/visits/view/visit_action_bar.dart#L112)
ثم `uploadAttachment`)، وقد أُعلن عن `Photos or Videos` في App Store Connect.

**التصحيح**: احذف كلمة `photos` من قائمة "does not collect"، وأضِف البند التالي.

الفارق المهم: التطبيق **لا يقرأ ألبوم صور الجهاز** — يلتقط من الكاميرا مباشرة فقط،
ويستخدم منتقي المستندات للمرفقات. الصياغة أدناه تحافظ على هذه الدقة.

**عربي:**

> **الصور والمرفقات**: عند تسجيل زيارة، يمكنك اختياريًا التقاط صورة بالكاميرا أو إرفاق
> ملف لإثبات الزيارة. الصور والملفات التي ترفعها تُخزَّن في نظام صاحب العمل مرتبطةً
> بسجل الزيارة. لا يصل التطبيق إلى ألبوم صور جهازك ولا يقرأ ملفاتك؛ لا يُرفع سوى ما
> تختاره أنت في كل مرة.

**English:**

> **Photos and attachments**: When recording a visit, you may optionally capture a photo
> with the camera or attach a file as proof of the visit. Photos and files you upload are
> stored in your employer's system against that visit record. The App does not access your
> device's photo library and does not read your files; only what you explicitly choose at
> the moment of upload is transmitted.

---

## 2. توكن الإشعارات — إغفال

السياسة تنفي جمع IMEI والمعرّفات الإعلانية (وهذا صحيح)، لكنها لا تذكر توكن FCM إطلاقًا،
بينما أُعلن عن `Device ID` في App Store Connect
([push_notification_service.dart:170](../../lib/core/push/push_notification_service.dart#L170)).

**عربي:**

> **معرّف الإشعارات**: يُنشئ التطبيق معرّفًا للإشعارات خاصًا بجهازك (رمز Firebase Cloud
> Messaging) ويحفظه في نظام صاحب العمل مرتبطًا بحسابك، ليتمكن النظام من تنبيهك عند إسناد
> زيارة إليك أو اعتمادها أو إعادتها. هذا المعرّف يخص التطبيق وحده، ولا يُستخدم في الإعلانات
> ولا يُشارَك مع أي جهة إعلانية.

**English:**

> **Push notification identifier**: The App generates a device-specific notification token
> (a Firebase Cloud Messaging token) and stores it in your employer's system against your
> account, so the system can alert you when a visit is assigned to you, approved, or
> returned. This identifier is specific to the App, is not used for advertising, and is not
> shared with any advertising network.

---

## 3. Sentry — طرف ثالث غير مُسمّى

السياسة تتحدث عن التشخيص بعبارات عامة. Apple تطلب تسمية الأطراف الثالثة التي تصلها
البيانات. الخبر الجيد أن `sendDefaultPii = false` في
[main.dart:32](../../lib/main.dart#L32) ولا يوجد استدعاء `Sentry.setUser` في أي مكان،
فالادّعاء بعدم الارتباط بالهوية صحيح فعلًا ويطابق ما أُعلن (`Crash Data` غير مرتبطة بالهوية).

**عربي:**

> **تقارير الأعطال والأداء**: عند حدوث خطأ في التطبيق، تُرسَل تقارير الأعطال وقياسات
> الأداء إلى Sentry، وهي خدمة خارجية لمراقبة الأخطاء، بغرض إصلاح المشكلات فقط. هذه التقارير
> مُهيّأة عمدًا لعدم إرفاق بيانات التعريف الشخصية — لا تتضمن اسمك ولا بريدك ولا موقعك ولا
> عنوان IP الخاص بك — ولا تُستخدم في التحليلات التسويقية ولا الإعلانات.

**English:**

> **Crash and performance reporting**: When an error occurs, crash reports and performance
> measurements are sent to Sentry, a third-party error-monitoring service, for the sole
> purpose of fixing defects. These reports are deliberately configured to exclude personally
> identifying information — they do not include your name, email, location, or IP address —
> and are not used for marketing analytics or advertising.

---

## بند مفيد يُستحسن إضافته

Apple وGoogle كلاهما يقدّر وجود بند صريح عن عدم التتبع، وهو صحيح هنا: لا توجد أي
حزمة إعلانات في المشروع.

> **لا تتبُّع إعلاني**: لا يشارك التطبيق أي بيانات مع وسطاء البيانات أو شبكات الإعلانات،
> ولا يدمج بياناتك مع بيانات من تطبيقات أو مواقع أخرى لأغراض إعلانية.

---

## بعد التعديل

لا حاجة لتغيير أي شيء في App Store Connect — إعلان App Privacy منشور وصحيح كما هو.
التعديل مطلوب على الموقع فقط، وقبل الضغط على "Add for Review".
