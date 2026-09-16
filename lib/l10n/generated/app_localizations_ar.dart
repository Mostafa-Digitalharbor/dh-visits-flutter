// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'الزيارات';

  @override
  String get appTagline => 'تابع زياراتك الميدانية بدقة';

  @override
  String get commonRequired => 'مطلوب';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get commonSearch => 'بحث…';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonOptional => '(اختياري)';

  @override
  String get commonLogout => 'تسجيل الخروج';

  @override
  String get commonRefresh => 'تحديث';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonNoValue => '—';

  @override
  String commonLabeledValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String commonCoordinates(String lat, String lng) {
    return '$lat, $lng';
  }

  @override
  String get commonListSeparator => ' · ';

  @override
  String commonRefreshFailedStale(String reason) {
    return '$reason تُعرض آخر بيانات تم تحميلها — اسحب الشاشة للأسفل لإعادة المحاولة.';
  }

  @override
  String commonTimeRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String commonDurationHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String commonDurationHours(int hours) {
    return '$hours س';
  }

  @override
  String commonDurationMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String commonErrorReference(String code) {
    return 'رمز الخطأ: $code';
  }

  @override
  String get commonGreetingMorning => 'صباح الخير';

  @override
  String get commonGreetingAfternoon => 'مساء الخير';

  @override
  String get commonGreetingEvening => 'مساء الخير';

  @override
  String get commonPageNotFoundTitle => 'الصفحة غير موجودة';

  @override
  String get commonPageNotFoundMessage =>
      'هذا الرابط لا يفتح أي صفحة في التطبيق. ارجع إلى الشاشة الرئيسية وحاول مرة أخرى من هناك.';

  @override
  String get commonGoHome => 'الذهاب إلى الشاشة الرئيسية';

  @override
  String commonFraction(String done, String total) {
    return '$done/$total';
  }

  @override
  String badgeOverflow(int max) {
    return '+$max';
  }

  @override
  String visitFallbackTitle(int id) {
    return 'زيارة رقم $id';
  }

  @override
  String unitMeters(String value) {
    return '$value م';
  }

  @override
  String unitMinutes(String value) {
    return '$value د';
  }

  @override
  String unitKm(String value) {
    return '$value كم';
  }

  @override
  String unitKmh(String value) {
    return '$value كم/س';
  }

  @override
  String unitPercentValue(String value) {
    return '$value٪';
  }

  @override
  String get unitMinShort => 'د';

  @override
  String get relativeNow => 'الآن';

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      many: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      many: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String get themeMode => 'المظهر';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageCodeShortArabic => 'ع';

  @override
  String get languageCodeShortEnglish => 'EN';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonOpenSettings => 'فتح الإعدادات';

  @override
  String get serverSetupTitle => 'اتصل بالخادم';

  @override
  String get serverSetupSubtitle => 'أدخل عنوان خادم شركتك للبدء';

  @override
  String get serverSetupUrlLabel => 'رابط الخادم';

  @override
  String get serverSetupUrlHint => 'https://your-company.odoo.com';

  @override
  String get serverSetupContinue => 'متابعة';

  @override
  String get serverSetupInvalidUrl =>
      'أدخل عنوان خادم صحيحًا (مثال: https://your-company.odoo.com).';

  @override
  String get serverSetupHelp =>
      'اسأل مسؤول النظام إذا كنت لا تعرف عنوان الخادم.';

  @override
  String get serverSetupDatabaseLabel => 'اسم قاعدة البيانات';

  @override
  String get serverSetupDatabaseHint => 'مثال: company-main';

  @override
  String get serverSetupDatabasePrompt =>
      'تعذّر اكتشاف قاعدة البيانات تلقائيًا. أدخل اسمها (اسأل مسؤول النظام).';

  @override
  String get serverSetupChecking => 'جارٍ الاتصال…';

  @override
  String get serverSetupDetectDb => 'اكتشاف قاعدة البيانات';

  @override
  String get serverSetupDetecting => 'جارٍ الاكتشاف…';

  @override
  String serverSetupDetected(String db) {
    return 'تم اكتشاف قاعدة البيانات: $db';
  }

  @override
  String get serverSetupDetectFailed =>
      'تعذّر اكتشاف قاعدة البيانات تلقائيًا — أدخل اسمها يدويًا.';

  @override
  String get serverSetupInsecureUrl =>
      'يبدأ هذا العنوان بـ http://، أي أن كلمة المرور سترسَل دون تشفير. أدخل عنوان الخادم الذي يبدأ بـ https://، واسأل مسؤول النظام إن لم تكن تعرفه.';

  @override
  String serverSetupUnreachable(String host) {
    return 'تعذّر الوصول إلى $host. تحقّق من كتابة العنوان ومن اتصالك بالإنترنت، ثم أعد المحاولة.';
  }

  @override
  String serverSetupTimeout(String host) {
    return 'استغرق $host وقتًا طويلًا في الرد. تحقّق من اتصالك وأعد المحاولة، وإن تكرّر ذلك فقد يكون الخادم متوقفًا؛ فتواصل مع مسؤول النظام.';
  }

  @override
  String serverSetupNotOdoo(String host) {
    return 'ردّ $host لكنه ليس خادم Odoo. أدخل العنوان الذي تفتح به Odoo في المتصفح، وإن كنت متصلًا بشبكة واي فاي عامة فسجّل الدخول إليها أولًا.';
  }

  @override
  String serverSetupUntrustedCertificate(String host) {
    return 'شهادة الأمان الخاصة بـ $host غير موثوقة، لذلك لن يرسل التطبيق كلمة المرور إليه. راجع العنوان مع مسؤول النظام؛ فالخادم يحتاج إلى شهادة أمان صالحة.';
  }

  @override
  String serverSetupServerDown(String host) {
    return 'يواجه $host مشكلة حاليًا، وقد يكون في أعمال صيانة. انتظر بضع دقائق ثم أعد المحاولة، وإن استمرت المشكلة فتواصل مع مسؤول النظام.';
  }

  @override
  String serverSetupSeveralDatabases(String databases) {
    return 'يستضيف هذا الخادم عدة قواعد بيانات ($databases). أدخل اسم القاعدة التي تستخدمها شركتك.';
  }

  @override
  String serverSetupDatabaseMissing(String db) {
    return 'لا توجد على هذا الخادم قاعدة بيانات باسم «$db». تحقّق من الاسم، أو امسح الحقل واضغط «اكتشاف قاعدة البيانات».';
  }

  @override
  String get serverSetupSaveFailed =>
      'تعذّر حفظ إعدادات الخادم على هذا الجهاز. أعد المحاولة، وإن تكرّر الخطأ فأعد تشغيل التطبيق.';

  @override
  String get loginChangeServer => 'تغيير الخادم';

  @override
  String get loginTitle => 'الزيارات';

  @override
  String get loginSubtitle => 'سجّل دخولك لبدء يومك الميداني';

  @override
  String get loginWelcomeBack => 'أهلًا بعودتك';

  @override
  String get loginRoleLabel => 'الدخول بصفتك';

  @override
  String get loginUsername => 'البريد الإلكتروني / اسم المستخدم';

  @override
  String get loginPassword => 'كلمة المرور';

  @override
  String get loginSubmit => 'تسجيل الدخول';

  @override
  String get loginRememberMe => 'تذكّرني';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginForgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get loginForgotPasswordBody =>
      'يتولى مسؤول النظام إعادة تعيين كلمات المرور. يُرجى التواصل معه لإعادة تعيين كلمة المرور.';

  @override
  String get loginSecureFooter => 'دخول آمن · Digital Harbor';

  @override
  String get loginInvalidCredentials =>
      'اسم المستخدم أو كلمة المرور غير صحيحة. تحقّق منهما وأعد المحاولة، ويمكن لمسؤول النظام إعادة تعيين كلمة المرور.';

  @override
  String get loginTwoFactorUnsupported =>
      'حسابك مفعّل عليه التحقق بخطوتين، وهو غير مدعوم في التطبيق حاليًا. اطلب من مسؤول النظام إيقافه لحسابك، ثم سجّل الدخول مجددًا.';

  @override
  String get loginNoVisitRole =>
      'ليست لحسابك صلاحية على الزيارات. اطلب من مسؤول النظام منحك دورًا في الزيارات (مستخدم أو مدير)، ثم سجّل الدخول مجددًا.';

  @override
  String get loginSessionEnded =>
      'تم تسجيل خروجك لأن جلستك انتهت على الخادم. سجّل الدخول مجددًا للمتابعة.';

  @override
  String get errInvalidCredentials =>
      'البريد الإلكتروني/اسم المستخدم أو كلمة المرور غير صحيحة. تحقّق منهما ثم أعد المحاولة.';

  @override
  String get errAuthRequired => 'انتهت جلستك. سجّل الدخول مرة أخرى للمتابعة.';

  @override
  String get errPermissionDenied =>
      'ليست لديك صلاحية لتنفيذ هذا الإجراء. إذا كنت تحتاج إليها فاطلبها من مديرك أو من مسؤول النظام.';

  @override
  String get errValidation =>
      'لم تُقبل بعض البيانات التي أدخلتها. راجعها ثم أعد المحاولة.';

  @override
  String get errNotVisitApprover =>
      'لست معتمِدًا لهذه الزيارة. الاعتماد أو الرفض متاح فقط لمدير ضمن التسلسل الإداري لصاحب الزيارة.';

  @override
  String get errOnlyApprovedCanStart =>
      'يجب اعتماد هذه الزيارة قبل أن تتمكن من بدئها. أرسلها للاعتماد إن لم تفعل، ثم انتظر قرار مديرك.';

  @override
  String get errOnlyInProgressCanEnd =>
      'هذه الزيارة ليست جارية، لذا لا يمكن إنهاؤها. حدِّث الصفحة للتحقق من حالتها، فربما لم تبدأ بعد أو انتهت بالفعل.';

  @override
  String get errOnlyDraftCanSubmit =>
      'لا يمكن إرسال هذه الزيارة للاعتماد لأنها ليست مسودة ولا مرفوضة ولا مُعادة الجدولة. حدِّث الصفحة لمعرفة حالتها الحالية.';

  @override
  String get errCannotApproveInState =>
      'لا يمكن اعتماد هذه الزيارة في حالتها الحالية. حدِّث الصفحة لمعرفة وضعها.';

  @override
  String get errAttendeesPending =>
      'لا يمكن اعتماد هذه الزيارة بعد — يجب أن يعتمد مدير كل مشارك مشاركته أولًا. أعد المحاولة بعد اكتمال موافقات المشاركين.';

  @override
  String get errCannotRejectInState =>
      'لا يمكن رفض هذه الزيارة في حالتها الحالية. حدِّث الصفحة لمعرفة وضعها.';

  @override
  String get errOutcomeRequired => 'أضف نتيجة الزيارة قبل إنهائها.';

  @override
  String errMissingRequiredField(String field) {
    return 'املأ الحقل المطلوب «$field» ثم أعد المحاولة.';
  }

  @override
  String get errMissingRequiredFieldGeneric =>
      'يوجد حقل مطلوب فارغ. املأ جميع الحقول المطلوبة ثم أعد المحاولة.';

  @override
  String get errAttendeeAlreadyDecided =>
      'تم البتّ في طلب هذا المشارك مسبقًا بالاعتماد أو الرفض. حدِّث الصفحة لمعرفة القرار الأخير.';

  @override
  String get errCannotRescheduleFinished =>
      'هذه الزيارة منتهية بالفعل، لذا لا يمكن إعادة جدولتها. أنشئ زيارة جديدة بدلًا منها.';

  @override
  String get errProjectRequired =>
      'اختر المشروع الخاص بهذه الزيارة ثم أعد المحاولة.';

  @override
  String get errOpportunityRequired =>
      'اختر الفرصة الخاصة بهذه الزيارة ثم أعد المحاولة.';

  @override
  String get errTrailVisitNotStarted =>
      'تعذّر تسجيل مسارك لأن هذه الزيارة لم تبدأ بعد. ابدأ الزيارة أولًا.';

  @override
  String get errTrailVisitEnded =>
      'انتهت هذه الزيارة بالفعل، لذا لا يمكن إضافة نقاط أخرى إلى مسارها. لا يلزمك أي إجراء.';

  @override
  String get errRecordInUse =>
      'هذا العنصر مرتبط ببيانات أخرى، لذا لا يمكن تعديله أو حذفه. تواصل مع مسؤول النظام إذا لزم تغييره.';

  @override
  String get errNotFound =>
      'تعذّر العثور على هذا العنصر، فربما حُذف. حدِّث الصفحة ثم أعد المحاولة.';

  @override
  String get errLocationRequired =>
      'لا يوجد موقع محفوظ لهذا العميل، لذا لا يمكن تسجيل الزيارة. اطلب من مديرك أو من مسؤول النظام إضافة موقع العميل.';

  @override
  String get errServerError =>
      'حدث خلل في الخادم. أعد المحاولة بعد بضع دقائق، وإذا تكرر ذلك فتواصل مع مسؤول النظام.';

  @override
  String get errServerUnavailable =>
      'الخادم غير متاح مؤقتًا، غالبًا بسبب أعمال صيانة. انتظر بضع دقائق ثم أعد المحاولة.';

  @override
  String get errRateLimited =>
      'أُرسلت طلبات كثيرة في وقت قصير. انتظر دقيقة ثم أعد المحاولة.';

  @override
  String get errPayloadTooLarge =>
      'حجم هذا الملف أكبر من المسموح برفعه. اختر ملفًا أصغر أو صورة بدقة أقل.';

  @override
  String get errInvalidResponse =>
      'وصل من الخادم رد تعذّر على التطبيق قراءته. إذا كنت متصلًا بشبكة واي فاي عامة فسجّل الدخول إليها أولًا، وإلا فراجع عنوان الخادم مع مسؤول النظام.';

  @override
  String get errDatabaseNotFound =>
      'لم يتم العثور على قاعدة بيانات الشركة على هذا الخادم. تحقّق من اسم قاعدة البيانات في إعدادات الخادم، أو اطلب الاسم الصحيح من مسؤول النظام.';

  @override
  String get errNetworkTimeout =>
      'استغرق الخادم وقتًا طويلًا في الرد. تحقّق من اتصالك بالإنترنت ثم أعد المحاولة.';

  @override
  String get errNetworkUnreachable =>
      'تعذّر الوصول إلى الخادم. تحقّق من اتصالك بالإنترنت (واي فاي أو بيانات الجوال) ثم أعد المحاولة.';

  @override
  String get errNetworkUnknown =>
      'حدثت مشكلة في الاتصال. تحقّق من اتصالك بالإنترنت ثم أعد المحاولة.';

  @override
  String get errLocationPermission =>
      'لا يستطيع التطبيق الوصول إلى موقعك. فعّل خدمات الموقع واسمح للتطبيق باستخدام موقعك، ثم أعد المحاولة.';

  @override
  String get errLocationNeededForVisit =>
      'يلزم تسجيل موقعك لتوثيق هذه الزيارة. فعّل خدمات الموقع واسمح للتطبيق باستخدامها، ثم أعد المحاولة.';

  @override
  String get errLocationUnavailable =>
      'تعذّر تحديد موقعك. انتقل إلى مكان مفتوح تظهر فيه السماء بوضوح ثم أعد المحاولة.';

  @override
  String get errUnknown =>
      'حدث خطأ من جهتنا. أعد المحاولة، وإذا تكرر ذلك فأرسل لقطة شاشة إلى مسؤول النظام.';

  @override
  String get errSessionRestoreFailed =>
      'تعذّر استعادة جلستك المحفوظة. سجّل الدخول مرة أخرى للمتابعة.';

  @override
  String get errProfileIncomplete =>
      'تعذّر تحميل صلاحياتك، لذا أُخفيت إجراءات الزيارات. سجّل الخروج ثم سجّل الدخول مجددًا، وإذا استمرت المشكلة فاطلب من مسؤول النظام مراجعة دورك في الزيارات.';

  @override
  String get pushChannelName => 'تحديثات الزيارات';

  @override
  String get pushChannelDescription =>
      'الاعتمادات وإعادة الجدولة وتغييرات حالة زياراتك.';

  @override
  String get pushEventSubmitted => 'زيارة بانتظار موافقتك';

  @override
  String get pushEventParticipationApproval => 'مشارك بانتظار موافقتك';

  @override
  String get pushEventReadyForApproval => 'زيارة جاهزة لاعتمادك';

  @override
  String get pushEventApproved => 'تم اعتماد الزيارة';

  @override
  String get pushEventRejected => 'تم رفض الزيارة';

  @override
  String get pushEventParticipantRejected => 'تم رفض أحد المشاركين';

  @override
  String get pushEventRescheduleRequested => 'طلب إعادة جدولة بانتظار موافقتك';

  @override
  String get pushEventRescheduleApproved => 'تم اعتماد إعادة الجدولة';

  @override
  String get pushEventEscalated => 'صُعِّدت إليك زيارة';

  @override
  String get pushEventStarted => 'بدأت الزيارة';

  @override
  String get pushEventCompleted => 'اكتملت الزيارة';

  @override
  String get pushEventCancelled => 'أُلغيت الزيارة';

  @override
  String get pushEventUpdated => 'تم تحديث الزيارة';

  @override
  String get unitPercent => '٪';

  @override
  String unitBytes(String size) {
    return '$size بايت';
  }

  @override
  String unitKilobytes(String size) {
    return '$size ك.ب';
  }

  @override
  String unitMegabytes(String size) {
    return '$size م.ب';
  }

  @override
  String offlineActionDropped(String reason) {
    return 'لم يُحفظ التحديث الذي أجريته دون اتصال. $reason افتح الزيارة وسجّله مرة أخرى.';
  }

  @override
  String get errConflict =>
      'عُدِّلت هذه الزيارة من مكان آخر. اسحب للأسفل للتحديث وتحقّق من حالتها الحالية قبل إعادة المحاولة.';

  @override
  String get errInsecureConnection =>
      'تعذّر إنشاء اتصال آمن بالخادم لأن شهادة الأمان الخاصة به غير موثوقة. تحقّق من عنوان الخادم مع مسؤول النظام.';

  @override
  String get errCustomerLoadFailed =>
      'تعذّر تحميل بيانات العميل. تحقّق من اتصالك بالإنترنت ثم أعد المحاولة.';

  @override
  String get errAttachmentOpenFailed =>
      'تعذّر فتح هذا المرفق. تأكّد من وجود تطبيق على جوالك يمكنه فتح هذا النوع من الملفات، ثم أعد المحاولة.';

  @override
  String get errAttachmentUnavailable =>
      'هذا المرفق لم يعد متاحًا — اسحب للأسفل للتحديث.';

  @override
  String get errAttachmentsLoadFailed =>
      'تعذّر تحميل المرفقات. تحقّق من اتصالك بالإنترنت، ثم اسحب للأسفل لإعادة المحاولة.';

  @override
  String get attachmentsEmpty => 'لا توجد مرفقات بعد';

  @override
  String get errCannotLaunchApp =>
      'لا يوجد على جوالك تطبيق يمكنه تنفيذ هذا الإجراء (مثل تطبيق الاتصال أو البريد أو الخرائط). ثبّت تطبيقًا مناسبًا أو فعّله، ثم أعد المحاولة.';

  @override
  String get errActionFailed =>
      'تعذّر إتمام هذا الإجراء بسبب مشكلة غير متوقعة. حدِّث الصفحة ثم أعد المحاولة، وإذا تكرر ذلك فتواصل مع مسؤول النظام.';

  @override
  String get errFeatureNotAvailable =>
      'هذه الميزة غير مفعّلة على خادم شركتك بعد. اطلب من مسؤول النظام تفعيلها.';

  @override
  String get customersTitle => 'العملاء';

  @override
  String get customersSearchHint => 'بحث عن عميل…';

  @override
  String get customersEmpty => 'لا يوجد عملاء';

  @override
  String get customersStatTotal => 'إجمالي العملاء';

  @override
  String get customersStatActive => 'العملاء النشطون';

  @override
  String get customerDetailTitle => 'تفاصيل العميل';

  @override
  String get customerLastVisit => 'آخر زيارة';

  @override
  String get customerActionCheckIn => 'بدء الزيارة';

  @override
  String get customerActionCall => 'اتصال';

  @override
  String get customerActionNavigate => 'اتجاهات';

  @override
  String get customerActionEmail => 'بريد';

  @override
  String get customerTypeCompany => 'شركة';

  @override
  String get customerTypeIndividual => 'فرد';

  @override
  String get customerSectionInfo => 'بيانات التواصل';

  @override
  String get customerFieldType => 'النوع';

  @override
  String get customerFieldEmail => 'البريد الإلكتروني';

  @override
  String get customerFieldJob => 'المسمى الوظيفي';

  @override
  String get customerFieldParent => 'الشركة التابع لها';

  @override
  String get customerFieldTags => 'الوسوم';

  @override
  String get customerFieldWebsite => 'الموقع الإلكتروني';

  @override
  String get customerFieldVat => 'الرقم الضريبي';

  @override
  String get customerFieldCoordinates => 'الإحداثيات';

  @override
  String get customerAddressSeparator => '، ';

  @override
  String get customerNotFound =>
      'هذا العميل لم يعد موجودًا، أو لم تعد لديك صلاحية الوصول إليه. ارجع وحدّث قائمة العملاء.';

  @override
  String get customerAlreadyCheckedIn => 'لديك زيارة جارية هنا الآن';

  @override
  String get customerActiveVisitBadge => 'زيارة جارية';

  @override
  String customerCheckInBlocked(String customer) {
    return 'لديك زيارة جارية عند $customer. أنهِها قبل بدء زيارة أخرى.';
  }

  @override
  String get customerCheckInBlockedShort => 'زيارة جارية في مكان آخر';

  @override
  String get checkInSuccess => 'تم تسجيل الوصول';

  @override
  String get visitActiveTitle => 'زيارة جارية';

  @override
  String get visitActiveEmpty =>
      'لا توجد زيارة جارية الآن.\nاختر عميلًا وابدأ الزيارة.';

  @override
  String visitStartedAt(String time) {
    return 'بدأت الساعة $time';
  }

  @override
  String get visitLiveIndicator => 'مباشر';

  @override
  String get mapZoomIn => 'تكبير';

  @override
  String get mapZoomOut => 'تصغير';

  @override
  String get mapRecenter => 'توسيط الخريطة';

  @override
  String get mapOpenDirections => 'فتح الاتجاهات';

  @override
  String get visitNotesLabel => 'ملاحظات (اختياري)';

  @override
  String get visitActionCheckOut => 'إنهاء الزيارة';

  @override
  String get checkOutSuccess => 'تم إنهاء الزيارة';

  @override
  String get employeesTitle => 'الموظفون';

  @override
  String get employeesEmpty => 'لا يوجد موظفون مُضافون بعد';

  @override
  String get employeesSearchHint => 'بحث عن موظف…';

  @override
  String get createVisitCustomerLabel => 'العميل';

  @override
  String get createVisitEmployeeLabel => 'الموظف';

  @override
  String get createVisitDateLabel => 'تاريخ الزيارة';

  @override
  String get createVisitTypeLabel => 'نوع الزيارة (اختياري)';

  @override
  String get createVisitNotesLabel => 'ملاحظات (اختياري)';

  @override
  String get createVisitStateLabel => 'الحالة الابتدائية';

  @override
  String get visitStateDraft => 'مسودة';

  @override
  String get visitStateSubmit => 'إرسال';

  @override
  String get visitStateUnderReview => 'قيد المراجعة';

  @override
  String get visitStateDone => 'منتهية';

  @override
  String get visitStateCancel => 'ملغاة';

  @override
  String get visitDetailVisitTypeLabel => 'نوع الزيارة';

  @override
  String get visitDetailEditVisitType => 'تغيير نوع الزيارة';

  @override
  String get visitDetailMarkAsDone => 'تأكيد المراجعة';

  @override
  String get visitDetailMarkAsDoneSuccess => 'تم تأكيد مراجعة الزيارة';

  @override
  String get visitDetailSendToEmployee => 'إرسال للموظف';

  @override
  String get visitDetailSentToEmployeeSuccess => 'تم إرسال الزيارة للموظف';

  @override
  String get visitDetailEditState => 'تغيير الحالة';

  @override
  String get visitDetailPickState => 'اختر الحالة';

  @override
  String get createVisitSuccess => 'تم إنشاء الزيارة';

  @override
  String get createVisitCustomerRequired => 'اختر عميلًا';

  @override
  String get createVisitEmployeeRequired => 'اختر موظفًا';

  @override
  String get createVisitDateRequired => 'حدد تاريخ الزيارة';

  @override
  String get createVisitTooltip => 'زيارة جديدة';

  @override
  String get createVisitPickType => 'اختر نوع الزيارة';

  @override
  String get createVisitPickCustomer => 'اختر العميل';

  @override
  String get createVisitPickEmployee => 'اختر الموظف';

  @override
  String get visitsSearchHint => 'بحث باسم العميل…';

  @override
  String get pickerSearchHint => 'بحث…';

  @override
  String get pickerNoResults => 'لا توجد نتائج';

  @override
  String get groupToday => 'اليوم';

  @override
  String get groupYesterday => 'أمس';

  @override
  String get groupEarlierThisWeek => 'في وقت سابق من هذا الأسبوع';

  @override
  String get groupEarlier => 'سابقًا';

  @override
  String get groupTomorrow => 'غدًا';

  @override
  String get groupLaterThisWeek => 'لاحقًا هذا الأسبوع';

  @override
  String get groupUpcoming => 'القادمة';

  @override
  String get statsTotal => 'الإجمالي';

  @override
  String get statsActive => 'جارية';

  @override
  String get statsCompleted => 'مكتملة';

  @override
  String get statsPendingReview => 'بانتظار المراجعة';

  @override
  String get statsDone => 'منتهية';

  @override
  String get visitsHistoryTitle => 'سجل الزيارات';

  @override
  String get visitsHistoryEmpty => 'لا يوجد سجل زيارات';

  @override
  String get visitsListTitle => 'الزيارات';

  @override
  String get visitsFilterToday => 'اليوم';

  @override
  String get visitsFilterAll => 'الكل';

  @override
  String get filterStatusLabel => 'الحالة';

  @override
  String get filterStatusAll => 'الكل';

  @override
  String get filterStatusCompleted => 'مكتملة';

  @override
  String get filterStatusPendingReview => 'بانتظار المراجعة';

  @override
  String get filterStatusIncomplete => 'غير مكتملة';

  @override
  String get filterTimingLabel => 'التوقيت';

  @override
  String get filterTimingAll => 'الكل';

  @override
  String get filterTimingOnTime => 'في موعدها';

  @override
  String get filterTimingEarly => 'قبل الموعد';

  @override
  String get filterTimingOverdue => 'متأخرة';

  @override
  String get visitsTodayEmpty => 'لا توجد زيارات مجدولة لليوم';

  @override
  String get visitDetailTitle => 'تفاصيل الزيارة';

  @override
  String get visitDetailNotesSection => 'الملاحظات';

  @override
  String get visitDetailNoNotes => 'لا توجد ملاحظات';

  @override
  String get visitDetailEditNotes => 'تعديل الملاحظات';

  @override
  String get visitDetailMetaSection => 'بيانات الزيارة';

  @override
  String get visitDetailTimelineSection => 'التوقيتات';

  @override
  String get visitDetailVisitDate => 'تاريخ الزيارة';

  @override
  String get visitDetailVisitType => 'نوع الزيارة';

  @override
  String get visitDetailSaveChanges => 'حفظ التعديلات';

  @override
  String get visitDetailReadOnlyHint =>
      'هذه الحقول قابلة للتعديل من قِبل المدير فقط.';

  @override
  String get visitDetailNotesEditableHint =>
      'يمكنك إضافة ملاحظات أثناء تسجيل الوصول.';

  @override
  String get visitDetailSaved => 'تم حفظ التعديلات';

  @override
  String get visitDetailDelete => 'حذف الزيارة';

  @override
  String get visitDetailNotStartedYet => 'لم تبدأ الزيارة بعد';

  @override
  String get visitDetailNotEndedYet => 'لم تنتهِ الزيارة بعد';

  @override
  String get visitDetailOpenCheckInLocation => 'عرض موقع البدء على الخريطة';

  @override
  String get visitDetailOpenCheckOutLocation => 'عرض موقع الإنهاء على الخريطة';

  @override
  String get visitDetailTimelineLocationsSection => 'التوقيتات والمواقع';

  @override
  String get visitDetailEditCustomer => 'تغيير العميل';

  @override
  String get visitDetailEditEmployee => 'تغيير الموظف';

  @override
  String get visitDetailCustomer => 'العميل';

  @override
  String get visitDetailEmployee => 'الموظف';

  @override
  String get visitDetailStatusLabel => 'الحالة';

  @override
  String get visitDetailStateBadgeDraft => 'مسودة';

  @override
  String get visitDetailStateBadgeSubmitted => 'مُرسَلة';

  @override
  String get visitDetailStateBadgeUnderReview => 'قيد المراجعة';

  @override
  String get visitDetailStateBadgeDone => 'منتهية';

  @override
  String get confirmDeleteVisitTitle => 'حذف الزيارة';

  @override
  String get confirmDeleteVisitMessage =>
      'هل أنت متأكد من حذف هذه الزيارة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get visitDeletedSuccess => 'تم حذف الزيارة';

  @override
  String get roleManager => 'مدير';

  @override
  String get roleUser => 'مندوب ميداني';

  @override
  String get roleProjectManager => 'مدير مشاريع';

  @override
  String get roleAdmin => 'مسؤول النظام';

  @override
  String get roleManagerTitle => 'مدير الفريق';

  @override
  String get roleEmployeeTitle => 'مندوب ميداني';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileTabTitle => 'حسابي';

  @override
  String get visitsHistoryActiveBadge => 'جارية الآن';

  @override
  String get visitsScheduledLabel => 'الموعد';

  @override
  String get dashboardGreeting => 'صباح الخير';

  @override
  String get dashboardTodayProgress => 'إنجاز اليوم';

  @override
  String get dashboardFieldTime => 'وقت الميدان';

  @override
  String dashboardFieldHoursValue(String hours) {
    return '$hours س';
  }

  @override
  String get dashboardDaySchedule => 'جدول يومك';

  @override
  String get affordanceScheduled => 'اضغط لبدء الزيارة';

  @override
  String get affordanceActive => 'زيارة جارية الآن';

  @override
  String get affordanceReview => 'بانتظار مراجعة المدير';

  @override
  String get affordanceApproved => 'تم اعتمادها';

  @override
  String get affordanceRejected => 'مرفوضة — أعد الزيارة';

  @override
  String get analyticsTabTitle => 'التحليلات';

  @override
  String get analyticsOnTime => 'في الوقت المحدد';

  @override
  String get analyticsVisitsThisWeek => 'الزيارات هذا الأسبوع';

  @override
  String get analyticsKm => 'كم في الميدان';

  @override
  String get analyticsAvgDuration => 'متوسط مدة الزيارة';

  @override
  String get analyticsWeeklyTitle => 'الزيارات هذا الأسبوع';

  @override
  String get analyticsWeeklyCompare => 'مقارنة بالأسبوع الماضي';

  @override
  String get analyticsByEmployee => 'حسب الموظف';

  @override
  String analyticsVisitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count زيارة',
      many: '$count زيارةً',
      few: '$count زيارات',
      two: 'زيارتان',
      one: 'زيارة واحدة',
      zero: 'لا توجد زيارات',
    );
    return '$_temp0';
  }

  @override
  String get reviewTitle => 'مراجعة الزيارات';

  @override
  String reviewPendingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n زيارة بانتظار اعتمادك',
      many: '$n زيارةً بانتظار اعتمادك',
      few: '$n زيارات بانتظار اعتمادك',
      two: 'زيارتان بانتظار اعتمادك',
      one: 'زيارة واحدة بانتظار اعتمادك',
      zero: 'لا توجد زيارات بانتظار اعتمادك',
    );
    return '$_temp0';
  }

  @override
  String get reviewApprove => 'اعتماد';

  @override
  String get reviewReject => 'رفض';

  @override
  String get reviewEmpty => 'لا توجد زيارات بانتظار المراجعة';

  @override
  String get reviewApproved => 'تم اعتماد الزيارة';

  @override
  String get reviewRejected => 'تم رفض الزيارة';

  @override
  String get reviewOutOfRangeBanner =>
      'خارج النطاق · سُجّلت خارج نطاق الموقع المعتمد';

  @override
  String get routeTabTitle => 'مسار اليوم';

  @override
  String get routeStops => 'المحطات';

  @override
  String routeStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محطة',
      many: '$count محطة',
      few: '$count محطات',
      two: 'محطتان',
      one: 'محطة واحدة',
      zero: 'لا توجد محطات',
    );
    return '$_temp0';
  }

  @override
  String get routeTotalDistance => 'إجمالي المسافة';

  @override
  String get routeNextStop => 'المحطة التالية';

  @override
  String get routeStartPoint => 'نقطة البداية';

  @override
  String routeDriveMinutes(int n) {
    return '$n د قيادة';
  }

  @override
  String get routeStartNav => 'بدء الملاحة';

  @override
  String get routeEmpty => 'لا توجد محطات في مسار اليوم';

  @override
  String get reportTitle => 'تقرير الزيارة';

  @override
  String get reportOutcome => 'نتيجة الزيارة';

  @override
  String get reportOutcomeDone => 'تمّت بنجاح';

  @override
  String get reportOutcomePostponed => 'مؤجلة';

  @override
  String get reportOutcomeAbsent => 'العميل غير موجود';

  @override
  String get reportNotes => 'ملاحظات';

  @override
  String get reportNotesHint => 'اكتب ملخص الزيارة وأهم الملاحظات...';

  @override
  String get reportPhoto => 'صورة إثبات';

  @override
  String get reportAddPhoto => 'إضافة صورة';

  @override
  String get reportSignature => 'توقيع العميل';

  @override
  String get reportSignHere => 'وقّع هنا';

  @override
  String get reportClear => 'مسح';

  @override
  String get reportSubmit => 'إنهاء وحفظ التقرير';

  @override
  String get createVisitTitle => 'إنشاء زيارة جديدة';

  @override
  String get createVisitSectionCustomer => 'العميل';

  @override
  String get createVisitSectionEmployee => 'المندوب الميداني';

  @override
  String get createVisitSectionType => 'نوع الزيارة';

  @override
  String get createVisitSectionDate => 'موعد الزيارة';

  @override
  String get createVisitChange => 'تغيير';

  @override
  String get createVisitSubmit => 'إنشاء الزيارة';

  @override
  String get visitsHistoryCompletedBadge => 'مكتملة';

  @override
  String get visitsHistoryIncompleteBadge => 'غير مكتملة';

  @override
  String get visitsHistoryOverdueBadge => 'متأخرة';

  @override
  String get visitDetailOverdueHint =>
      'انقضى موعد الزيارة ولم تكتمل بعد. أعد جدولتها أو تابعها.';

  @override
  String get visitExecutedOnTime => 'نُفِّذت في موعدها';

  @override
  String visitExecutedEarly(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'نُفِّذت قبل موعدها بـ$days يوم',
      many: 'نُفِّذت قبل موعدها بـ$days يومًا',
      few: 'نُفِّذت قبل موعدها بـ$days أيام',
      two: 'نُفِّذت قبل موعدها بيومين',
      one: 'نُفِّذت قبل موعدها بيوم واحد',
    );
    return '$_temp0';
  }

  @override
  String visitExecutedLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'نُفِّذت بعد موعدها بـ$days يوم',
      many: 'نُفِّذت بعد موعدها بـ$days يومًا',
      few: 'نُفِّذت بعد موعدها بـ$days أيام',
      two: 'نُفِّذت بعد موعدها بيومين',
      one: 'نُفِّذت بعد موعدها بيوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get visitsHistoryRunning => 'جارية';

  @override
  String get timelineCheckIn => 'وصول';

  @override
  String get timelineCheckOut => 'مغادرة';

  @override
  String timelineDuration(String value) {
    return '$value د';
  }

  @override
  String get visitRangeInRange => 'ضمن النطاق';

  @override
  String get visitRangeOutOfRange => 'خارج النطاق';

  @override
  String get statusScheduled => 'مجدولة';

  @override
  String get statusActive => 'جارية الآن';

  @override
  String get statusReview => 'بانتظار المراجعة';

  @override
  String get statusApproved => 'معتمدة';

  @override
  String get statusRejected => 'مرفوضة';

  @override
  String get visitDetailScheduledTimeLabel => 'موعد الزيارة';

  @override
  String get visitDetailInRange => 'أنت داخل نطاق العميل';

  @override
  String get visitDetailOutRange => 'أنت خارج نطاق العميل';

  @override
  String visitDetailRangeMeta(String distance, String radius) {
    return 'يبعد $distance م · نطاق التسجيل $radius م';
  }

  @override
  String get visitDetailOutRangeHint =>
      'اقترب أكثر من موقع العميل لبدء الزيارة.';

  @override
  String get visitDetailCheckInTitle => 'تسجيل بدء الزيارة';

  @override
  String get visitDetailCheckInInRangeSub => 'أنت داخل النطاق';

  @override
  String get visitDetailCheckInLocatingSub => 'جارٍ تحديد موقعك…';

  @override
  String get visitDetailCheckInOverride => 'تسجيل خارج النطاق';

  @override
  String get visitDetailElapsedLabel => 'الوقت المنقضي';

  @override
  String visitDetailStartedAt(String time) {
    return 'بدء الزيارة $time';
  }

  @override
  String get visitDetailCheckOutTitle => 'تسجيل إنهاء الزيارة';

  @override
  String get visitDetailCheckOutSub => 'سيتم التقاط موقعك عند الإنهاء';

  @override
  String get visitDetailOnTime => 'تمّت في موعدها';

  @override
  String get visitDetailDurationLabel => 'مدة الزيارة';

  @override
  String get timelineCreated => 'تم إنشاء الزيارة';

  @override
  String get visitShowLocation => 'عرض موقع العميل';

  @override
  String get visitDetailCustomerLocationSection => 'موقع العميل';

  @override
  String get visitDetailNavigate => 'عرض موقع العميل على الخريطة';

  @override
  String get visitDetailNoCustomerLocation =>
      'لا يوجد موقع محفوظ لهذا العميل. اطلب من مديرك إضافته.';

  @override
  String visitDetailCheckInStartedAt(String customer) {
    return 'بدأت الزيارة عند $customer — تم تسجيل موقعك';
  }

  @override
  String get visitLocationDialogTitle => 'موقع تسجيل الوصول';

  @override
  String get visitLocationCustomer => 'مكتب العميل';

  @override
  String get visitLocationCheckIn => 'نقطة الوصول';

  @override
  String get visitLocationCheckOut => 'نقطة المغادرة';

  @override
  String get visitLocationNotAvailable =>
      'لا يوجد موقع محفوظ لهذا العميل. اطلب من مديرك إضافته.';

  @override
  String get offlineNoQueue =>
      'أنت غير متصل بالإنترنت — ستُحفظ إجراءاتك على الجهاز وتُرسَل عند عودة الاتصال.';

  @override
  String offlineWithQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'غير متصل — $count إجراء بانتظار المزامنة',
      many: 'غير متصل — $count إجراءً بانتظار المزامنة',
      few: 'غير متصل — $count إجراءات بانتظار المزامنة',
      two: 'غير متصل — إجراءان بانتظار المزامنة',
      one: 'غير متصل — إجراء واحد بانتظار المزامنة',
    );
    return '$_temp0';
  }

  @override
  String offlineSyncing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'جارٍ مزامنة $count إجراء معلّق…',
      many: 'جارٍ مزامنة $count إجراءً معلّقًا…',
      few: 'جارٍ مزامنة $count إجراءات معلّقة…',
      two: 'جارٍ مزامنة إجراءين معلّقين…',
      one: 'جارٍ مزامنة إجراء واحد معلّق…',
    );
    return '$_temp0';
  }

  @override
  String offlinePendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'لا يزال $count إجراء في الانتظار — تحقّق من اتصالك ثم أعد المحاولة.',
      many:
          'لا يزال $count إجراءً في الانتظار — تحقّق من اتصالك ثم أعد المحاولة.',
      few:
          'لا تزال $count إجراءات في الانتظار — تحقّق من اتصالك ثم أعد المحاولة.',
      two: 'لا يزال إجراءان في الانتظار — تحقّق من اتصالك ثم أعد المحاولة.',
      one: 'لا يزال إجراء واحد في الانتظار — تحقّق من اتصالك ثم أعد المحاولة.',
    );
    return '$_temp0';
  }

  @override
  String get offlineCheckInQueued =>
      'حُفظ على الجهاز — ستتم المزامنة عند عودة الاتصال';

  @override
  String get dashboardTabTitle => 'لوحة المتابعة';

  @override
  String get dashboardKpiOverdue => 'متأخرة';

  @override
  String get dashboardKpiPending => 'بانتظار المراجعة';

  @override
  String get dashboardKpiToday => 'زيارات اليوم';

  @override
  String get dashboardKpiActive => 'جارية الآن';

  @override
  String get dashboardActiveOnMapTitle => 'الموظفون في الميدان';

  @override
  String get dashboardActiveEmpty => 'لا يوجد موظفون في زيارة حاليًا';

  @override
  String dashboardActiveMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+ $count موظف آخر',
      many: '+ $count موظفًا آخر',
      few: '+ $count موظفين آخرين',
      two: '+ موظفان آخران',
      one: '+ موظف آخر',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTopCustomers => 'أكثر العملاء زيارة';

  @override
  String get dashboardTopEmployees => 'أفضل الموظفين (الزيارات المكتملة)';

  @override
  String get dashboardNoData => 'لا توجد بيانات كافية بعد';

  @override
  String get visitsTabTitle => 'الزيارات';

  @override
  String get homeTabCustomers => 'العملاء';

  @override
  String get homeTabActive => 'الجارية';

  @override
  String get homeTabHistory => 'السجل';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsServer => 'تغيير الخادم';

  @override
  String get settingsServerNone => 'غير محدد';

  @override
  String get settingsAbout => 'حول التطبيق';

  @override
  String get settingsVersion => 'الإصدار';

  @override
  String settingsVersionValue(String version) {
    return 'الإصدار $version';
  }

  @override
  String profileBuildVersion(String version, String build) {
    return '$version ($build)';
  }

  @override
  String get settingsEditProfile => 'تعديل الملف الشخصي';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsNotificationsSub => 'تنبيهات الزيارات والتذكيرات';

  @override
  String get settingsLastSync => 'آخر مزامنة';

  @override
  String get settingsSyncNow => 'مزامنة الآن';

  @override
  String get settingsSynced => 'تمت المزامنة';

  @override
  String get settingsSyncNothingPending => 'لا يوجد شيء في الانتظار';

  @override
  String settingsSyncPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إجراء بانتظار المزامنة',
      many: '$count إجراءً بانتظار المزامنة',
      few: '$count إجراءات بانتظار المزامنة',
      two: 'إجراءان بانتظار المزامنة',
      one: 'إجراء واحد بانتظار المزامنة',
    );
    return '$_temp0';
  }

  @override
  String get settingsHelp => 'المساعدة والدعم';

  @override
  String get confirmLogoutTitle => 'تسجيل الخروج';

  @override
  String get confirmLogoutMessage => 'هل تريد تسجيل الخروج من التطبيق؟';

  @override
  String get confirmExitTitle => 'الخروج من التطبيق';

  @override
  String get confirmExitMessage => 'هل تريد الخروج من التطبيق؟';

  @override
  String get weekdayShortSun => 'أحد';

  @override
  String get weekdayShortMon => 'إثنين';

  @override
  String get weekdayShortTue => 'ثلاثاء';

  @override
  String get weekdayShortWed => 'أربعاء';

  @override
  String get weekdayShortThu => 'خميس';

  @override
  String get weekdayShortFri => 'جمعة';

  @override
  String get weekdayShortSat => 'سبت';

  @override
  String get aboutAppName => 'زيارات العملاء';

  @override
  String get aboutLegalese => '© 2026 Digital Harbor';

  @override
  String get aboutFooter => 'زيارات العملاء · Digital Harbor © 2026';

  @override
  String get wfStateDraft => 'مسودة';

  @override
  String get wfStateSubmitted => 'مُرسَلة';

  @override
  String get wfStateWaitingParticipant => 'بانتظار اعتماد مديري المشاركين';

  @override
  String get wfStateWaitingManager => 'بانتظار اعتماد المدير';

  @override
  String get wfStateEscalated => 'مُصعَّدة';

  @override
  String get wfStateApproved => 'معتمدة';

  @override
  String get wfStateRejected => 'مرفوضة';

  @override
  String get wfStateCancelled => 'ملغاة';

  @override
  String get wfStateReschedule => 'طلب إعادة جدولة';

  @override
  String get wfStateInProgress => 'جارية';

  @override
  String get wfStateDone => 'منتهية';

  @override
  String get wfStateUnknown => '—';

  @override
  String get wfScopeMine => 'زياراتي';

  @override
  String get wfScopePending => 'بانتظار الاعتماد';

  @override
  String get wfScopeTeam => 'الفريق';

  @override
  String get wfScopeEscalated => 'المُصعَّدة';

  @override
  String get wfActionSubmit => 'إرسال للاعتماد';

  @override
  String get wfActionApprove => 'اعتماد';

  @override
  String get wfActionReject => 'رفض';

  @override
  String get wfActionReschedule => 'طلب إعادة جدولة';

  @override
  String get wfActionStart => 'بدء الزيارة';

  @override
  String get wfApproveWaitsForAttendees =>
      'يُتاح الاعتماد بعد اعتماد جميع المشاركين.';

  @override
  String get wfActionEnd => 'إنهاء الزيارة';

  @override
  String get wfActionCancel => 'إلغاء الزيارة';

  @override
  String get wfActionAddParticipant => 'إضافة مشارك';

  @override
  String get wfActionAddAttachment => 'إضافة مرفق';

  @override
  String wfActionAddAttachmentCount(int count) {
    return 'إضافة مرفق ($count)';
  }

  @override
  String get wfTypeProject => 'مشروع';

  @override
  String get wfTypeOpportunity => 'فرصة';

  @override
  String get wfFieldType => 'نوع الزيارة';

  @override
  String get wfFieldProject => 'المشروع';

  @override
  String get wfFieldOpportunity => 'الفرصة';

  @override
  String get wfFieldCustomer => 'العميل';

  @override
  String wfLinkedCustomer(String name) {
    return 'العميل: $name';
  }

  @override
  String wfOptionalField(String label) {
    return '$label (اختياري)';
  }

  @override
  String wfLabelColon(String label) {
    return '$label:';
  }

  @override
  String get wfFieldSchedule => 'تاريخ ووقت الزيارة';

  @override
  String get wfFieldPurpose => 'الغرض';

  @override
  String get wfFieldLocation => 'الموقع';

  @override
  String get wfFieldOutcome => 'النتيجة';

  @override
  String get wfFieldResponsible => 'الموظف المسؤول';

  @override
  String get wfFieldParticipants => 'مشاركون إضافيون';

  @override
  String get wfFieldDirectManager => 'المدير المباشر';

  @override
  String get wfFieldHigherManager => 'المدير الأعلى';

  @override
  String get wfPickProject => 'اختر مشروعًا';

  @override
  String get wfPickOpportunity => 'اختر فرصة';

  @override
  String get wfPickEmployee => 'اختر موظفًا';

  @override
  String get wfSelfLabel => 'أنا';

  @override
  String get wfPlanForMyself => 'خطّط لها لنفسي';

  @override
  String get wfPurposeRequired => 'الغرض مطلوب';

  @override
  String get wfOutcomeRequired => 'النتيجة مطلوبة لإنهاء الزيارة';

  @override
  String get wfRejectReason => 'سبب الرفض';

  @override
  String get wfRejectReasonHint => 'اكتب سبب رفض الزيارة…';

  @override
  String get wfReasonRequired => 'السبب مطلوب';

  @override
  String get wfCreateTitle => 'زيارة جديدة';

  @override
  String get wfCreated => 'تم إنشاء الزيارة';

  @override
  String wfParticipantsNotAdded(String reason) {
    return 'أُنشئت الزيارة، لكن لم يُضَف المشاركون. $reason اضغط «إعادة إضافة المشاركين» للمحاولة مرة أخرى، أو افتح الزيارة دونهم.';
  }

  @override
  String get wfRetryAddParticipants => 'إعادة إضافة المشاركين';

  @override
  String get wfOpenCreatedVisit => 'فتح الزيارة';

  @override
  String get wfSubmitted => 'تم الإرسال للاعتماد';

  @override
  String get wfApproved => 'تم اعتماد الزيارة';

  @override
  String get wfRejected => 'تم رفض الزيارة';

  @override
  String get wfStarted => 'بدأت الزيارة';

  @override
  String get wfEnded => 'اكتملت الزيارة';

  @override
  String get wfRescheduled => 'تم طلب إعادة الجدولة';

  @override
  String get wfCancelled => 'تم إلغاء الزيارة';

  @override
  String get wfAttachmentAdded => 'تمت إضافة المرفق';

  @override
  String wfAttachmentTooLarge(String size, String limit) {
    return 'حجم هذا الملف $size، وهو أكبر من الحد المسموح به ($limit). اختر ملفًا أصغر أو اضغطه، ثم أعد المحاولة.';
  }

  @override
  String get wfAttachmentUnreadable =>
      'تعذّرت قراءة الملف المحدد. اختره مرة أخرى أو اختر ملفًا آخر.';

  @override
  String get wfCameraUnavailable =>
      'تعذّر فتح الكاميرا. أغلق أي تطبيق آخر يستخدمها، ثم أعد المحاولة.';

  @override
  String get wfFilePickerUnavailable =>
      'تعذّر فتح ملفاتك. أعد المحاولة، وإذا تكرّر الخطأ فأعد تشغيل التطبيق.';

  @override
  String get wfCameraAccessTitle => 'يلزم السماح باستخدام الكاميرا';

  @override
  String get wfCameraAccessMessage =>
      'لا يملك التطبيق إذنًا لاستخدام الكاميرا. اسمح له بالوصول إلى الكاميرا من الإعدادات، ثم أعد المحاولة.';

  @override
  String get wfFilesAccessTitle => 'يلزم السماح بالوصول إلى الصور والملفات';

  @override
  String get wfFilesAccessMessage =>
      'لا يملك التطبيق إذنًا لفتح الصور والملفات. اسمح له بالوصول من الإعدادات، ثم أعد المحاولة.';

  @override
  String get wfOpenSettings => 'فتح الإعدادات';

  @override
  String get wfParticipantApproved => 'تم اعتماد المشارك';

  @override
  String get wfParticipantRejected => 'تم رفض المشارك';

  @override
  String get wfParticipantsAdded => 'تمت إضافة المشاركين';

  @override
  String get wfApprovalHistory => 'سجل الاعتماد';

  @override
  String get wfSubmittedOn => 'أُرسلت في';

  @override
  String get wfApprovedByOn => 'اعتمدها';

  @override
  String get wfRejectedByOn => 'رفضها';

  @override
  String get wfReason => 'السبب';

  @override
  String get wfEscalatedBadge => 'مُصعَّدة';

  @override
  String get wfParticipantsSection => 'المشاركون';

  @override
  String get wfParticipantPending => 'قيد الانتظار';

  @override
  String get wfParticipantApprovedState => 'مُعتمَد';

  @override
  String get wfParticipantRejectedState => 'مرفوض';

  @override
  String get wfNoParticipants => 'لا يوجد مشاركون إضافيون';

  @override
  String get wfUnknownEmployee => 'موظف غير معروف';

  @override
  String get wfApproveParticipant => 'اعتماد';

  @override
  String get wfRejectParticipant => 'رفض';

  @override
  String get wfEmptyMine => 'لا توجد لديك زيارات بعد';

  @override
  String get wfEmptyPending => 'لا توجد زيارات بانتظار اعتمادك';

  @override
  String get wfEmptyTeam => 'لا توجد زيارات للفريق';

  @override
  String get wfEmptyEscalated => 'لا توجد زيارات مُصعَّدة';

  @override
  String get wfSearchHint => 'ابحث بالعميل أو المرجع أو الغرض…';

  @override
  String get wfSearchNoMatch => 'لا توجد زيارات مطابقة لبحثك';

  @override
  String get wfFilterNoMatch =>
      'لا توجد زيارات تطابق عامل التصفية هذا. أزل عامل التصفية لعرض جميع زياراتك.';

  @override
  String get wfClearFilter => 'إزالة عامل التصفية';

  @override
  String get wfRescheduleTitle => 'طلب إعادة جدولة';

  @override
  String get wfRescheduleNoChanges =>
      'لم يتغيّر شيء. غيّر التاريخ أو الغرض أو الموقع قبل إرسال الطلب.';

  @override
  String get wfListTitle => 'الزيارات';

  @override
  String get wfDetailTitle => 'زيارة';

  @override
  String get wfStartLocationCaptured =>
      'سيُسجَّل موقعك الحالي عبر نظام تحديد المواقع';

  @override
  String get wfConfirmCancelTitle => 'إلغاء الزيارة';

  @override
  String get wfConfirmCancelMessage => 'هل أنت متأكد من إلغاء هذه الزيارة؟';

  @override
  String get wfScheduledLabel => 'مجدولة';

  @override
  String get wfStartedLabel => 'بدأت';

  @override
  String get wfEndedLabel => 'انتهت';

  @override
  String get wfFieldStartLocation => 'موقع البدء';

  @override
  String get wfFieldEndLocation => 'موقع الإنهاء';

  @override
  String get wfDurationLabel => 'المدة';

  @override
  String get wfSectionVisitInfo => 'معلومات الزيارة';

  @override
  String get wfSectionApproval => 'الفريق والاعتماد';

  @override
  String get wfSectionExecution => 'التنفيذ';

  @override
  String get wfSectionAttachments => 'المرفقات';

  @override
  String get wfOpenInMaps => 'فتح في الخرائط';

  @override
  String wfRangeDistance(String distance) {
    return 'على بُعد $distance';
  }

  @override
  String wfRangeRadius(String radius) {
    return 'نطاق التسجيل $radius';
  }

  @override
  String get wfHoursShort => 'س';

  @override
  String get wfMinutesShort => 'د';

  @override
  String get wfDaysShort => 'ي';

  @override
  String get wfShortVisitHint => 'زيارة قصيرة';

  @override
  String get wfNotificationsTitle => 'الإشعارات';

  @override
  String get wfNotificationsEmpty => 'لا توجد مهام مطلوبة منك حاليًا';

  @override
  String wfNotificationsDue(String date) {
    return 'الموعد $date';
  }

  @override
  String get wfActionTakePhoto => 'التقاط صورة';

  @override
  String get wfMockLocationTitle => 'تم رصد موقع مزيّف';

  @override
  String get wfMockLocationMessage =>
      'يُبلغ جهازك عن موقع وهمي (مزيَّف)، وسيُحال ذلك للمراجعة. هل تريد المتابعة على أي حال؟';

  @override
  String get wfQueuedOffline =>
      'حُفظ دون اتصال — ستتم مزامنته فور عودة الاتصال بالإنترنت';

  @override
  String get wfMockFlagBannerTitle => 'سُجِّل موقع مزيَّف في هذه الزيارة';

  @override
  String get wfMockFlagBannerBody =>
      'أبلغ الجهاز عن موقع وهمي (مزيَّف) عند بدء الزيارة أو إنهائها. راجِعها جيدًا قبل اعتمادها.';

  @override
  String get trailSectionTitle => 'المسار المقطوع';

  @override
  String get trailMapTitle => 'مسار التتبّع';

  @override
  String get trailEmpty => 'لم تُسجَّل أي نقاط بعد';

  @override
  String get trailEmptyRunning => 'جارٍ تسجيل مسارك — يظهر الخط أثناء تحركك';

  @override
  String get trailEmptyFinished => 'لم تُسجَّل أي نقاط خلال هذه الزيارة';

  @override
  String get trailLive => 'جارٍ التسجيل';

  @override
  String trailPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      many: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا توجد نقاط',
    );
    return '$_temp0';
  }

  @override
  String get trailDistance => 'المسافة';

  @override
  String trailDistanceKm(String value) {
    return '$value كم';
  }

  @override
  String get trailAvgSpeed => 'متوسط السرعة';

  @override
  String trailSpeedKmh(String value) {
    return '$value كم/س';
  }

  @override
  String get trailLastFix => 'آخر موقع';

  @override
  String get trailFirstFix => 'أول موقع';

  @override
  String get trailOpenFull => 'عرض المسار كاملًا';

  @override
  String get trailPointStart => 'البداية';

  @override
  String get trailPointEnd => 'النهاية';

  @override
  String get trailPointTrack => 'أثناء الطريق';

  @override
  String get trailPointManual => 'مضافة يدويًا';

  @override
  String trailAccuracy(String meters) {
    return '±$meters م';
  }

  @override
  String trailPendingUploads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة بانتظار الرفع',
      many: '$count نقطةً بانتظار الرفع',
      few: '$count نقاط بانتظار الرفع',
      two: 'نقطتان بانتظار الرفع',
      one: 'نقطة واحدة بانتظار الرفع',
    );
    return '$_temp0';
  }

  @override
  String get trailUploadNow => 'رفع الآن';

  @override
  String get trailUploadDone => 'تم رفع النقاط المسجّلة';

  @override
  String trailUploadStillPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ما زالت $count نقطة بانتظار الرفع. تحقّق من اتصالك بالإنترنت، وستُرفع تلقائيًا عند عودة الاتصال.',
      many:
          'ما زالت $count نقطةً بانتظار الرفع. تحقّق من اتصالك بالإنترنت، وستُرفع تلقائيًا عند عودة الاتصال.',
      few:
          'ما زالت $count نقاط بانتظار الرفع. تحقّق من اتصالك بالإنترنت، وستُرفع تلقائيًا عند عودة الاتصال.',
      two:
          'ما زالت نقطتان بانتظار الرفع. تحقّق من اتصالك بالإنترنت، وستُرفعان تلقائيًا عند عودة الاتصال.',
      one:
          'ما زالت نقطة واحدة بانتظار الرفع. تحقّق من اتصالك بالإنترنت، وستُرفع تلقائيًا عند عودة الاتصال.',
      zero: 'لا توجد نقاط بانتظار الرفع.',
    );
    return '$_temp0';
  }

  @override
  String trailPointsDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'تعذّر حفظ $count نقطة مسجَّلة، لذا تظهر انقطاعات في مسارك. لا يلزمك أي إجراء، وأبلغ مديرك إذا بدا المسار غير صحيح.',
      many:
          'تعذّر حفظ $count نقطةً مسجَّلة، لذا تظهر انقطاعات في مسارك. لا يلزمك أي إجراء، وأبلغ مديرك إذا بدا المسار غير صحيح.',
      few:
          'تعذّر حفظ $count نقاط مسجَّلة، لذا تظهر انقطاعات في مسارك. لا يلزمك أي إجراء، وأبلغ مديرك إذا بدا المسار غير صحيح.',
      two:
          'تعذّر حفظ نقطتين مسجَّلتين، لذا تظهر انقطاعات في مسارك. لا يلزمك أي إجراء، وأبلغ مديرك إذا بدا المسار غير صحيح.',
      one:
          'تعذّر حفظ نقطة مسجَّلة واحدة، لذا يظهر انقطاع في مسارك. لا يلزمك أي إجراء، وأبلغ مديرك إذا بدا المسار غير صحيح.',
    );
    return '$_temp0';
  }

  @override
  String get trailPointsList => 'النقاط';

  @override
  String get trailFitRoute => 'احتواء المسار في الشاشة';

  @override
  String get visitTrackingRequired =>
      'لا يمكن بدء الزيارة إلا مع تسجيل مسارها. اضغط «بدء الزيارة» مجددًا ووافق على تسجيل المسار للمتابعة.';

  @override
  String get visitTrackingNotificationTitle => 'تتبع الزيارة نشط';

  @override
  String get visitTrackingNotificationText => 'يجري تسجيل مسار زيارتك';

  @override
  String get visitTrackingDisclosureTitle => 'تسجيل مسار الزيارة';

  @override
  String get visitTrackingDisclosureBody =>
      'أثناء تنفيذ زيارة عميل، يجمع تطبيق الزيارات الموقع الدقيق لهذا الجهاز — حتى والتطبيق في الخلفية أو غير مستخدَم، وأثناء قفل الشاشة — لتسجيل مسار تلك الزيارة لصالح جهة عملك.';

  @override
  String get visitTrackingDisclosureStops =>
      'يبدأ التسجيل فقط بعد أن تضغط «بدء الزيارة» وتبدأ الزيارة فعليًا، ويتوقف فور إنهاء الزيارة أو تسجيل الخروج. لا يُسجَّل أي موقع قبل بدء الزيارة ولا بين الزيارات ولا بعد انتهائها.';

  @override
  String get visitTrackingDisclosureStorage =>
      'تبقى النقاط المسجَّلة على هذا الهاتف حتى تصل إلى خادم شركتك، بما فيها النقاط المسجَّلة دون اتصال. ولرسم مسار الزيارة على الطرق قد تُرسَل نقاطها إلى خدمة مطابقة الخرائط الخاصة بشركتك.';

  @override
  String get visitTrackingDisclosureAndroid =>
      'يبقى إشعار ظاهرًا طوال مدة تسجيل الزيارة.';

  @override
  String get visitTrackingDisclosureIos =>
      'سيطلب نظام iOS الإذن بالوصول إلى الموقع، ويكفي خيار «أثناء استخدام التطبيق». ويُظهر iOS مؤشر الموقع طوال مدة تسجيل الزيارة.';

  @override
  String get visitTrackingDisclosureAgree => 'أوافق وأتابع';

  @override
  String get visitTrackingDisclosureDecline => 'ليس الآن';

  @override
  String get trailStatusRecording => 'يجري تسجيل مسار الزيارة';

  @override
  String get trailStatusWaitingSync =>
      'يبدأ تسجيل المسار بعد وصول الزيارة إلى الخادم';

  @override
  String get trailStatusNoConsent =>
      'لا يُسجَّل المسار — يلزم الحصول على موافقتك';

  @override
  String get trailStatusNoPermission =>
      'توقّف تسجيل المسار — اسمح بالوصول إلى الموقع لاستئنافه';

  @override
  String get trailStatusUnavailable =>
      'تعذّر بدء تسجيل المسار — اضغط «استئناف»';

  @override
  String get trailStatusResume => 'استئناف';

  @override
  String get routeRecordedTrails => 'المسارات المسجّلة اليوم';

  @override
  String routeTrailSummary(int points, String km) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points نقطة',
      many: '$points نقطةً',
      few: '$points نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا توجد نقاط',
    );
    return '$_temp0 · $km كم';
  }

  @override
  String routePointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      many: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا توجد نقاط',
    );
    return '$_temp0';
  }

  @override
  String get routeTrailsPartial =>
      'تعذّر تحميل مسارات بعض الزيارات. اسحب للأسفل لإعادة المحاولة.';

  @override
  String routeTrailsLoadFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر تحميل مسارات $count زيارة.',
      many: 'تعذّر تحميل مسارات $count زيارة.',
      few: 'تعذّر تحميل مسارات $count زيارات.',
      two: 'تعذّر تحميل مساري زيارتين.',
      one: 'تعذّر تحميل مسار زيارة واحدة.',
      zero: 'تعذّر تحميل مسارات الزيارات.',
    );
    return '$_temp0 تحقّق من الاتصال، ثم اضغط «إعادة المحاولة».';
  }

  @override
  String get routeLineRoads => 'الطرق';

  @override
  String get routeLineGps => 'المسار الخام';

  @override
  String get routeLineMatching => 'جارٍ المطابقة مع الطرق…';

  @override
  String get routeLineUnmatched =>
      'تعذّرت المطابقة مع الطرق — يُعرض المسار الخام';
}
