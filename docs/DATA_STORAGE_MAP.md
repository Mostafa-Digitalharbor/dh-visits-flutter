# أين يُحفَظ كل جزء من التطبيق على الأودو (Data → Odoo model)

خريطة موثّقة ومتحقَّق منها حيًّا (2026-07-14) لكل كيان في التطبيق ونظيره على السيرفر.

| جزء التطبيق | موديل الأودو | طريقة الوصول | ملاحظات |
|---|---|---|---|
| **العملاء (Customers)** | `res.partner` | `call_kw` (search_read/read) | نعم — دي موديول **جهات الاتصال (Contacts)** القياسي. `is_company` بيفرّق **شركة** عن **فرد**. الإحداثيات في `partner_latitude`/`partner_longitude` (من base_geolocalize). العنوان في `contact_address`/`street`/`city`/`country_id`. **مفيش حقل `customer_rank`** لأن موديول sale مش متثبّت — التطبيق بيعتبر أي جهة اتصال ليها إحداثيات = عميل قابل للعرض على الخريطة. |
| **الفرص (Opportunities)** | `crm.lead` (بدومين `type='opportunity'`) | `call_kw` | موديول **CRM**. `dh.visit.opportunity_id` بيشاور عليه. ⚠️ مستخدمي الزيارات **ممنوعين** من قراءة `crm.lead` (ده سبب مشكلة "فرصة" في الإنشاء — راجع `docs/OPPORTUNITY_VISIT_ACCESS.md`). |
| **المشاريع (Projects)** | `project.project` | `call_kw` (id/name/partner_id) | موديول **Project** القياسي. `partner_id` بيملأ العميل تلقائيًا. `dh.visit.project_id` بيشاور عليه. |
| **الزيارات (Visits)** | `dh.visit` | **REST `/api/visit/*`** للأكشنز + `call_kw` للقراءات الغنية وقوائم المدير | موديول مخصّص **`dh_visit_management`** (workflow بـ 11 حالة). GPS البدء/الإنهاء + الأوقات + النتيجة كلها حقول على `dh.visit`. علاقات: `project_id`→project.project، `opportunity_id`→crm.lead، `partner_id`→res.partner، `employee_id`→hr.employee. |
| **المشاركون (Participants)** | `dh.visit.participant` | REST `/api/visit/add_participants` + `call_kw` للموافقة/الرفض | موديول مخصّص. كل مشارك مربوط بـ `employee_id`→hr.employee ومديره `manager_id`. |
| **المرفقات (Attachments)** | `ir.attachment` | REST `/api/visit/upload_attachment` + `call_kw` للقائمة/التحميل | التخزين القياسي للمرفقات، مربوط بالزيارة عبر `res_model='dh.visit'` + `res_id`. |
| **الحضور/تسجيل الدخول-الخروج (Attendance)** | `hr.attendance` | مسار أودو المدمج `/hr_attendance/systray_check_in_out` | انعكاس (mirror) اختياري لبدء/إنهاء الزيارة، بيسجّل GPS في `in_/out_latitude/longitude`. ⚠️ على قاعدة بيانات الاختبار الحالية **موديول hr_attendance مش متثبّت** فالاستدعاء بيرجّع 404 والانعكاس بيتجاهَل بصمت. |
| **الموظفون/المستخدمون (Employees/Users)** | `res.users` (+ `hr.employee` عبر `res.users.employee_id`) | `call_kw` | الدور بيتحدّد من `res.users.group_ids` مقابل مجموعات `dh_visit_management` (41–44). الـ pickers بتاخد `employee_id` (hr.employee) لأن endpoints المشاركين/المالك بتشتغل بيه. |
| **توكنات الإشعارات (Push tokens)** | `dh.visit.device.token` | REST `/api/visit/register_device` + `/unregister_device` | موديول مخصّص. بيخزّن `user_id/token/platform/device_id/active/last_seen`. (الإرسال الفعلي لسه ناقص على الباك إند — `docs/PUSH_MISSING_FCM_SEND.md`). |
| **الموقع اللحظي/التواجد (Live location)** | `calendar.event` | `call_kw` (search/write/create) | مفيش موديول مخصّص: كل موظف له حدث calendar.event واحد، وموقعه الحالي متخزّن كـ JSON (base64) جوّه وصف الحدث، بيتحدّث كل ping. المدير بيقرأ كل الأحداث لرادار "القريبين". |
| **مسار يوم العمل (Work-day route)** | `dh.work.session` + `dh.work.location` (موديول **`dh_workday_tracking`**) — وعلى سيرفر التجربة فقط: `x_dh_work_session` + `x_dh_work_location` (no-code) | REST `/api/workday/*` لو الموديول متثبّت، وإلا `call_kw` على موديلات `x_` | يوم عمل واحد نشط لكل موظف؛ النقاط append-only ومربوطة اختياريًا بـ `visit_id`. التطبيق بيكتشف الموجود تلقائيًا (`WorkdayRepository.backend`). على الجهاز: journal native (`files/workday_fixes.jsonl` على Android، `Application Support/workday/` على iOS) + طابور الرفع في SharedPreferences (`workday_points_v1`) + كاش خطوط مطابقة الطرق `route_match_v1/` (30 يوم، بيتمسح عند الخروج). راجع `docs/WORKDAY_TRACKING.md`. |
| **الإشعارات الداخلية/الأنشطة (Notifications)** | `mail.activity` | `call_kw` (search_read/search_count بدومين `res_model='dh.visit'`, `user_id=<current>`) | جرس الإشعارات + قائمتها = سحب (pull) من `mail.activity` القياسي. (الـ push الحقيقي مخطّط عبر FCM من التوكنات، لسه ناقص باك إند.) |

## خلاصة الأسئلة الثلاثة
1. **العملاء بيتحفظوا في موديول Contacts؟** ✅ **نعم** — `res.partner` (نفس موديول جهات الاتصال في الأودو).
2. **الفرص بتتحفظ فين؟** في **`crm.lead`** (موديول CRM) بالحقل `type='opportunity'`.
3. **المشاريع بتتحفظ فين؟** في **`project.project`** (موديول Project).
