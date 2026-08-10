// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Visits';

  @override
  String get appTagline => 'تابع زياراتك الميدانية بدقة';

  @override
  String get commonRequired => 'مطلوب';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonLoading => 'جاري التحميل…';

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
  String get unitMinShort => 'د';

  @override
  String get relativeNow => 'الآن';

  @override
  String relativeMinutesAgo(int count) {
    return 'من $count د';
  }

  @override
  String relativeHoursAgo(int count) {
    return 'من $count س';
  }

  @override
  String relativeDaysAgo(int count) {
    return 'من $count يوم';
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
  String get commonBack => 'رجوع';

  @override
  String get commonContinue => 'متابعة';

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
      'أدخل رابطاً صحيحاً (مثال: https://your-company.odoo.com)';

  @override
  String get serverSetupHelp =>
      'اسأل مسؤول النظام إذا كنت لا تعرف عنوان الخادم.';

  @override
  String get serverSetupDatabaseLabel => 'اسم قاعدة البيانات';

  @override
  String get serverSetupDatabaseHint => 'مثال: company-main';

  @override
  String get serverSetupDatabasePrompt =>
      'تعذّر اكتشاف قاعدة البيانات تلقائياً. أدخل اسمها (اسأل مسؤول النظام).';

  @override
  String get serverSetupChecking => 'جاري الاتصال…';

  @override
  String get serverSetupDetectDb => 'اكتشاف الداتا بيز';

  @override
  String get serverSetupDetecting => 'جاري الاكتشاف…';

  @override
  String serverSetupDetected(String db) {
    return 'تم اكتشاف الداتا بيز: $db';
  }

  @override
  String get serverSetupDetectFailed =>
      'تعذّر اكتشاف الداتا بيز — اكتبها يدويًا';

  @override
  String get loginChangeServer => 'تغيير الخادم';

  @override
  String get loginTitle => 'Visits';

  @override
  String get loginSubtitle => 'سجّل دخولك لبدء يومك الميداني';

  @override
  String get loginWelcomeBack => 'أهلاً بعودتك';

  @override
  String get loginRoleLabel => 'الدخول بصفتك';

  @override
  String get loginUsername => 'البريد / المستخدم';

  @override
  String get loginPassword => 'كلمة السر';

  @override
  String get loginSubmit => 'تسجيل الدخول';

  @override
  String get loginRememberMe => 'تذكّرني';

  @override
  String get loginForgotPassword => 'نسيت كلمة السر؟';

  @override
  String get loginForgotPasswordTitle => 'إعادة تعيين كلمة السر';

  @override
  String get loginForgotPasswordBody =>
      'إعادة تعيين كلمة السر تتم عن طريق المسؤول. من فضلك تواصل مع مسؤول النظام لإعادة تعيين كلمة السر.';

  @override
  String get loginSecureFooter => 'دخول آمن · Digital Harbor';

  @override
  String get errInvalidCredentials => 'بيانات الدخول غير صحيحة';

  @override
  String get errAuthRequired => 'يجب تسجيل الدخول';

  @override
  String get errPermissionDenied => 'ليس لديك صلاحية لهذا الإجراء';

  @override
  String get errValidation => 'بيانات غير صحيحة — راجعها وحاول مرة أخرى';

  @override
  String get errNotFound => 'العنصر غير موجود';

  @override
  String get errLocationRequired => 'هذا العميل ليس له إحداثيات مسجّلة';

  @override
  String get errServerError => 'خطأ في الخادم — حاول لاحقاً';

  @override
  String get errNetworkTimeout => 'انتهت مهلة الاتصال';

  @override
  String get errNetworkUnreachable => 'تعذر الاتصال بالخادم';

  @override
  String get errNetworkUnknown => 'حدث خطأ في الشبكة';

  @override
  String get errLocationPermission => 'فعّل خدمة الموقع وامنح الإذن للتطبيق';

  @override
  String get errLocationNeededForVisit =>
      'لازم نسجّل موقعك عشان نوثّق الزيارة. فعّل خدمة الموقع واسمح للتطبيق يستخدمها، وبعدين جرّب تاني.';

  @override
  String get errLocationUnavailable =>
      'مش قادرين نحدد موقعك دلوقتي. اتحرك لمكان مكشوف وجرّب تاني.';

  @override
  String get errUnknown =>
      'حصل خطأ من ناحيتنا. جرّب تاني — ولو الموضوع اتكرر، ابعت صورة للشاشة لمسؤول النظام.';

  @override
  String get errSessionRestoreFailed =>
      'مقدرناش نفتح جلستك المحفوظة. سجّل دخولك تاني عشان تكمّل.';

  @override
  String get errProfileIncomplete =>
      'مقدرناش نحمّل صلاحياتك، فأزرار الزيارة مخفية. اعمل تسجيل خروج ودخول تاني — ولو الموضوع فضل، اطلب من مسؤول النظام يراجع دورك في الزيارات.';

  @override
  String get liveLocationUnsupported =>
      'مشاركة الموقع المباشر مش متاحة على الخادم ده — اطلب من مسؤول النظام يفعّلها.';

  @override
  String get liveLocationPermissionOff =>
      'مشاركة الموقع مقفولة، فمديرك مش شايفك على الخريطة. اسمح بالوصول للموقع عشان ترجّعها.';

  @override
  String get liveLocationPingFailed =>
      'موقعك مش بيوصل للخادم، فمكانك على الخريطة قديم.';

  @override
  String get pushChannelName => 'تحديثات الزيارات';

  @override
  String get pushChannelDescription =>
      'الموافقات وإعادة الجدولة وتغييرات حالة زياراتك.';

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
    return 'التحديث اللي عملته وإنت أوفلاين مااتحفظش: $reason افتح الزيارة وسجّله تاني.';
  }

  @override
  String get errConflict =>
      'الزيارة دي اتغيّرت من مكان تاني. اسحب لتحت عشان تحدّث وتشوف حالتها الحالية قبل ما تجرّب تاني.';

  @override
  String get errInsecureConnection =>
      'مقدرناش نعمل اتصال آمن بالخادم. شهادة الأمان بتاعته مش موثوقة — راجع عنوان الخادم مع مسؤول النظام.';

  @override
  String get errCustomerLoadFailed => 'تعذر تحميل بيانات العميل';

  @override
  String get errAttachmentOpenFailed => 'تعذّر فتح المرفق. حاول مرة أخرى.';

  @override
  String get errAttachmentUnavailable =>
      'المرفق لم يعد متاحًا — اسحب للأسفل للتحديث.';

  @override
  String get errAttachmentsLoadFailed =>
      'تعذّر تحميل المرفقات. اسحب للأسفل للمحاولة مجددًا.';

  @override
  String get attachmentsEmpty => 'لا توجد مرفقات بعد';

  @override
  String get errCannotLaunchApp =>
      'تعذّر فتح تطبيق مناسب لهذا الإجراء على جهازك.';

  @override
  String get errActionFailed => 'تعذّر إتمام الإجراء. حاول مرة أخرى.';

  @override
  String get errFeatureNotAvailable => 'هذه الميزة غير متاحة على هذا السيرفر';

  @override
  String get errLocationSharingDisabled => 'صلاحية الموقع غير مفعّلة';

  @override
  String get customersTitle => 'العملاء';

  @override
  String get customersSearchHint => 'بحث عن عميل…';

  @override
  String get customersEmpty => 'لا توجد عملاء';

  @override
  String get customersStatTotal => 'إجمالي العملاء';

  @override
  String get customersStatActive => 'عميل نشط';

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
  String customerActionNearby(String radius) {
    return 'عرض الموظفين القريبين ($radius م)';
  }

  @override
  String get customerAlreadyCheckedIn => 'أنت مسجّل وصول هنا الآن';

  @override
  String get customerActiveVisitBadge => 'زيارة نشطة';

  @override
  String customerCheckInBlocked(String customer) {
    return 'أنهِ زيارتك الحالية عند $customer أولاً';
  }

  @override
  String get customerCheckInBlockedShort => 'زيارة جارية في مكان آخر';

  @override
  String get checkInSuccess => 'تم تسجيل الوصول';

  @override
  String get visitActiveTitle => 'زيارة نشطة';

  @override
  String get visitActiveEmpty =>
      'لا توجد زيارة نشطة الآن.\nاختر عميل وابدأ تسجيل الوصول.';

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
  String get mapLiveTracking => 'تتبّع مباشر';

  @override
  String get visitNotesLabel => 'ملاحظات (اختياري)';

  @override
  String get visitActionCheckOut => 'إنهاء الزيارة';

  @override
  String get checkOutSuccess => 'تم إنهاء الزيارة';

  @override
  String get employeesTitle => 'الموظفين';

  @override
  String get employeesEmpty => 'لا يوجد موظفين معدّين بعد';

  @override
  String get employeesSearchHint => 'بحث عن موظف…';

  @override
  String get createVisitTitle => 'إنشاء زيارة جديدة';

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
  String get visitStateCancel => 'ملغية';

  @override
  String get visitDetailVisitTypeLabel => 'نوع الزيارة';

  @override
  String get visitDetailEditVisitType => 'تغيير النوع';

  @override
  String get visitDetailMarkAsDone => 'تأكيد المراجعة';

  @override
  String get visitDetailMarkAsDoneSuccess => 'تم اعتماد الزيارة كمنتهية';

  @override
  String get visitDetailSendToEmployee => 'إرسال للموظف';

  @override
  String get visitDetailSentToEmployeeSuccess => 'تم إرسال الزيارة للموظف';

  @override
  String get visitDetailEditState => 'تغيير الحالة';

  @override
  String get visitDetailPickState => 'اختار الحالة';

  @override
  String get createVisitSubmit => 'إنشاء الزيارة';

  @override
  String get createVisitSuccess => 'تم إنشاء الزيارة';

  @override
  String get createVisitCustomerRequired => 'اختار عميل';

  @override
  String get createVisitEmployeeRequired => 'اختار موظف';

  @override
  String get createVisitDateRequired => 'حدد تاريخ الزيارة';

  @override
  String get createVisitTooltip => 'إنشاء زيارة';

  @override
  String get createVisitPickType => 'اختار نوع الزيارة';

  @override
  String get createVisitPickCustomer => 'اختار العميل';

  @override
  String get createVisitPickEmployee => 'اختار الموظف';

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
  String get groupEarlierThisWeek => 'هذا الأسبوع';

  @override
  String get groupEarlier => 'سابقاً';

  @override
  String get groupTomorrow => 'غداً';

  @override
  String get groupLaterThisWeek => 'خلال الأسبوع';

  @override
  String get groupUpcoming => 'قادم';

  @override
  String get statsTotal => 'الإجمالي';

  @override
  String get statsActive => 'نشطة';

  @override
  String get statsCompleted => 'مكتملة';

  @override
  String get statsPendingReview => 'للمراجعة';

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
  String get filterStatusPendingReview => 'قيد المراجعة';

  @override
  String get filterStatusIncomplete => 'غير مكتملة';

  @override
  String get filterTimingLabel => 'التوقيت';

  @override
  String get filterTimingAll => 'الكل';

  @override
  String get filterTimingOnTime => 'في ميعادها';

  @override
  String get filterTimingEarly => 'قبل الميعاد';

  @override
  String get filterTimingOverdue => 'فات الميعاد';

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
  String get visitDetailStateBadgeSubmitted => 'قيد التنفيذ';

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
  String get nearbyAdjustRadius => 'ضبط نصف القطر';

  @override
  String get roleManager => 'مدير';

  @override
  String get roleUser => 'موظف ميداني';

  @override
  String get roleManagerTitle => 'مدير الفريق';

  @override
  String get roleEmployeeTitle => 'مندوب ميداني';

  @override
  String get visitsHistoryActiveBadge => 'نشطة الآن';

  @override
  String get visitsScheduledLabel => 'الموعد';

  @override
  String get dashboardGreeting => 'صباح الخير';

  @override
  String get dashboardTodayProgress => 'إنجاز اليوم';

  @override
  String get dashboardFieldTime => 'وقت الميدان';

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
  String get analyticsVisitsThisWeek => 'زيارة هذا الأسبوع';

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
  String get reviewTitle => 'مراجعة الزيارات';

  @override
  String reviewPendingCount(int n) {
    return '$n بانتظار موافقتك';
  }

  @override
  String get reviewApprove => 'اعتمد';

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
  String get routeStops => 'محطات';

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
  String get createVisitSectionCustomer => 'العميل';

  @override
  String get createVisitSectionEmployee => 'الموظف الميداني';

  @override
  String get createVisitSectionType => 'نوع الزيارة';

  @override
  String get createVisitSectionDate => 'موعد الزيارة';

  @override
  String get createVisitChange => 'تغيير';

  @override
  String get visitsHistoryCompletedBadge => 'مكتملة';

  @override
  String get visitsHistoryIncompleteBadge => 'غير مكتملة';

  @override
  String get visitsHistoryOverdueBadge => 'فات الميعاد';

  @override
  String get visitDetailOverdueHint =>
      'ميعاد الزيارة عدّى والزيارة لسه ما خلصتش. يا تأجل التاريخ يا تعمل follow-up.';

  @override
  String get visitExecutedOnTime => 'اتعملت في ميعادها';

  @override
  String visitExecutedEarly(int days) {
    return 'اتعملت قبل ميعادها بـ $days يوم';
  }

  @override
  String visitExecutedLate(int days) {
    return 'اتعملت بعد ميعادها بـ $days يوم';
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
  String get statusActive => 'نشطة الآن';

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
  String get visitDetailOutRangeHint => 'اقترب أكثر من الموقع لبدء الزيارة';

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
  String get visitDetailNoCustomerLocation => 'موقع العميل غير متاح';

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
  String get visitLocationNotAvailable => 'موقع العميل غير متاح';

  @override
  String get offlineNoQueue => 'إنت أوفلاين — الأكشن هيتحفظ محلياً';

  @override
  String offlineWithQueue(int count) {
    return 'أوفلاين — $count إجراء في انتظار المزامنة';
  }

  @override
  String offlineSyncing(int count) {
    return 'جاري المزامنة لـ $count إجراء…';
  }

  @override
  String offlinePendingCount(int count) {
    return 'لا يزال $count إجراء في الانتظار — تحقّق من الاتصال وحاول مجددًا.';
  }

  @override
  String get offlineCheckInQueued => 'اتحفظ محلياً — هيترفع لما الشبكة ترجع';

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
  String get dashboardActiveOnMapTitle => 'الموظفين في الميدان';

  @override
  String get dashboardActiveEmpty => 'لا يوجد موظفين عاملين دلوقتي';

  @override
  String dashboardActiveMore(int count) {
    return '+$count كمان';
  }

  @override
  String get dashboardTopCustomers => 'أكثر العملاء زيارة';

  @override
  String get dashboardTopEmployees => 'أفضل موظفين (زيارات منتهية)';

  @override
  String get dashboardNoData => 'البيانات لسه قليلة';

  @override
  String get visitsTabTitle => 'الزيارات';

  @override
  String get homeTabCustomers => 'العملاء';

  @override
  String get homeTabActive => 'النشطة';

  @override
  String get homeTabHistory => 'السجل';

  @override
  String get homeLocationSharingOn => 'مشاركة الموقع مفعّلة';

  @override
  String get homeLocationSharingOff => 'مشاركة الموقع متوقفة';

  @override
  String get nearbyTitle => 'الموظفين القريبين';

  @override
  String nearbyRadiusLabel(String radius) {
    return 'نصف القطر: $radius متر';
  }

  @override
  String get nearbyEmpty => 'لا يوجد موظفين داخل النطاق';

  @override
  String nearbyLastUpdate(String time) {
    return 'آخر تحديث: $time';
  }

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
    return '$count في انتظار المزامنة';
  }

  @override
  String get settingsHelp => 'المساعدة والدعم';

  @override
  String get confirmLogoutTitle => 'تسجيل الخروج';

  @override
  String get confirmLogoutMessage => 'هل تريد تسجيل الخروج من التطبيق؟';

  @override
  String get confirmExitTitle => 'إنهاء التطبيق';

  @override
  String get confirmExitMessage => 'هل تريد إنهاء التطبيق؟';

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
  String get wfStateSubmitted => 'مُقدَّمة';

  @override
  String get wfStateWaitingParticipant => 'بانتظار موافقة مدير المشارك';

  @override
  String get wfStateWaitingManager => 'بانتظار موافقة المدير';

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
  String get wfScopePending => 'بانتظار الموافقة';

  @override
  String get wfScopeTeam => 'الفريق';

  @override
  String get wfScopeEscalated => 'المُصعَّدة';

  @override
  String get wfActionSubmit => 'تقديم للموافقة';

  @override
  String get wfActionApprove => 'موافقة';

  @override
  String get wfActionReject => 'رفض';

  @override
  String get wfActionReschedule => 'طلب إعادة جدولة';

  @override
  String get wfActionStart => 'بدء الزيارة';

  @override
  String get wfActionEnd => 'إنهاء الزيارة';

  @override
  String get wfActionCancel => 'إلغاء الزيارة';

  @override
  String get wfActionAddParticipant => 'إضافة مشارك';

  @override
  String get wfActionAddAttachment => 'إضافة مرفق';

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
  String get wfSubmitted => 'تم التقديم للموافقة';

  @override
  String get wfApproved => 'تمت الموافقة على الزيارة';

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
  String get wfParticipantApproved => 'تمت الموافقة على المشارك';

  @override
  String get wfParticipantRejected => 'تم رفض المشارك';

  @override
  String get wfApprovalHistory => 'سجل الموافقات';

  @override
  String get wfSubmittedOn => 'قُدِّمت في';

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
  String get wfParticipantApprovedState => 'موافَق';

  @override
  String get wfParticipantRejectedState => 'مرفوض';

  @override
  String get wfNoParticipants => 'لا يوجد مشاركون إضافيون';

  @override
  String get wfApproveParticipant => 'موافقة';

  @override
  String get wfRejectParticipant => 'رفض';

  @override
  String get wfEmptyMine => 'لا توجد لديك زيارات بعد';

  @override
  String get wfEmptyPending => 'لا شيء بانتظار موافقتك';

  @override
  String get wfEmptyTeam => 'لا توجد زيارات للفريق';

  @override
  String get wfEmptyEscalated => 'لا توجد زيارات مُصعَّدة';

  @override
  String get wfSearchHint => 'ابحث بالعميل أو المرجع أو الغرض…';

  @override
  String get wfSearchNoMatch => 'لا توجد زيارات مطابقة لبحثك';

  @override
  String get wfRescheduleTitle => 'طلب إعادة جدولة';

  @override
  String get wfListTitle => 'الزيارات';

  @override
  String get wfDetailTitle => 'زيارة';

  @override
  String get wfStartLocationCaptured => 'سيتم تسجيل موقعك عبر الـ GPS';

  @override
  String get wfConfirmCancelTitle => 'إلغاء الزيارة';

  @override
  String get wfConfirmCancelMessage => 'متأكد إنك عايز تلغي الزيارة دي؟';

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
  String get wfSectionApproval => 'الفريق والموافقة';

  @override
  String get wfSectionExecution => 'التنفيذ';

  @override
  String get wfOpenInMaps => 'افتح في الخرائط';

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
  String get wfNotificationsEmpty => 'مفيش حاجة مطلوبة منك';

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
      'جهازك بيبلّغ عن موقع GPS وهمي (mock). ده هيتسجّل للمراجعة. تكمّل برضه؟';

  @override
  String get wfQueuedOffline => 'اتسجّل أوفلاين — هيتزامن أول ما النت يرجع';

  @override
  String get wfMockFlagBannerTitle => 'اتسجّل موقع مزيّف على الزيارة دي';

  @override
  String get wfMockFlagBannerBody =>
      'الجهاز بلّغ عن موقع GPS وهمي وقت بدء أو إنهاء الزيارة. راجعها كويس قبل الموافقة.';
}
