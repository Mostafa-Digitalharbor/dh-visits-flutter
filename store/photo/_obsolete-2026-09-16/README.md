# لقطات ملغاة — 2026-09-16

متترفعش أي صورة من الفولدر ده على Play أو App Store.

التطبيق بقى يسجّل الموقع **أثناء الزيارة الجارية بس**. اتشال "مسار اليوم" (Today's route)
و"الموظفون المباشرون" (Live employees) ومشاركة الموقع اللحظي. الصور دي بتعرض الشاشات
اللي اتشالت، فعرضها في المتجر يبقى وصف مضلِّل للتطبيق:

| الصورة | المشكلة |
|---|---|
| `edited/02_visits_list.png` وكل `1-visits-list.png` و`Screenshot_1784471051.png` | تبويب "Today's route" في الشريط السفلي (مسار يوم العمل) |
| `edited/03_dashboard.png` وكل `3-dashboard.png` و`Screenshot_1784471657.png` | خريطة "Live employees"، وعنوان "See your team in real time / Live progress, attendance…" |

المسارات جوه الفولدر نفس مساراتها الأصلية تحت `store/photo/`.

## المطلوب بدلها

صوّر من النسخة الحالية (1.0.2 وما بعدها)، على حساب فيه بيانات عرض نظيفة (بدون
`[QA-AUTO]` / `[PROBE]` / `Test`):

1. قائمة الزيارات (من غير تبويب مسار اليوم).
2. تفاصيل زيارة مع زر "بدء الزيارة".
3. مسار زيارة واحدة على الخريطة.
4. لوحة المدير (من غير خريطة الموظفين المباشرين).

حط الصور الخام في `store/photo/edited/` بنفس الأسماء، وبعدين شغّل:

```powershell
powershell -ExecutionPolicy Bypass -File store/photo/tools/compose.ps1 -Platform play
```
