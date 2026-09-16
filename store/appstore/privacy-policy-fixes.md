# تعديلات مطلوبة على صفحة سياسة الخصوصية

الصفحة: https://digitalharbor.com.sa/ar/visit-app

> **الحالة (فُحصت 2026-09-14):** الصفحة المنشورة ما زالت النسخة القديمة — تقول
> "The App does not collect or transmit your location when it is in the background"
> و"No background tracking"، وتاريخ السريان ما زال نصًا مؤقتًا ("Replace with the date
> you publish this policy"). انشر مكانها النص الكامل من
> [docs/PRIVACY_POLICY.md](../../docs/PRIVACY_POLICY.md) (أو `PRIVACY_POLICY.html` /
> `PRIVACY_POLICY.docx`، آخر تحديث 16 سبتمبر 2026) **قبل** رفع أي build يسجّل مسار
> الزيارة في الخلفية، وإلا يتناقض مع التطبيق وإعلانات المتجرين.
>
> **تحديث 2026-09-16:** "يوم العمل" ومشاركة الموقع اللحظي ورادار "الموظفين القريبين"
> وانعكاس الحضور اتشالوا من التطبيق. أي نص عن "مسار يوم العمل" أو "Start/End work day"
> **ممنوع ينشر** — البند 0 تحت اتكتب من جديد على أساس الزيارات فقط.

الصفحة جيدة في تغطية الموقع، لكنها تناقض إعلان App Privacy المنشور في App Store Connect
في ثلاث نقاط. المراجع لدى Apple يقارن الاثنين، والتناقض سبب رفض مباشر.

---

## 0. الموقع في الخلفية أثناء الزيارة الجارية — تغيير جوهري (الأهم الآن)

الصفحة تقول إن التطبيق لا يتتبع الموقع في الخلفية. هذا لم يعد صحيحًا بالكامل: أثناء
الزيارة الجارية فقط — من تأكيد الخادم لبدء الزيارة حتى "إنهاء الزيارة" أو تسجيل
الخروج — يسجّل التطبيق مسار الزيارة في الخلفية ومع قفل الشاشة (Android: خدمة
foreground من نوع location مع إشعار ظاهر وبإذن "أثناء الاستخدام" فقط؛ iOS: وضع
الخلفية location مع مؤشر الموقع الأزرق). احذف أي عبارة "لا يوجد تتبع في الخلفية"
وأضِف ما يلي. النص الإنجليزي الكامل في
[docs/PRIVACY_POLICY.md](../../docs/PRIVACY_POLICY.md) (البندان 2.2 و4).

**عربي:**

> **موقع الزيارات ومسارها**: يستخدم التطبيق موقع جهازك لزيارات العملاء فقط. يسجّل
> موقعًا واحدًا عند الضغط على "بدء الزيارة" لزيارة معتمدة، وموقعًا واحدًا عند الضغط على
> "إنهاء الزيارة"، ومسار الزيارة أثناء تنفيذها. يبدأ تسجيل المسار بعد أن يؤكد خادم جهة
> عملك بدء الزيارة، ويستمر والتطبيق في الخلفية أو الشاشة مقفلة، ويتوقف فور الضغط على
> "إنهاء الزيارة" أو تسجيل الخروج. على Android يظهر إشعار "تتبع الزيارة نشط" طوال مدة
> التسجيل، وعلى iOS يظهر مؤشر الموقع الأزرق الخاص بالنظام. لا يُجمع أي موقع قبل بدء
> الزيارة أو بين الزيارات أو بعد إنهائها، ولا يُسجَّل مسار يوم العمل كاملًا، ولا تُشارَك
> مواقعك لحظيًا مع أحد. تشمل كل نقطة خط العرض وخط الطول ووقت التقاطها الفعلي والدقة
> والارتفاع والسرعة والاتجاه ومعرّفًا عشوائيًا خاصًا بهذا التثبيت. عند انقطاع الشبكة
> تُحفظ النقاط في مساحة التطبيق الخاصة على الجهاز وتُرفع لاحقًا بأوقاتها الأصلية —
> حتى بعد انتهاء الزيارة — ولا يقبل الخادم إلا النقاط الواقعة بين بدء الزيارة وإنهائها،
> ثم تُحذف من الجهاز بعد رفعها أو رفضها نهائيًا. لرسم مسار الزيارة على الطرق قد تُرسَل
> نقاط تلك الزيارة فقط (دون اسمك أو معرّفك أو معرّف الجهاز) إلى خدمة مطابقة طرق تديرها
> Digital Harbor على بنية تحتية تتحكم فيها (وليست خدمة توجيه عامة)؛ ولا تُغيَّر المواقع
> المسجّلة.

**English:**

> **Visit locations and routes**: The App uses your device's location only for customer
> visits. It records one position when you tap "Start Visit" on an approved visit, one
> when you tap "End Visit", and the route of the visit while it is in progress. Route
> recording starts once your employer's server confirms the start, continues while the
> App is in the background or the screen is locked, and stops as soon as you tap "End
> Visit" or sign out. On Android a "Visit tracking active" notification is shown for as
> long as recording runs; on iOS the system's blue location indicator is shown. No
> location is collected before a visit starts, between visits or after it ends; the App
> does not record a whole work day and does not share your live position with anyone.
> Each point contains latitude, longitude, the time it was actually taken, accuracy,
> altitude, speed, heading and a random identifier for this installation. Without a
> network, points are kept in the App's private storage and uploaded later — even after
> the visit ended — with their original times; the server accepts only points taken
> between the visit's start and end, and points are deleted from the device once uploaded
> or permanently refused. To draw a visit's route along roads, only that visit's points
> (without your name, ID or device ID) may be sent to a road-matching service operated by
> Digital Harbor on infrastructure it controls (never a public routing service); the
> recorded positions are not changed.

---

## 1. الصور — تناقض صريح

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
