# هندسة النظام (Architecture) - PharmaOS

## النمط المعماري
Clean Architecture مبسّط، بثلاث طبقات لكل ميزة:

- **Presentation**: الشاشات، العناصر المرئية، Providers (Riverpod)، Controllers.
- **Domain**: الكيانات (Entities)، عقود المستودعات (Repository Interfaces)، حالات الاستخدام (UseCases). هذه الطبقة لا تعرف شيئًا عن قاعدة البيانات أو Flutter.
- **Data**: تنفيذ المستودعات، مصادر البيانات (Datasources)، النماذج (Models) المرتبطة مباشرة بجداول Drift.

## قاعدة صارمة
الاعتماد يكون دائمًا من الخارج إلى الداخل:
`Presentation → Domain ← Data`
طبقة Domain لا تستورد أي شيء من Data أو Presentation.

## لماذا هذا التصميم؟
- يسمح باختبار منطق الأعمال دون تشغيل واجهة المستخدم.
- يسمح لاحقًا بتبديل قاعدة البيانات أو الواجهة دون كسر منطق الأعمال.
- يمنع تسرب استعلامات SQL إلى داخل الشاشات مباشرة (خطأ شائع يصعّب الصيانة لاحقًا).

## تدفق البيانات في عملية بيع نموذجية (مثال تطبيقي)
1. الشاشة (POS Screen) تستدعي Controller.
2. Controller يستدعي UseCase (مثل `CreateSaleUseCase`).
3. UseCase يستدعي `SalesRepository` (عقد Domain).
4. `SalesRepositoryImpl` (في Data) ينفذ الاستعلام عبر `SalesDataSource` على قاعدة بيانات Drift المشفرة.
5. النتيجة تعود بنفس المسار عكسيًا وتُحدَّث الحالة عبر Riverpod Provider.

## الحقن (Dependency Injection)
عبر GetIt، يُسجَّل كل Repository وDataSource مرة واحدة عند إقلاع التطبيق في `core/di` (يُبنى في مرحلة Foundation).

## إدارة الحالة
Riverpod فقط. ممنوع استخدام setState لأي حالة تتجاوز عنصر واجهة بسيط جدًا ومحلي بالكامل.
