# Customer Visits — location_gps

تطبيق فلاتر لموظفي المبيعات الميدانيين عشان يبدأوا وينهوا **زيارات العملاء** بالموقع (Start Visit / End Visit) ويتسجّل مسار الزيارة **أثناء تنفيذها بس**، وللمديرين عشان يراجعوا الزيارات ويعتمدوها. الباك إند Odoo 19 (موديول `dh_visit_management` — العقد في [docs/API.md](docs/API.md)).

> **2026-09-16:** يوم العمل (Start/End Work Day ومسار اليوم كامل)، واللايف لوكيشن، ورادار الموظفين القريبين، وانعكاس الحضور على `hr.attendance` **اتشالوا**. الموقع بيتجمع للزيارات بس — التصميم في [docs/VISIT_TRACKING.md](docs/VISIT_TRACKING.md).

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
| Start Visit / End Visit | يلتقط موقع GPS فعلي لحظة البدء ولحظة الإنهاء ويرسله مع `/api/visit/start` و`/api/visit/end` ويتحقق من المسافة من مقر العميل. |
| Persistent Visit Bar | شريط ثابت أسفل الشاشة بيعرض الزيارة المفتوحة الحالية + الزمن الجاري. |
| مسار الزيارة (أثناء الزيارة بس) | التسجيل بيبدأ بعد ما السيرفر يأكّد `in_progress` ويقف فورًا مع End Visit أو تسجيل الخروج، وبيكمل في الخلفية والشاشة مقفولة أثناء الزيارة بس (Android: foreground service من نوع location بإشعار "Visit tracking active"، iOS: `UIBackgroundModes=location`). النقاط بتتخزن على الجهاز وتترفع دفعات على `/api/visit/log_locations`، والرسم على الطرق (OSRM) اختياري. التفاصيل في [docs/VISIT_TRACKING.md](docs/VISIT_TRACKING.md). |
| سجل الزيارات | تاريخ زيارات الموظف + فلاتر بالتاريخ/الحالة. |
| Dashboard (للمديرين) | KPIs عامة + خريطة بالزيارات الجارية عند نقطة بدء كل زيارة. |
| الإعدادات | تبديل اللغة / الثيم + Logout. |
| التحكم في الصلاحيات | يفرّق بين **User** (موظف عادي يشوف زياراته بس) و **Manager** (يشوف العملاء والموظفين كلهم). |
| Offline queue | لو Start/End اتعمل بدون نت يتخزّن محلياً ويتبعت تلقائياً لما النت يرجع (التتبع مابيبدأش غير لما السيرفر يقبل الـ Start). |

---

## الـ Tech Stack

- **Framework:** Flutter (Dart SDK `^3.9.2`)
- **State management:** [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) (Bloc + Cubit) + `equatable`
- **Networking:** [`dio`](https://pub.dev/packages/dio) + `dio_cookie_manager` + `cookie_jar` (لحفظ جلسة Odoo)
- **DI:** [`get_it`](https://pub.dev/packages/get_it) — الـ service locator في [lib/core/di/service_locator.dart](lib/core/di/service_locator.dart)
- **Routing:** [`go_router`](https://pub.dev/packages/go_router) — راوتر مركزي مع redirect على حسب حالة الـ auth
- **Storage:** `shared_preferences` (للإعدادات) + `flutter_secure_storage` (للـ session) + `cookie_jar` persistent
- **Location:** `geolocator` + `permission_handler` لموقع Start/End والأذونات. مسار الزيارة native: `visittracking/VisitLocationService.kt` (foreground service، بدون `ACCESS_BACKGROUND_LOCATION`) و`VisitLocation.swift` (`UIBackgroundModes=location`)
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
- الموقع في الخلفية بيتجمع في حالة واحدة بس: زيارة جارية (`VisitTrailTracker` + الخدمة native). مفيش أي تتبّع قبل البدء أو بين الزيارات أو بعد الإنهاء، وإشعار الـ push عمره ما يبدأ تتبّع. ده معلن في سياسة الخصوصية.

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
│   │   ├── dashboard/               # KPIs + خريطة الزيارات الجارية
│   │   ├── home/                    # _UserShell / _ManagerShell
│   │   ├── settings/                # ثيم/لغة/logout
│   │   └── visits/                  # VisitBloc + create/list/detail + bar + VisitTrailTracker
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
│   ├── images/                      # أصول مضمّنة داخل التطبيق
│   │   ├── visit-logo.png           # اللوجو كامل (باللوحة الكحلي)
│   │   ├── visit-logo-mark.png      # الرمز بدون خلفية (للأسطح الفاتحة)
│   │   └── map-cairo.png            # خلفية شاشات الدخول
│   └── icon/                        # مصادر بناء فقط — غير مضمّنة في التطبيق
│       ├── visit-logo-master.png    # اللوجو الأصلي (مصدر كل المشتقات)
│       ├── visit-logo-foreground.png# واجهة الأيقونة التكيّفية + الـ splash
│       └── visit-logo-ios.png       # أيقونة iOS (بدون شفافية)
│
├── docs/
│   ├── API.md                       # عقد الـ Backend API الحالي (dh_visit_management)
│   ├── VISIT_TRACKING.md            # تصميم تتبّع الموقع أثناء الزيارة فقط
│   ├── README.md                    # مرجع قديم لـ API موديول dh_customer_visits (legacy)
│   ├── BACKEND_OPEN_ASKS.md         # أسئلة معلّقة للباك إند
│   ├── RELEASE.md                   # دليل البناء والنشر على Play / App Store
│   ├── PRIVACY_POLICY.md            # سياسة الخصوصية (Markdown — المصدر)
│   ├── PRIVACY_POLICY.html          # مولّدة من الـ md للصق في CMS الموقع
│   └── PRIVACY_POLICY.docx          # نفس السياسة كملف Word
│
├── scripts/
│   ├── build_privacy_policy_html.mjs  # يبني الـ .html من PRIVACY_POLICY.md
│   └── build_privacy_policy_docx.ps1  # يبني الـ .docx من OOXML+ZIP مباشرة (نصه مكتوب جوّه السكربت)
│
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # compileSdk 36 + signing + R8 + ProGuard
│   │   ├── proguard-rules.pro       # R8 keep-rules لـ Flutter/secure_storage
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # permissions + VisitLocationService (type location)
│   │       ├── kotlin/net/digitalharbor/visits/MainActivity.kt
│   │       ├── kotlin/net/digitalharbor/visits/visittracking/  # تسجيل مسار الزيارة
│   │       └── res/
│   │           ├── values/strings.xml        # app_name = "Customer Visits"
│   │           ├── values-ar/strings.xml     # app_name = "زيارات العملاء"
│   │           └── xml/data_extraction_rules.xml  # منع نقل الـ session
│   ├── key.properties.template      # قالب release signing keystore
│   └── ...
│
├── ios/
│   └── Runner/
│       ├── Info.plist               # WhenInUse location + HTTPS-only + bg mode location (أثناء الزيارة)
│       ├── VisitLocation.swift      # تسجيل مسار الزيارة
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

# 4. شغّل التطبيق -- هيبدأ من شاشة "اتصل بالخادم" زي أول تشغيل عند العميل
flutter run

# 4-ب. لو عايز تتخطى شاشة الإعداد وتروح للـ backend الاختباري على طول
flutter run --dart-define=DEV_SEED_SERVER=true

# 5. أو شغّله على instance بعينه عن طريق --dart-define
flutter run \
  --dart-define=API_BASE_URL=https://your-odoo-instance.com \
  --dart-define=ODOO_DATABASE=your_db_name

# 6. أو من ملف .env (انسخ .env.example الأول)
flutter run --dart-define-from-file=.env.dev
```

### إيقونة التطبيق و splash

بعد تغيير `assets/icon/visit-logo-master.png` شغّل:

```bash
pwsh tool/generate_icons.ps1        # يشتق كل المقاسات من اللوجو الأصلي
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

`tool/generate_icons.ps1` يولّد كمان أيقونة الإشعارات
`android/app/src/main/res/drawable-*/ic_notification.png` — وهي **صورة ظلّية
بيضاء على خلفية شفافة**، لأن أندرويد بيتجاهل ألوان أيقونة شريط الحالة ويستخدم
قناة الشفافية فقط. لا تستبدلها بأيقونة التطبيق الملوّنة وإلا ظهرت ككتلة مصمتة.

---

## الاتصال بالباك إند

العقد الحالي كامل في [docs/API.md](docs/API.md) ([docs/README.md](docs/README.md) مرجع قديم للـ API السابق). الـ endpoints الرئيسية:

| الـ Endpoint | الوصف |
|---|---|
| `POST /web/session/authenticate` | تسجيل دخول Odoo |
| `POST /api/visit/my` · `get` | سجل الزيارات وتفاصيل زيارة |
| `POST /api/visit/create` · `submit` · `approve` · `reject` | إنشاء الزيارة ودورة الاعتماد |
| `POST /api/visit/start` · `end` | بداية ونهاية الزيارة (مع الإحداثيات) |
| `POST /api/visit/log_locations` | رفع نقاط مسار الزيارة دفعات |
| `POST /api/visit/track` | قراءة مسار الزيارة |

العملاء بيتقروا من `res.partner` عن طريق `call_kw` (شوف [docs/DATA_STORAGE_MAP.md](docs/DATA_STORAGE_MAP.md)).

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
| Precise location (while in use) | `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` | موقع Start/End Visit + مسار الزيارة الجارية |
| مسار الزيارة في الخلفية | `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` (service type `location`) | `UIBackgroundModes=location` + `NSLocationTemporaryUsageDescriptionDictionary` + `NSLocationAlwaysAndWhenInUseUsageDescription` (مطلوب لفحص Apple لأن `geolocator_apple` بيربط Always API، وبيخلّي المستخدم يقدر يختار Always من الإعدادات — التطبيق مابيطلبوش) | أثناء زيارة جارية فقط (من تأكيد Start لحد End أو الخروج) |
| Notifications | `POST_NOTIFICATIONS` | (push) | إشعارات الزيارات + إشعار "Visit tracking active" على Android |
| Camera | (intent) | `NSCameraUsageDescription` | صور إثبات الزيارة |
| Internet | `INTERNET` + `ACCESS_NETWORK_STATE` | (تلقائي) | API + كشف الـ offline |

**التطبيق مش بيطلب:**
- ❌ `ACCESS_BACKGROUND_LOCATION` — الـ foreground service بتبدأ دايمًا والتطبيق في المقدمة
- ❌ إذن "Always" على iOS — "While Using" كفاية (لو المستخدم اختار Always بنفسه من الإعدادات، iOS ممكن يعيد فتح التطبيق عشان يكمّل زيارة لسه جارية)
- ❌ Mic / Contacts / Calendar / SMS

قبل أول "بدء الزيارة" بيظهر إفصاح داخل التطبيق (إيه اللي بيتجمع، إنه بيكمل في الخلفية أثناء الزيارة، إنه بيقف مع End Visit أو الخروج، وبيروح فين). إعلانات Play في [store/play/location-and-foreground-service-declarations.md](store/play/location-and-foreground-service-declarations.md).

الـ Privacy Policy الكاملة في [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) (ونسخة HTML في [docs/PRIVACY_POLICY.html](docs/PRIVACY_POLICY.html) للصق في CMS الموقع، ونسخة Word في [docs/PRIVACY_POLICY.docx](docs/PRIVACY_POLICY.docx)).

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
4. انشر `docs/PRIVACY_POLICY.html` (أو الـ `.docx`) على موقع الشركة وحط الرابط في Play Console و App Store Connect.
5. اتبع الـ checklist في [docs/RELEASE.md](docs/RELEASE.md).
