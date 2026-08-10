# لقطات مرفوضة — لا تُرفع على App Store

الصور اللي في المجلد ده هي اللي كانت مرفوعة مع النسخة **1.0 (4)** وأدت لرفض
Apple يوم **2026-08-06** تحت البند **Guideline 2.3.10 — Accurate Metadata**:

> Revise the app's screenshots to remove non-iOS status bar images.

**السبب:** اللقطات دي أصلها تصوير من جهاز أندرويد (1080×2400) اتعمل له تأطير،
فبيظهر فيها شريط حالة أندرويد (مثلث الإشارة + أيقونة بطارية أندرويد) وشريط
التنقل السفلي (gesture pill). Apple بتعتبر ده إظهار لمنصة تانية.

مجموعات `ipad-13` كمان مكبّرة من لقطة موبايل، ومبقتش مطلوبة أصلًا بعد ما بقى
`TARGETED_DEVICE_FAMILY = "1"` (آيفون فقط) في النسخة 1.0.1 (5).

**البديل الصحيح:**

1. على ماك: `bash store/photo/tools/ios_shots.sh` → لقطات من محاكي iPhone 16 Pro Max
   بمقاس 1290×2796 بشريط حالة iOS نضيف (9:41، إشارة كاملة، بطارية 100%).
2. على ويندوز: `powershell -File store/photo/tools/compose.ps1 -Platform ios`
   → `store/photo/framed-ios/ios-6.9/`.

التفاصيل الكاملة والرد المرسل لـ Apple: [../../appstore/apple-review-2026-08-06.md](../../appstore/apple-review-2026-08-06.md).

اللقطات دي محفوظة هنا للرجوع فقط — لقطات **Google Play** مالهاش علاقة بالموضوع
وشغالة زي ما هي في `store/photo/framed-play/`.
