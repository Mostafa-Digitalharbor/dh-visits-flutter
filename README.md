# Customer Visits — location_gps

تطبيق فلاتر لموظفي المبيعات الميدانيين عشان يعملوا **Check-in / Check-out** عند العملاء مع تتبّع الموقع لايف أثناء استخدام التطبيق، وللمديرين عشان يتابعوا فريقهم على الخريطة. الباك إند Odoo 19 (موديول `dh_customer_visits`).

- **اللغات:** عربي (افتراضي) + إنجليزي.
- **الثيم:** Light / Dark / System.
- **المنصات المدعومة للنشر:** Android (Google Play) + iOS (App Store). الكود نفسه يبني على Web/Windows/macOS/Linux للتطوير لكن مش هندف لنشرهم.
- **Package / Bundle ID:** `net.digitalharbor.visits` (الاتنين Android و iOS).
- **حالة الـ Backend URL:** متعرّف وقت البناء عن طريق `--dart-define` (مش hardcoded). شوف [الاتصال بالباك إند](#الاتصال-بالباك-إند).

---

## فهرس

- [نظرة سريعة على الميزات](#نظرة-سريعة-على-الميزات)

- [الـ Tech Stack](#الـ-tech-stack)

- [بنية المشروع (Architecture)](#بنية-المشروع-architecture)

- [تقسيم الفايلات](#تقسيم-الفايلات)

- [طريقة التشغيل](#طريقة-التشغيل)

- [الاتصال بالباك إند](#الاتصال-بالباك-إند)

- [الترجمة والـ Localization](#الترجمة-والـ-localization)

- [الصلاحيات والخصوصية](#الصلاحيات-والخصوصية)

- [بناء النسخة النهائية للنشر](#بناء-النسخة-النهائية-للنشر)

---

## نظرة سريعة على الميزات

| الميزة | الوصف |
|---|---|
| تسجيل الدخول | عبر Odoo session cookie (`/web/session/authenticate`) — مع زرّ تبديل اللغة والثيم في شاشة اللوجين. |
| قائمة العملاء | بحث + بدّل بين الـ list والـ map، وفلترة العملاء اللي معاهم إحداثيات بس. |
| Check-in / Check-out | يلتقط موقع GPS فعلي ويرسل للسيرفر ويتحقق من المسافة من مقر العميل. |
| Persistent Visit Bar | شريط ثابت أسفل الشاشة بيعرض الزيارة المفتوحة الحالية + الزمن الجاري. |
| لايف لوكيشن (foreground-only) | إرسال موقع الموظف كل 30 ثانية أثناء استخدام التطبيق + heartbeat كل دقيقتين + فلتر مسافة 5م لتوفير البطارية. **يتوقّف تلقائياً لما التطبيق يدخل background**. |
| Nearby Employees (للمديرين) | يجيب كل الموظفين على بُعد 10م من مقر عميل معيّن، يحدّث كل 10ث. |
| سجل الزيارات | تاريخ زيارات الموظف + فلاتر بالتاريخ/الحالة. |
| Dashboard (للمديرين) | KPIs عامة + خريطة فيها الموظفين النشطين دلوقتي. |
| الإعدادات | تبديل اللغة / الثيم + Logout. |
| التحكم في الصلاحيات | يفرّق بين **User** (موظف عادي يشوف زياراته بس) و **Manager** (يشوف العملاء والموظفين كلهم). |
| Offline queue | لو الـ check-in/out اتعمل بدون نت يتخزّن محلياً ويتبعت تلقائياً لما النت يرجع. |

---

## الـ Tech Stack

- **Framework:** Flutter (Dart SDK `^3.9.2`)
- **State management:** [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) (Bloc + Cubit) + `equatable`
- **Networking:** [`dio`](https://pub.dev/packages/dio) + `dio_cookie_manager` + `cookie_jar` (لحفظ جلسة Odoo)
- **DI:** [`get_it`](https://pub.dev/packages/get_it) — الـ service locator في [lib/core/di/service_locator.dart](lib/core/di/service_locator.dart)
- **Routing:** [`go_router`](https://pub.dev/packages/go_router) — راوتر مركزي مع redirect على حسب حالة الـ auth
- **Storage:** `shared_preferences` (للإعدادات) + `flutter_secure_storage` (للـ session) + `cookie_jar` persistent
- **Location:** `geolocator` + `permission_handler` — *foreground-only* (لا `ACCESS_BACKGROUND_LOCATION` ولا `UIBackgroundModes`)
- **Maps:** `flutter_map` + `latlong2` (OpenStreetMap tiles، مش Google)
- **i18n:** Flutter gen-l10n من `.arb` files
- **UI:** Material 3 — Theme مبني على ألوان الشركة (Digital Harbor navy `#1E2A6E` + cyan `#3FBFD9`)
- **App icons + splash:** `flutter_launcher_icons` + `flutter_native_splash` (Android 12+ splash API support)

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
- الـ `LiveLocationBloc` بيستخدم `WidgetsBindingObserver` فيوقّف الـ ticker لما التطبيق يدخل background ويرجّع يشغّله لما يرجع للـ foreground — ده يطابق تصريح الخصوصية بإننا foreground-only.

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
│   │   ├── constants.dart           # intervals + thresholds + getters للـ env
│   │   ├── config/
│   │   │   └── app_environment.dart # baseUrl/database من --dart-define
│   │   ├── api/
│   │   │   ├── api_client.dart      # Dio + cookie + onUnauthorized stream
│   │   │   ├── api_exceptions.dart  # ApiException + ApiErrorCode enum
│   │   │   ├── endpoints.dart       # URLs ثابتة لكل endpoint
│   │   │   └── pretty_log_interceptor.dart   # log JSON في debug mode
│   │   ├── di/
│   │   │   └── service_locator.dart # GetIt setup — singletons + repos
│   │   ├── location/
│   │   │   └── location_service.dart # geolocator wrapper + permission flow
│   │   ├── network/
│   │   │   └── pending_actions_queue.dart # offline check-in/out queue
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
│   │   ├── auth/                    # AuthBloc + LoginPage + SplashPage
│   │   ├── customers/               # CustomersBloc + list/detail/map
│   │   ├── employees/               # EmployeesBloc (للمدير)
│   │   ├── dashboard/               # KPIs + active-employees map
│   │   ├── home/                    # _UserShell / _ManagerShell
│   │   ├── live_location/           # ticker + lifecycle observer
│   │   ├── nearby/                  # NearbyBloc polling 10ث
│   │   ├── settings/                # ثيم/لغة/logout
│   │   └── visits/                  # VisitBloc + create/list/detail + bar
│   │
│   ├── shared/                      # widgets/extensions reusable
│   │   ├── extensions/
│   │   │   └── context_extensions.dart  # context.s / colors / text / showSnack
│   │   └── widgets/                 # AppButton, AppCard, AppTextField, ...
│   │
│   └── l10n/
│       ├── app_ar.arb               # الترجمات العربية
│       ├── app_en.arb               # الترجمات الإنجليزية
│       └── generated/               # gen-l10n output — مولّد تلقائي
│
├── assets/
│   └── images/
│       └── logo.jpg                 # شعار الشركة (مصدر الـ launcher icons)
│
├── docs/
│   ├── README.md                    # توثيق الـ Backend API كامل
│   ├── BACKEND_OPEN_ASKS.md         # أسئلة معلّقة للباك إند
│   ├── RELEASE.md                   # دليل البناء والنشر على Play / App Store
│   ├── PRIVACY_POLICY.md            # سياسة الخصوصية (Markdown)
│   └── PRIVACY_POLICY.docx          # نفس السياسة كملف Word جاهز للموقع
│
├── scripts/
│   └── build_privacy_policy_docx.ps1  # يبني الـ .docx من OOXML+ZIP مباشرة
│
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # compileSdk 36 + signing + R8 + ProGuard
│   │   ├── proguard-rules.pro       # R8 keep-rules لـ Flutter/secure_storage
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # permissions + foreground-only location
│   │       ├── kotlin/net/digitalharbor/visits/MainActivity.kt
│   │       └── res/
│   │           ├── values/strings.xml        # app_name = "Customer Visits"
│   │           ├── values-ar/strings.xml     # app_name = "زيارات العملاء"
│   │           └── xml/data_extraction_rules.xml  # منع نقل الـ session
│   ├── key.properties.template      # قالب release signing keystore
│   └── ...
│
├── ios/
│   └── Runner/
│       ├── Info.plist               # WhenInUse location + HTTPS-only + no bg modes
│       ├── en.lproj/InfoPlist.strings  # permission strings — English
│       └── ar.lproj/InfoPlist.strings  # permission strings — Arabic
│
├── .env.example                     # قالب للـ --dart-define-from-file
├── test/widget_test.dart
├── pubspec.yaml                     # deps + assets + launcher icons + splash
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

# 4. شغّل التطبيق على الإعدادات الافتراضية (تبيوس dev/trial)
flutter run

# 5. أو شغّله على instance بعينه عن طريق --dart-define
flutter run \
  --dart-define=API_BASE_URL=https://your-odoo-instance.com \
  --dart-define=ODOO_DATABASE=your_db_name

# 6. أو من ملف .env (انسخ .env.example الأول)
flutter run --dart-define-from-file=.env.dev
```

### إيقونة التطبيق و splash

بعد تغيير `assets/images/logo.jpg` شغّل:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
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

### إعداد عنوان الـ Backend

الـ `baseUrl` و `database` بقوا **مش hardcoded**. بيتقروا وقت البناء عن طريق `--dart-define`:

| متغير | الوصف |
|---|---|
| `API_BASE_URL` | عنوان الـ Odoo instance (بدون trailing slash) |
| `ODOO_DATABASE` | اسم الـ Odoo database |
| `APP_FLAVOR` | `dev` / `staging` / `production` — للعرض في الإعدادات |

القيم الافتراضية (لو مفيش `--dart-define`) في [lib/core/config/app_environment.dart](lib/core/config/app_environment.dart) بتشاور على الـ dev/trial instance علشان البناء المحلي يشتغل من أول مرة. **متعتمدش عليها في build للإنتاج** — لازم تمرّر القيم الإنتاجية صراحةً.

---

## الترجمة والـ Localization

- الترجمات المصدر في [lib/l10n/app_ar.arb](lib/l10n/app_ar.arb) و [lib/l10n/app_en.arb](lib/l10n/app_en.arb).
- استخدامها في الكود عن طريق extension موحّد: `context.s.someKey` (مُعرَّفة في [lib/shared/extensions/context_extensions.dart](lib/shared/extensions/context_extensions.dart)).
- اللغة الافتراضية: عربي (`SettingsState.defaultLocale = Locale('ar')`).
- المستخدم يقدر يبدّل بين العربي/الإنجليزي من شاشة Settings أو من زرّ على شاشة Login.
- اسم التطبيق نفسه متلوكلَيز:
  - Android: `values/strings.xml` (EN) + `values-ar/strings.xml` (AR).
  - iOS: `en.lproj/InfoPlist.strings` + `ar.lproj/InfoPlist.strings`.

أي مفتاح جديد لازم يتضاف في الـ `.arb` files الاتنين، وبعدين `flutter gen-l10n` يولّد الـ Dart class.

---

## الصلاحيات والخصوصية

التطبيق بيطلب أقل عدد ممكن من الصلاحيات:

| الصلاحية | Android | iOS | السبب |
|---|---|---|---|
| Precise location (foreground) | `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` | check-in/out + لايف لوكيشن أثناء استخدام التطبيق |
| Internet | `INTERNET` + `ACCESS_NETWORK_STATE` | (تلقائي) | API + كشف الـ offline |

**التطبيق مش بيطلب:**
- ❌ Background location — اللايف لوكيشن يقف لما التطبيق يبق في background
- ❌ Foreground service — مش محتاجه طول ما مفيش background tracking
- ❌ Camera / Mic / Contacts / Calendar / SMS / Files

الـ Privacy Policy الكاملة في [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) (و نسخة Word في [docs/PRIVACY_POLICY.docx](docs/PRIVACY_POLICY.docx) جاهزة للرفع على موقع الشركة).

---

## بناء النسخة النهائية للنشر

الدليل الكامل في [docs/RELEASE.md](docs/RELEASE.md). الخطوط العريضة:

```bash
# Android — Google Play (AAB)
flutter build appbundle --release \
  --dart-define-from-file=.env.production \
  --obfuscate --split-debug-info=build/symbols/android

# iOS — App Store (IPA)
flutter build ipa --release \
  --dart-define-from-file=.env.production \
  --obfuscate --split-debug-info=build/symbols/ios
```

قبل أول رفع للستورات:

1. اعمل keystore لـ Android: `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. انسخ `android/key.properties.template` لـ `android/key.properties` وحط فيه القيم.
3. انسخ `.env.example` لـ `.env.production` وحط فيه `API_BASE_URL` و `ODOO_DATABASE` الإنتاجية.
4. ارفع `docs/PRIVACY_POLICY.docx` على موقع الشركة وحط الرابط في Play Console و App Store Connect.
5. اتبع الـ checklist في [docs/RELEASE.md](docs/RELEASE.md).
