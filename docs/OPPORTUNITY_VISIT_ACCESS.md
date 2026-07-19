# مشكلة: إنشاء زيارة من نوع "فرصة" (Opportunity)

## العرض
لما المستخدم يختار **فرصة** بدل **مشروع** في شاشة إنشاء زيارة، ويفتح قائمة اختيار
الفرصة → بتطلع رسالة خطأ ومفيش أي فرص بتظهر.

## السبب الجذري (مؤكّد)
التطبيق بيقرأ الفرص من `crm.lead` مباشرة عبر `call_kw`
(`search_read` بدومين `[('type','=','opportunity')]`). لكن مجموعات الزيارات
(`group_visit_user` / `group_visit_manager`) **ماعندهاش صلاحية قراءة `crm.lead`**.
الرد من الأودو (تم اختباره حيًّا كـ `mona@test.com`):

```
You are not allowed to access 'Lead' (crm.lead) records.
This operation is allowed for the following groups:
  - Sales/Administrator
  - Sales/User: Own Documents Only
```

> **ملاحظة:** المشاريع (`project.project`) بتشتغل عادي لأن صلاحيتها متاحة —
> المشكلة في `crm.lead` بس.

## الحلول الممكنة (قرار الباك إند / المنتج)

### الخيار أ — تفعيل الفرص بشكل صحيح (لو الميزة مطلوبة)
لازم الباك إند يوفّر وصول آمن للفرص القابلة للاختيار. الأنضف: **endpoint مخصّص**
في `dh_visit_management` يرجّع الفرص (بـ sudo أو بصلاحية مناسبة) بدل ما التطبيق
يلمس `crm.lead` مباشرة — نفس فكرة باقي الـ `/api/visit/*`:

```python
@http.route('/api/visit/opportunities', type='json', auth='user')
def opportunities(self, **kw):
    leads = request.env['crm.lead'].sudo().search(
        [('type', '=', 'opportunity')], limit=500, order='name asc')
    return {'opportunities': [
        {'id': l.id, 'name': l.name,
         'partner_id': l.partner_id.id, 'partner_name': l.partner_id.display_name}
        for l in leads]}
```

> لو استُخدم `sudo()` لازم يتضاف فلتر مناسب (مثلاً الفرص اللي المستخدم مسؤول
> عنها أو ضمن فريقه) عشان ماتكسرش قواعد الخصوصية.

**أو** (أبسط بس أوسع صلاحية) — إضافة `read` على `crm.lead` لمجموعات الزيارات عبر
`ir.model.access` / record rule. لكن ده بيدي المستخدمين قراءة كل الفرص، فالـ
endpoint المتحكَّم فيه أفضل.

بعد ما الباك إند يوفّر `/api/visit/opportunities`، أنا أعدّل التطبيق يستخدمه بدل
`call_kw` على `crm.lead` (تعديل بسيط في `VisitsRepository.listOpportunities`).

### الخيار ب — إخفاء نوع "فرصة" مؤقتًا (لو الميزة مش مطلوبة دلوقتي)
تعديل client فقط: أشيل زرّ **فرصة** من `SegmentedButton` في شاشة الإنشاء وأخلّي
الزيارات على المشاريع بس، لحد ما الباك إند يجهّز الوصول. أقدر أعمله فورًا.

## الحالة الحالية في التطبيق
- التطبيق بيعرض رسالة الخطأ الخام من الأودو في القائمة. (ممكن أحسّنها لرسالة
  واضحة "لا تملك صلاحية الوصول للفرص" لو قررنا نسيبها ظاهرة.)
