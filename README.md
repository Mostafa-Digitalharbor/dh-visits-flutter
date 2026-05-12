# Customer Visits — location_gps

تطبيق فلاتر لموظفي المبيعات الميدانيين عشان يعملوا **Check-in / Check-out** عند العملاء مع تتبّع المواقع لايف، وللمديرين عشان يتابعوا فريقهم على الخريطة. الباك إند Odoo 19 (موديول `dh_customer_visits`).

- **اللغات:** عربي (افتراضي) + إنجليزي.
- **الثيم:** Light / Dark / System.
- **المنصات:** Android · iOS · Web · Windows · macOS · Linux (الكود واحد).
- **التاريخ الحالي للنسخة التجريبية:** صلاحية الـ Odoo trial لحد `2026-06-07`.

---

## فهرس

- [نظرة سريعة على الميزات](#نظرة-سريعة-على-الميزات)
- [الـ Tech Stack](#الـ-tech-stack)
- [بنية المشروع (Architecture)](#بنية-المشروع-architecture)
- [تقسيم الفايلات](#تقسيم-الفايلات)
- [طريقة التشغيل](#طريقة-التشغيل)
- [الاتصال بالباك إند](#الاتصال-بالباك-إند)
- [الترجمة والـ Localization](#الترجمة-والـ-localization)

---

## نظرة سريعة على الميزات

| الميزة | الوصف |
|---|---|
| تسجيل الدخول | عبر Odoo session cookie (`/web/session/authenticate`) — مع زرّ تبديل اللغة والثيم في شاشة اللوجين. |
| قائمة العملاء | بحث + بدّل بين الـ list والـ map، وفلترة العملاء اللي معاهم إحداثيات بس. |
| Check-in / Check-out | يلتقط موقع GPS فعلي ويرسل للسيرفر ويتحقق من المسافة من مقر العميل. |
| Persistent Visit Bar | شريط ثابت أسفل الشاشة بيعرض الزيارة المفتوحة الحالية + الزمن الجاري. |
| لايف لوكيشن | إرسال موقع الموظف كل 30 ثانية (مع heartbeat كل دقيقتين) + فلتر مسافة 5م لتوفير البطارية. |
| Nearby Employees (للمديرين) | يجيب كل الموظفين على بُعد 10م من مقر عميل معيّن، يحدّث كل 10ث. |
| سجل الزيارات | تاريخ زيارات الموظف + فلاتر بالتاريخ/الحالة. |
| الإعدادات | تبديل اللغة / الثيم + Logout. |
| التحكم في الصلاحيات | يفرّق بين **User** (موظف عادي يشوف زياراته بس) و **Manager** (يشوف العملاء والموظفين كلهم). |

---

## الـ Tech Stack

- **Framework:** Flutter (Dart SDK `^3.9.2`)
- **State management:** [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) (Bloc + Cubit) + `equatable`
- **Networking:** [`dio`](https://pub.dev/packages/dio) + `dio_cookie_manager` + `cookie_jar` (لحفظ جلسة Odoo)
- **DI:** [`get_it`](https://pub.dev/packages/get_it) — الـ service locator في [lib/core/di/service_locator.dart](lib/core/di/service_locator.dart)
- **Routing:** [`go_router`](https://pub.dev/packages/go_router) — راوتر مركزي مع redirect على حسب حالة الـ auth
- **Storage:** `shared_preferences` (للإعدادات) + `flutter_secure_storage` (للـ session) + `cookie_jar` persistent
- **Location:** `geolocator` + `permission_handler`
- **Maps:** `flutter_map` + `latlong2` (OpenStreetMap tiles، مش Google)
- **i18n:** Flutter gen-l10n من `.arb` files
- **UI:** Material 3 — Theme مبني على ألوان الشركة (Digital Harbor navy `#1E2A6E` + cyan `#3FBFD9`)

---

## بنية المشروع (Architecture)

التنظيم **Feature-first** مع طبقات داخل كل Feature:

```
┌──────────────────────────────────────────────────────────────┐
│                    UI Layer  (Pages + Widgets)               │
│        لب التطبيق — listens لحالات الـ Bloc/Cubit            │
└──────────────────────────┬───────────────────────────────────┘
                           │ events / states
┌──────────────────────────▼───────────────────────────────────┐
│                   Bloc / Cubit Layer                         │
│      يخاطب الـ Repository ويصدر states مع equatable          │
└──────────────────────────┬───────────────────────────────────┘
                           │ async calls
┌──────────────────────────▼───────────────────────────────────┐
│                Repository / Data Layer                       │
│       يفك ويغلّف JSON + يستخدم ApiClient + يرمي ApiException │
└──────────────────────────┬───────────────────────────────────┘
                           │ HTTP / JSON-RPC
┌──────────────────────────▼───────────────────────────────────┐
│   Core: ApiClient · LocationService · SessionStorage · DI    │
└──────────────────────────────────────────────────────────────┘
```

- كل feature بيتركّب على نفس الشكل: `bloc/` للحالة، `data/` للريبو والموديلز، `view/` لشاشات الـ UI.
- الـ `ApiClient` بيقبض على 401/`AUTH_REQUIRED` ويبثّ Stream، التطبيق يلتقطه في [lib/app/app.dart](lib/app/app.dart) ويعمل `AuthLogoutRequested` تلقائي.
- الـ `GoRouter` بيراقب الـ `AuthBloc` ويعمل redirect: لو unauthenticated يروح `/login`، لو authenticated يروح `/home`.
- شاشة الـ Home بتفرّع على حسب الدور: `_UserShell` للموظف، `_ManagerShell` (Tabs) للمدير.

---

## تقسيم الفايلات

```
location_gps/
├── lib/
│   ├── main.dart                    # نقطة البداية — يهيئ tz + DI ثم runApp
│   │
│   ├── app/                         # كل اللي يخص الـ root widget والتنقّل
│   │   ├── app.dart                 # MaterialApp.router + MultiBlocProvider
│   │   ├── router.dart              # GoRouter + redirect حسب AuthStatus
│   │   ├── theme.dart               # AppTheme.light() / dark() — ألوان الشركة
│   │   └── transitions.dart         # fade/slide transitions موحّدة
│   │
│   ├── core/                        # أساسيات مشتركة بين الـ features
│   │   ├── constants.dart           # baseUrl + database name + intervals
│   │   ├── api/
│   │   │   ├── api_client.dart      # Dio + cookie + onUnauthorized stream
│   │   │   ├── api_exceptions.dart  # ApiException + ApiErrorCode enum
│   │   │   ├── endpoints.dart       # URLs ثابتة لكل endpoint
│   │   │   └── pretty_log_interceptor.dart   # log JSON في debug mode
│   │   ├── di/
│   │   │   └── service_locator.dart # GetIt setup — singletons + repos
│   │   ├── location/
│   │   │   └── location_service.dart # geolocator wrapper + permission flow
│   │   ├── settings/
│   │   │   ├── settings_cubit.dart  # ThemeMode + Locale state
│   │   │   └── settings_repository.dart # حفظ في SharedPreferences
│   │   ├── storage/
│   │   │   └── session_storage.dart # secure storage للسيشن
│   │   └── utils/
│   │       ├── communications.dart  # phone/email/url_launcher helpers
│   │       ├── distance.dart        # Haversine لحساب المسافة
│   │       └── user_time.dart       # تحويل أوقات Odoo UTC للـ user tz
│   │
│   ├── features/                    # كل ميزة جوّاها bloc/data/view
│   │   ├── auth/
│   │   │   ├── bloc/                # AuthBloc + events + states
│   │   │   ├── data/                # AuthRepository + User model
│   │   │   └── view/                # LoginPage + SplashPage
│   │   ├── customers/
│   │   │   ├── bloc/                # CustomersBloc — list + search + paging
│   │   │   ├── data/                # CustomersRepository + Customer model
│   │   │   └── view/                # customers_list_page + customer_detail
│   │   ├── employees/
│   │   │   ├── bloc/                # EmployeesBloc (للمدير)
│   │   │   ├── data/                # EmployeesRepository + Employee model
│   │   │   └── view/                # employees_list_page
│   │   ├── home/
│   │   │   └── view/
│   │   │       └── home_shell.dart  # يتفرّع _UserShell / _ManagerShell
│   │   ├── live_location/
│   │   │   ├── bloc/                # تايمر إرسال الموقع كل 30ث + heartbeat
│   │   │   └── data/                # LiveLocationRepository
│   │   ├── nearby/
│   │   │   ├── bloc/                # NearbyBloc — polling 10ث
│   │   │   ├── data/                # NearbyRepository + NearbyEmployee
│   │   │   └── view/                # nearby_map_page — flutter_map
│   │   ├── settings/
│   │   │   └── view/                # settings_page (ثيم/لغة/logout)
│   │   └── visits/
│   │       ├── bloc/                # VisitBloc + VisitsListBloc + CreateVisit
│   │       ├── data/                # VisitsRepository + Visit + VisitType
│   │       └── view/                # create/list/detail + persistent_visit_bar
│   │
│   ├── shared/                      # widgets/extensions reusable
│   │   ├── extensions/
│   │   │   └── context_extensions.dart  # context.s / colors / text / showSnack
│   │   └── widgets/
│   │       ├── widgets.dart         # barrel export
│   │       ├── app_button.dart      # FilledButton موحّد مع loading state
│   │       ├── app_card.dart
│   │       ├── app_text_field.dart  # input مع label + password toggle
│   │       ├── confirm_dialog.dart  # ConfirmDialog.show(...)
│   │       ├── empty_view.dart
│   │       ├── error_view.dart
│   │       ├── info_row.dart
│   │       ├── picker_bottom_sheet.dart
│   │       ├── skeleton.dart        # shimmer placeholders
│   │       └── visit_card.dart
│   │
│   └── l10n/
│       ├── app_ar.arb               # الترجمات العربية (المصدر)
│       ├── app_en.arb               # الترجمات الإنجليزية
│       └── generated/               # gen-l10n output — مولّد تلقائي
│
├── assets/
│   └── images/
│       └── logo.jpg                 # شعار الشركة
│
├── docs/
│   ├── README.md                    # توثيق الـ Backend API كامل
│   └── BACKEND_OPEN_ASKS.md         # أسئلة معلّقة للباك إند
│
├── android/ · ios/ · web/ · windows/ · macos/ · linux/
│                                    # platform-specific projects
│
├── test/
│   └── widget_test.dart
│
├── pubspec.yaml                     # deps + assets + launcher icons
├── l10n.yaml                        # إعدادات gen-l10n
├── analysis_options.yaml            # lint rules
└── README.md                        # الملف ده
```

---

## طريقة التشغيل

```bash
# 1. تأكد من نسخة فلاتر
flutter --version    # محتاج Dart SDK ^3.9.2

# 2. تنزيل الحزم
flutter pub get

# 3. توليد ملفات الترجمة (لو عدّلت في .arb)
flutter gen-l10n

# 4. شغّل التطبيق
flutter run                          # على الجهاز/المحاكي الافتراضي
flutter run -d chrome                # ويب
flutter run -d windows               # ويندوز
```

### بيانات الدخول التجريبية

موجودين في [docs/README.md §13](docs/README.md). الـ baseUrl والـ database name متعرّفين في [lib/core/constants.dart](lib/core/constants.dart):

```dart
baseUrl  = 'https://dh-abdelrahmanwael-odoo-19-test.odoo.com'
database = 'dh-abdelrahmanwael-odoo-19-test-pros-31943069'
```

### إيقونة التطبيق

بعد تغيير `assets/images/logo.jpg` شغّل:

```bash
dart run flutter_launcher_icons
```

---

## الاتصال بالباك إند

كل التفاصيل (endpoints, error envelope, data models, edge cases) موجودين في [docs/README.md](docs/README.md). الـ endpoints الرئيسية:

| الـ Endpoint | الوصف |
|---|---|
| `POST /web/session/authenticate` | تسجيل دخول Odoo |
| `GET  /api/customers` | قائمة العملاء + بحث |
| `GET  /api/customers/<id>` | تفاصيل العميل + آخر زيارة |
| `GET  /api/customers/<id>/nearby-employees` | موظفين قريبين (للمدير) |
| `POST /api/visits/check-in` · `check-out` | بداية ونهاية الزيارة |
| `GET  /api/visits` | سجل الزيارات (مع فلاتر) |
| `POST /api/employee/location` | تحديث موقع لايف |

الـ `ApiClient` بيتعامل تلقائيًا مع:
- إضافة الكوكي على كل request.
- تحويل أخطاء Odoo (JSON envelope) لـ `ApiException` مع `ApiErrorCode` enum.
- بثّ event عند أي 401 → AuthLogout تلقائي.

---

## الترجمة والـ Localization

- الترجمات المصدر في [lib/l10n/app_ar.arb](lib/l10n/app_ar.arb) و [lib/l10n/app_en.arb](lib/l10n/app_en.arb).
- استخدامها في الكود عن طريق extension موحّد: `context.s.someKey` (مُعرَّفة في [lib/shared/extensions/context_extensions.dart](lib/shared/extensions/context_extensions.dart)).
- اللغة الافتراضية: عربي (`SettingsState.defaultLocale = Locale('ar')`).
- المستخدم يقدر يبدّل بين العربي/الإنجليزي من شاشة Settings أو من زرّ على شاشة Login.

أي مفتاح جديد لازم يتضاف في الـ `.arb` files الاتنين، وبعدين `flutter gen-l10n` يولّد الـ Dart class.
