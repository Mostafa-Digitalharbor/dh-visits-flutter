# دليل رفع التطبيق على Google Play و App Store

ده دليل تفصيلي خطوة بخطوة لكل اللي محتاج تعمله **يدوياً** قبل ما تضغط Submit. الكود وأوامر البناء موجودين في [RELEASE.md](RELEASE.md) -- الدليل ده عن **الحسابات والإعدادات الخارجية والـ secrets**.

---

## فهرس

- [1. الـ Secrets اللي لازم تحفظها في مكان آمن](#1-الـ-secrets-اللي-لازم-تحفظها-في-مكان-آمن)

- [2. خطوات Sentry.io (ابدأ بيها)](#2-خطوات-sentryio-ابدأ-بيها)

- [3. خطوات Google Play Console](#3-خطوات-google-play-console)

- [4. خطوات Apple App Store Connect](#4-خطوات-apple-app-store-connect)

- [5. الـ Privacy Policy](#5-الـ-privacy-policy)

- [6. قبل الـ Submit النهائي -- Checklist](#6-قبل-الـ-submit-النهائي--checklist)

- [7. لو الـ Review اترفض -- شائعة الأسباب وحلولها](#7-لو-الـ-review-اترفض--شائعة-الأسباب-وحلولها)

---

## 1. الـ Secrets اللي لازم تحفظها في مكان آمن

دي أهم نقطة في الموضوع كله. لو ضاعت منك أي حاجة من دول، ممكن تحصل مصايب من ضياع التطبيق نهائياً لحد رفع تكاليف. **استخدم password manager (1Password / Bitwarden / KeePass) أو vault الشركة** -- ممنوع تماماً تحطها في ملف نصي على المكتب أو ترفعها على GitHub.

### 1.1 Android keystore (الأهم على الإطلاق)

| العنصر | الوصف | لو ضاع |
|---|---|---|
| `upload-keystore.jks` | الملف نفسه (ثنائي) | **مش هتقدر ترفع تحديثات أبداً** -- التطبيق هيبقى يتيم وهتضطر تنشره من جديد بـ package جديد |
| `storePassword` | password الـ keystore كلها | نفس النتيجة |
| `keyPassword` | password المفتاح اللي جواه | نفس النتيجة |
| `keyAlias` | اسم المفتاح (افتراضي `upload`) | تقدر تطلعه من الـ jks لو الـ password عندك |

**خطوات إنشاءه (مرة واحدة فقط):**

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

هيسألك عن:
- `Enter keystore password:` -> اكتب password قوي واحفظه
- `Re-enter new password:`
- `What is your first and last name?` -> اسم الشركة (Digital Harbor)
- `What is the name of your organizational unit?` -> القسم (Mobile / IT)
- `What is the name of your organization?` -> Digital Harbor
- `What is the name of your City or Locality?` -> القاهرة مثلاً
- `What is the name of your State or Province?` -> Cairo
- `What is the two-letter country code?` -> EG

بعد كده هيطلب password المفتاح: اضغط Enter يستخدم نفس password الـ keystore، أو حط واحد مختلف.

**خزّن الـ 4 حاجات:**
1. الملف `upload-keystore.jks` نفسه (في password manager بصيغة file attachment، أو في cloud storage مشفر)
2. `storePassword`
3. `keyPassword`
4. `keyAlias` (`upload`)

**عمل ملف `android/key.properties` محلياً** (لا يتراك في git):

```properties
storePassword=الـpassword اللي ادخلته
keyPassword=الـpassword اللي ادخلته
keyAlias=upload
storeFile=C:/absolute/path/to/upload-keystore.jks
```

> ملاحظة Windows: لو فيه `\` في الـ path، استبدلها بـ `/` أو `\\` عشان Gradle مايتلخبطش.

### 1.2 Sentry DSN

DSN هو URL يقول للتطبيق فين يبعت الـ crashes. مش serious زي الـ keystore لكن:
- **مش حساس جداً** (لو اتسرب، شخص تاني يقدر يبعت fake events لمشروعك ويستهلك من quota)
- لو ضاع، تقدر تجيب واحد جديد من Sentry dashboard وتغيره في `.env.production`

**خزّن:**
- الـ DSN الكامل: `https://<key>@o<org>.ingest.sentry.io/<project>`
- `Auth Token` الخاص بـ Sentry CLI (لرفع الـ debug symbols تلقائياً -- اختياري في V1)

### 1.3 Apple Developer credentials

| العنصر | الوصف | لو ضاع |
|---|---|---|
| Apple ID اللي مسجل بيه في developer.apple.com | الإيميل | استعادة عادية عبر iforgot.apple.com |
| Team ID (10 أحرف) | معرّف الـ team في Apple | تجيبه من developer.apple.com -> Membership |
| App-Specific Password | لرفع IPA من command line | اعمل جديد من appleid.apple.com -> App-Specific Passwords |
| Distribution Certificate (`.p12`) + password | الشهادة اللي بتوقع بيها على الـ IPA | تقدر تعمل جديدة من Xcode |
| Provisioning Profile (`.mobileprovision`) | الـ profile بتاع التطبيق | اعمل جديد من developer.apple.com |

**Xcode بيدير معظمها تلقائياً** لو فعّلت "Automatically manage signing". لكن خزّن الـ Team ID و Apple ID في الـ vault.

### 1.4 Google Play Console credentials

| العنصر | الوصف |
|---|---|
| Google account اللي مسجل بيه | إيميل + 2FA backup codes |
| Developer account ID | تجيبه من Play Console -> Settings -> Developer account |
| Service Account JSON | لو هتعمل CI/CD ترفع تلقائي. لاحقاً، مش لازم لـ V1. |

### 1.5 Odoo backend credentials

| العنصر | الوصف |
|---|---|
| `API_BASE_URL` الإنتاجي | عنوان السيرفر بدون / في الآخر |
| `ODOO_DATABASE` الإنتاجي | اسم الـ database |
| Admin Odoo password | للوصول للـ backend وإدارة المستخدمين -- خزّنه برضو |

---

## 2. خطوات Sentry.io (ابدأ بيها)

ده هتعمله الأول عشان الـ DSN لازم يكون موجود في `.env.production` قبل البناء.

### 2.1 إنشاء حساب + project

1. روح <https://sentry.io/signup/> واعمل حساب بإيميل الشركة (`ai-tools@digital-harbor.net`).
2. اختار **Free plan** -- 5,000 errors / شهر وكافيين جداً للبداية.
3. لما يسألك عن نوع الـ project، اختار **Flutter**.
4. حط اسم الـ project: `customer-visits-mobile`.
5. اختار team أو اعمل team جديد `digital-harbor`.

### 2.2 طلع الـ DSN

بعد إنشاء الـ project هتلاقي صفحة "Configure" بيظهرلك:

```
const sentryDsn = 'https://abcdef1234567890@o9876543.ingest.sentry.io/1234567';
```

انسخ الـ string اللي بعد `=` بالظبط (من غير الـ quotes).

### 2.3 حطه في الـ `.env.production`

```bash
SENTRY_DSN=https://abcdef1234567890@o9876543.ingest.sentry.io/1234567
SENTRY_TRACES_PERCENT=10
```

> **مهم:** سيب `SENTRY_DSN=` فاضي في `.env.dev` عشان وأنت بتطوّر مايبعتش events من كل hot-reload.

### 2.4 جرّب يشتغل

بعد ما تعمل أول release build وتشغّله:
1. روح Sentry dashboard -> Issues
2. لو مفيش events، استنى دقيقة ثم اعمل crash متعمد (مثلاً اعمل throw في زرار للاختبار).
3. الـ crash المفروض يظهر خلال ثوان.

### 2.5 إعدادات الـ project المستحسنة

في Sentry dashboard:
- **Project Settings -> Alerts** -> فعّل "Notify me when a new issue happens" واربطه بـ Slack أو إيميل.
- **Project Settings -> Data Scrubbing** -> فعّل "Remove default credit cards/SSN/IPs" (افتراضي مفعّل).
- **Project Settings -> Inbound Filters** -> فعّل "Filter out errors from localhost" عشان مايجيش events من dev.

### 2.6 إيه اللي هتشوفه؟

- **كل crash** بيحصل في التطبيق (uncaught exceptions، type errors، null checks).
- **كل BLoC error** غير متوقّع (الـ `SentryBlocObserver` بيفلتر أخطاء الشبكة المعروفة عشان مايملاش الـ inbox).
- معاهم stack trace + معلومات الجهاز + إصدار التطبيق + الـ flavor (`dev`/`staging`/`production`).
- **مش هيشوف:** كلمات السر، الـ session tokens، الـ IPs الشخصية (مفعّلين `sendDefaultPii = false`).

---

## 3. خطوات Google Play Console

### 3.1 إنشاء developer account (مرة واحدة)

1. روح <https://play.google.com/console/signup>.
2. سجّل دخول بحساب Google الخاص بالشركة.
3. ادفع **$25 رسوم تسجيل مرة واحدة** (مدى الحياة، مش سنوي).
4. املأ بيانات الـ developer:
   - **Developer name**: Digital Harbor (هيظهر في صفحة التطبيق)
   - **Email**: ai-tools@digital-harbor.net
   - **Website**: https://digital-harbor.net
   - **Phone**: رقم اتصال فعّال (مش بيظهر للمستخدمين)
5. اقبل الـ Developer Distribution Agreement.
6. كمّل verification الـ identity (هيطلب ID رسمي للشركة أو بطاقة الشخص المسجل).

### 3.2 إنشاء التطبيق

1. Play Console -> **Create app**.
2. **App name**: Customer Visits
3. **Default language**: English (US) -- ممكن تضيف العربية بعدين كـ translation
4. **App or game**: App
5. **Free or paid**: Free
6. اقبل الـ declarations.

### 3.3 املأ الـ Store Listing

طلباتهم في تبويب "Main store listing":

- **App name**: Customer Visits
- **Short description** (80 char): "Field employee customer visit check-in/out with live location sharing."
- **Full description** (4000 char): اكتب وصف كامل. الـ template:

  ```
  Customer Visits is a workforce management tool for field sales teams.

  KEY FEATURES:
  • Check-in / check-out at customer sites with GPS verification
  • Live location sharing with your manager while using the app
  • Customer database with map view
  • Visit history and notes
  • Works offline -- queues actions and syncs when back online
  • Arabic and English support

  PRIVACY:
  This app collects your precise location ONLY while you are actively using it.
  No background tracking. No third-party analytics. No advertising. Your data
  goes directly to your employer's private Odoo instance.

  REQUIREMENTS:
  • Active employee account on your company's Odoo instance
  • Location services enabled
  ```

- **App icon**: 512×512 PNG (Play Console هيستخدمه؛ مش هو نفسه الـ launcher icon)
- **Feature graphic**: 1024×500 PNG (banner اللي بيظهر فوق التطبيق في Play Store)
- **Phone screenshots**: على الأقل 2، حد أقصى 8. الـ size: 1080×1920 أو 1080×2400 PNG
- **Tablet screenshots** (اختياري): لو هتدعم tablets

### 3.4 املأ الـ Content Rating

1. تبويب "App content" -> "Content rating".
2. اختار IARC questionnaire.
3. **Category**: Utility / Productivity / Communication
4. كل الأسئلة جاوبها **No** (مفيش عنف، مفيش contenu للراشدين، إلخ).
5. النتيجة هتطلع **Everyone**.

### 3.5 املأ الـ Target Audience

1. تبويب "App content" -> "Target audience and content".
2. **Target age groups**: 18 and over (التطبيق للموظفين فقط)
3. **Appeals to children**: No

### 3.6 املأ الـ Data Safety form (الأهم)

تبويب "App content" -> "Data safety". ده اللي بيتسبب في معظم الرفض.

**Data collection**:
- ✅ **Location -> Precise location**:
  - Collected: **Yes**
  - Shared with third parties: **No** (الـ Odoo instance بتاع الشركة مش third party)
  - Required: **Yes**
  - Purpose: **App functionality**
  - **هل بتجمعها في background؟** -> **No** (مهم جداً)
- ✅ **Personal info -> Name / Email address**:
  - Collected: Yes (للـ login)
  - Required: Yes
  - Purpose: Account management
- ✅ **App activity -> App interactions**:
  - Collected: Yes (visit history)
  - Purpose: App functionality
- ❌ **Photos/Videos**: No
- ❌ **Contacts**: No
- ❌ **Financial info**: No
- ❌ **Health & fitness**: No
- ❌ **Messages**: No
- ❌ **Files & docs**: No
- ❌ **Calendar / Audio / Web browsing / Other**: No

**Data handling practices**:
- ✅ Data is encrypted in transit (HTTPS only)
- ✅ Users can request that their data be deleted (عبر admin شركتهم)

### 3.7 املأ الـ Privacy Policy URL

تبويب "App content" -> "Privacy Policy".

- **URL**: `https://digital-harbor.net/privacy/visits` (بعد ما ترفع الـ `PRIVACY_POLICY.docx` على موقع الشركة، حط الـ URL هنا)

### 3.8 ارفع الـ AAB

1. تبويب "Production" -> "Create new release".
2. اختار **Use Google-generated app signing key** (موصى به -- جوجل بيدير الـ signing key للنشر، وانت بتوقّع بـ upload key بس).
3. **Upload**: ارفع `build/app/outputs/bundle/release/app-release.aab`
4. **Release name**: يفترض ياخدها من الـ versionName تلقائي (1.0.0)
5. **Release notes**:
   - English: "Initial release"
   - Arabic: "الإصدار الأول"
6. اضغط Next -> Review release -> Start rollout.

### 3.9 ارفع الـ debug symbols (لـ Sentry)

عشان الـ stack traces في Sentry تطلع readable بدل obfuscated:

```bash
# بعد البناء، الـ symbols في build/symbols/android/
# ارفعهم لـ Sentry CLI:
npm install -g @sentry/cli
sentry-cli login    # هيطلب الـ auth token
sentry-cli debug-files upload --org digital-harbor --project customer-visits-mobile build/symbols/android/
```

اعمل ده **مع كل release**. (لاحقاً تقدر تأتمته في CI.)

### 3.10 الـ Internal testing track (اختياري لكن مستحسن)

قبل ما تروح Production مباشرة:
1. **Testing -> Internal testing -> Create new release**.
2. ارفع الـ AAB.
3. ضيف نفسك + 2-3 من الفريق كـ testers.
4. جرّب التطبيق فعلياً.
5. لو كل حاجة تمام، **Promote release -> Production**.

---

## 4. خطوات Apple App Store Connect

### 4.1 إنشاء حساب Apple Developer

1. روح <https://developer.apple.com/programs/enroll/>.
2. سجّل دخول بـ Apple ID الشركة.
3. ادفع **$99 سنوياً** (لازم تجدّد كل سنة وإلا التطبيق هيتشال).
4. اختار **Organization** (مش Individual) لأنك بترفع باسم Digital Harbor.
5. هيطلب منك **D-U-N-S number** للشركة. لو مش معاكي:
   - ادخل <https://www.dnb.com/duns/get-a-duns-number.html>
   - مجاني للشركات لكن بياخد 5-14 يوم
6. كمّل verification -- ممكن ياخد أسبوع أو اتنين.

### 4.2 إنشاء App ID

1. <https://developer.apple.com/account/resources/identifiers/list>
2. **+** -> App IDs -> App
3. **Description**: Customer Visits
4. **Bundle ID**: Explicit -> `net.digitalharbor.visits`
5. Capabilities: مش محتاج تفعّل أي حاجة (مفيش push notifications، مفيش in-app purchases)
6. Continue -> Register

### 4.3 إنشاء التطبيق في App Store Connect

1. <https://appstoreconnect.apple.com> -> My Apps -> **+** -> New App
2. **Platform**: iOS
3. **Name**: Customer Visits
4. **Primary language**: English (U.K.) أو Arabic
5. **Bundle ID**: net.digitalharbor.visits (هيظهر اللي عملته فوق)
6. **SKU**: `digitalharbor-customer-visits` (أي قيمة فريدة، مش بتظهر للمستخدمين)
7. **User Access**: Full Access

### 4.4 املأ الـ App Information

1. **Privacy Policy URL**: نفس اللي حطته في Google Play
2. **Category**: Primary = Business، Secondary = Productivity
3. **Content Rights**: Does Your App Contain, Display, or Access Third-Party Content? -> No

### 4.5 املأ الـ App Privacy

تبويب **App Privacy** -> Get Started.

نفس فكرة Google Data Safety بس بنموذج مختلف:

- ✅ **Location -> Precise Location**:
  - Used to: App Functionality
  - Linked to user: Yes
  - Used for tracking: **No** (مهم جداً -- "tracking" عند Apple معناه استخدامها للإعلانات، مش للمدير)
- ✅ **Contact Info -> Name + Email Address**:
  - Used to: App Functionality
  - Linked to user: Yes
  - Used for tracking: No
- ✅ **User Content -> Other User Content** (visit notes):
  - Used to: App Functionality
  - Linked to user: Yes
  - Used for tracking: No
- ✅ **Identifiers -> User ID** (Odoo uid):
  - Used to: App Functionality
  - Linked to user: Yes
  - Used for tracking: No

كل اللي تاني: Not Collected.

### 4.6 إعداد Pricing & Availability

- **Price**: Free
- **Availability**: All countries (أو حدد دول معينة لو عايز)

### 4.7 جهّز Screenshots & Description

- **App previews and screenshots**:
  - **iPhone 6.7"** (iPhone 15 Pro Max): مطلوب على الأقل 3 -- size 1290×2796
  - **iPhone 6.5"** (iPhone 11 Pro Max): مطلوب على الأقل 3 -- size 1242×2688
  - **iPad 12.9"** (لو هتدعم iPad): 2048×2732

- **Promotional Text** (170 char): "Field employee check-in/out app with live location sharing."
- **Description** (4000 char): نفس وصف Google Play
- **Keywords** (100 char): "field, visits, employee, gps, check-in, sales, customer"
- **Support URL**: https://digital-harbor.net/support
- **Marketing URL** (اختياري): https://digital-harbor.net

### 4.8 ارفع الـ IPA

من جهازك (Mac مطلوب):

```bash
flutter build ipa --release \
  --dart-define-from-file=.env.production \
  --obfuscate --split-debug-info=build/symbols/ios
```

الـ IPA في `build/ios/ipa/*.ipa`. ارفعها بإحدى الطرق:

**الطريقة (أ): Transporter app** (الأسهل)
1. نزّل **Transporter** من Mac App Store
2. سجّل دخول بـ Apple ID
3. اسحب الـ IPA للنافذة -> Deliver
4. استنى 5-15 دقيقة عشان يعمل processing

**الطريقة (ب): xcrun من الـ terminal**
```bash
xcrun altool --upload-app -f build/ios/ipa/*.ipa \
  -t ios -u your-apple-id@example.com -p app-specific-password
```

### 4.9 جهّز الـ TestFlight Build قبل Production

1. App Store Connect -> Your App -> **TestFlight**
2. الـ build اللي رفعته هيظهر بعد processing.
3. ضيف اختبارات داخلية:
   - **Internal testing -> + Group** -> "Digital Harbor Team"
   - ضيف نفسك + 2-3 من الفريق
   - يجي للناس إيميل، يحمّلوا TestFlight app ويثبتوا التطبيق
4. جرّب لمدة 2-3 أيام.

### 4.10 ارفع الـ Submit للـ App Review

1. App Store Connect -> Your App -> **App Store** tab -> Prepare for Submission
2. اختار الـ build اللي اختبرته في TestFlight
3. املأ:
   - **Description, Keywords** (لو لسه)
   - **Sign-In Information** (مهم جداً للـ Apple reviewer):
     - Username: `reviewer@digital-harbor.net` (اعمل حساب test في الـ Odoo)
     - Password: شيء قوي بس مش حقيقي
     - Notes: "Please use these credentials to test the app. The app requires location permission."
   - **Contact Information**: اسم وإيميل
4. **Submit for Review**

> Apple بياخد **24-72 ساعة** للمراجعة. أحياناً أسرع، أحياناً أبطأ.

### 4.11 ارفع الـ dSYMs (لـ Sentry)

```bash
sentry-cli debug-files upload --org digital-harbor --project customer-visits-mobile \
  build/ios/archive/Runner.xcarchive/dSYMs/
```

---

## 5. الـ Privacy Policy

التطبيق بيطلب location، فـ **مفيش رفع من غير privacy policy على لينك علني**.

### 5.1 ارفع الـ document

1. الملف جاهز في [PRIVACY_POLICY.docx](PRIVACY_POLICY.docx) (و [PRIVACY_POLICY.md](PRIVACY_POLICY.md))
2. عدّل الـ placeholders:
   - `_Replace with the date you publish this policy_` -> التاريخ الفعلي
3. ارفعه على موقع الشركة. خيارات:
   - **الأبسط**: ارفع HTML أو PDF على `https://digital-harbor.net/privacy/visits/`
   - **بـ Markdown viewer**: استخدم Notion / GitBook ووفّر public link
   - **GitHub Pages**: لو مش هتلاقي مكان بسرعة، ارفع `PRIVACY_POLICY.md` لـ repo public وفعّل GitHub Pages

### 5.2 حط الـ URL في:
- Google Play Console -> App content -> Privacy Policy
- App Store Connect -> App Information -> Privacy Policy URL
- داخل التطبيق نفسه (لاحقاً تقدر تضيف زرار في الـ Settings)

---

## 6. قبل الـ Submit النهائي -- Checklist

اعمل scan على القائمة دي قبل ما تضغط Submit في أي من المتجرين:

### تقنياً
- [ ] `flutter analyze` نظيف
- [ ] الـ AAB / IPA اتبنى بـ `--release --obfuscate --split-debug-info`
- [ ] الـ build استخدم `.env.production` (مش `.env.dev`!)
- [ ] اختبرت الـ AAB فعلياً على جهاز Android حقيقي (مش emulator بس)
- [ ] اختبرت الـ IPA فعلياً عبر TestFlight على iPhone حقيقي
- [ ] جربت تسجيل الدخول والـ check-in/out بنجاح
- [ ] جربت الـ live location يظهر صح في dashboard الـ Odoo
- [ ] جربت اللغة العربية والإنجليزية والـ Light/Dark theme
- [ ] جربت قطع النت ثم رجوعه (الـ offline queue يشتغل)
- [ ] جربت crash متعمد وتأكدت إنه ظهر في Sentry

### إدارياً
- [ ] الـ keystore + passwords محفوظين في password manager
- [ ] الـ Privacy Policy منشور على URL علني
- [ ] الـ `.env.production` فيه القيم الإنتاجية (مش الـ trial)
- [ ] حساب test في Odoo جاهز للـ Apple reviewer
- [ ] Screenshots و feature graphic جاهزين بالـ resolutions الصحيحة
- [ ] الـ versionName في `pubspec.yaml` متظبط (مثلاً `1.0.0`)
- [ ] الـ versionCode (الـ `+N`) يساوي أو أكبر من آخر build مرفوع

---

## 7. لو الـ Review اترفض -- شائعة الأسباب وحلولها

### Google Play

| السبب | الحل |
|---|---|
| "Permission not declared in privacy policy" | ضيف الـ permission اللي في الـ manifest للـ Privacy Policy |
| "Data Safety doesn't match app behavior" | راجع نموذج Data Safety -- أكيد فيه حاجة معلنة غلط |
| "App targeting older API" | غيّر `targetSdk` في `build.gradle.kts` -- لازم >= 34 |
| "Missing privacy policy" | حط الـ URL في App content -> Privacy Policy |
| "Background location declared but no foreground service" | **مش حالتنا** -- إحنا foreground-only |

### Apple

> **حصل فعلًا يوم 2026-08-06 على النسخة 1.0 (4):** رفض تحت البندين 2.3.10 و2.1.
> التشخيص والرد وخطوات إعادة التقديم في
> [../store/appstore/apple-review-2026-08-06.md](../store/appstore/apple-review-2026-08-06.md).

| السبب | الحل |
|---|---|
| **"Guideline 2.3.10 - non-iOS status bar images"** | لقطات App Store لازم تتصوَّر على iOS -- `store/photo/tools/ios_shots.sh`. لقطة أندرويد مؤطَّرة = رفض مباشر |
| **"Guideline 2.1 - Provide server address"** | التطبيق بيطلب عنوان سيرفر الشركة أول شاشة؛ حساب demo لوحده مش كفاية -- لازم URL + اسم الـ database في الـ Notes |
| "Guideline 5.1.1 - Data Collection and Storage" | راجع App Privacy form -- محتاج تكون أوضح في الـ purpose |
| "Guideline 2.1 - App Completeness" | فيه bug أو الـ login مش شغّال للـ reviewer -- وفّر credentials صحيحة |
| "Guideline 4.0 - Design" | الـ UI مش متبع iOS HIG -- نادراً يحصل لتطبيق Flutter |
| "Missing Demo Account" | لازم تحط user/pass في Sign-In Information |
| "Background Location Usage" | مش حالتنا -- مفيش بـ `UIBackgroundModes` |

---

## أهم النصايح اللي أتعلمتها من ناس رفعت قبل كده

1. **لا ترفع AAB على Production مباشرة**. روح Internal Testing الأول، ولو تمام promote.
2. **Apple أبطأ من Google** بكتير. خطّط على أساس 3-5 أيام من رفع IPA لظهوره في الـ Store.
3. **الـ keystore تضيع = التطبيق يضيع**. اعمل backup في 3 أماكن مختلفة (vault + cloud + USB في الخزنة).
4. **اعمل version bump بعد كل رفع**. الـ Play Console بيرفض أي AAB versionCode يساوي أو أصغر من المرفوع قبله.
5. **خلي عينك على Sentry أول أسبوع بعد الإطلاق**. الـ crashes اللي ما تظهرش في الـ testing بتظهر في الـ wild.
6. **متضفش Background location لـ V1**. لو احتجته بعدين، اعمله في V1.1 مع flutter_foreground_task. شوف [RELEASE.md](RELEASE.md) -- الـ refactor موثّق.
