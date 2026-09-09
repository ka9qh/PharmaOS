# PharmaOS - الحزمة الكاملة لكل ما بُني في هذه المحادثة (أغسطس 2026)

هذا الملف هو الدليل الوحيد الذي تحتاجه للتطبيق. الملفات الأخرى في `docs/`
(`PATCH_NOTES_*.md`) تشرح كل دفعة بالتفصيل إن أردت المراجعة، لكن هذا الملف
يكفي وحده للتطبيق الكامل.

## خطوات التطبيق

1. **انسخ الاحتياطي أولاً**: خذ نسخة كاملة من مجلد مشروعك الحالي قبل أي شيء
   (فقط للأمان، رغم أن كل ما هنا إضافي/تعديل وليس حذفًا لأي ميزة كانت تعمل).
2. **انسخ كل مجلد `lib/` هنا فوق مجلد `lib/` في مشروعك** - استبدال كامل لكل
   ملف يوجد بنفس المسار (43 ملف، القائمة الكاملة أسفل هذا الملف). أي ملف في
   مشروعك غير موجود بهذه الحزمة لم يتغيّر - اتركه كما هو.
3. **استبدل `pubspec.yaml`** بالنسخة المرفقة (أضافت حزمة واحدة جديدة فقط:
   `file_picker` و`csv` - لازمتان لاستيراد الأدوية من ملفات).
4. شغّل:
   ```
   flutter pub get
   flutter run   (أو flutter build windows)
   ```
5. **لا حاجة لـ `build_runner`** في كل هذه الدفعات - كل التعديلات على قاعدة
   البيانات تمت عبر SQL خام داخل الترحيل (migration) بدل تعديل تعريف الجداول،
   عمدًا، لتجنّب الحاجة لإعادة توليد كود Drift (`.g.dart`) في بيئة لا أملك فيها
   Flutter لأختبره فعليًا. إن ظهر خطأ غريب غير متوقع فقط، جرّب
   `dart run build_runner build --delete-conflicting-outputs` كخطوة احتياطية.
6. قاعدة بياناتك الحالية (إن جربتها من قبل) ستُرقَّى تلقائيًا عند أول تشغيل
   (schemaVersion وصل الآن لـ 4) - لا حذف بيانات. إن كانت قاعدة تجريبية فقط،
   يمكنك حذفها والبدء نظيفًا لتفادي أي تعقيد اختباري.

## ماذا تحصل عليه بعد التطبيق (ملخص كل الدفعات)

1. **نقطة البيع (POS) هي الشاشة الرئيسية** بعد تسجيل الدخول (كانت لوحة
   التحكم) - إلا لمن لا يملك صلاحية استخدامها فيُنقل للوحة التحكم مباشرة.
2. **بحث الأدوية أصبح سريعًا فعليًا** حتى مع مخزون ضخم (فهارس SQL + بحث نصي
   كامل FTS5 اختياري) بدل تحميل كل الجدول للذاكرة في كل بحث.
3. **نظام صلاحيات متقدم حقيقي**: 7 أدوار × 14 صلاحية + تخصيص فردي لكل مستخدم
   من شاشة "الصلاحيات" الجديدة (لوحة التحكم ← الإدارة ← الصلاحيات).
4. **استيراد الأدوية من Excel بالجملة** (الإعدادات ← بيانات الأدوية) - يحفظ
   الباركود الحقيقي من الملف إن وُجد.
5. **تعدد وحدات البيع** (حبة/شريط/باكت) - إعداد لكل دواء من شاشة الأدوية
   (أيقونة 📦)، يظهر عند استلام المخزون وعند البيع من نقطة البيع.
6. **3 ملفات بذر جاهزة فيها 5,532 دواء حقيقي إجمالاً** من 3 مصادر رفعتها
   (راجع القسم التفصيلي أدناه - يشمل تصحيح خطأ اكتشفته أثناء فحص التكرار).

## القائمة الكاملة لكل ملف (41 ملف)

كل الملفات تحت `lib/` في هذه الحزمة (نفس المسار بالضبط في مشروعك):

```
app/app_router.dart
core/database/app_database.dart
core/di/service_locator.dart
core/security/permissions_service.dart
core/security/role_guard.dart
core/services/medicine_excel_import_service.dart
core/services/medicine_packaging_service.dart
features/auth/data/models/auth_model.dart
features/auth/data/repositories/auth_repository_impl.dart
features/auth/domain/entities/auth_entity.dart
features/auth/presentation/screens/auth_screen.dart
features/backup/presentation/screens/backup_screen.dart
features/dashboard/presentation/screens/dashboard_screen.dart
features/inventory/presentation/screens/inventory_screen.dart
features/medicines/data/datasources/medicines_datasource.dart
features/medicines/data/repositories/medicines_repository_impl.dart
features/medicines/domain/entities/medicines_entity.dart
features/medicines/domain/repositories/medicines_repository.dart
features/medicines/domain/usecases/medicines_usecase.dart
features/medicines/presentation/providers/medicines_provider.dart
features/medicines/presentation/screens/medicine_form_screen.dart
features/medicines/presentation/screens/medicines_screen.dart
features/medicines/presentation/widgets/medicines_widget.dart
features/medicines/presentation/widgets/packaging_config_dialog.dart
features/permissions/data/datasources/permissions_datasource.dart
features/permissions/data/repositories/permissions_repository_impl.dart
features/permissions/domain/entities/permissions_entity.dart
features/permissions/domain/repositories/permissions_repository.dart
features/permissions/domain/usecases/permissions_usecase.dart
features/permissions/presentation/providers/permissions_provider.dart
features/permissions/presentation/screens/permissions_screen.dart
features/permissions/presentation/widgets/permissions_widget.dart
features/pos/presentation/providers/pos_provider.dart
features/pos/presentation/screens/pos_screen.dart
features/pos/presentation/widgets/manual_add_dialog.dart
features/reports/presentation/controllers/reports_controller.dart
features/reports/presentation/screens/reports_screen.dart
features/settings/presentation/screens/medicine_import_screen.dart
features/settings/presentation/screens/settings_screen.dart
features/users/presentation/screens/users_screen.dart
features/users/presentation/widgets/users_widget.dart
```

بالإضافة إلى: `pubspec.yaml` (جذر المشروع)، و`docs/*.md` (اختياري، للمرجعية
فقط)، و3 ملفات بذر تحت `seed_data/`:
`yemen_pharmacy_guide_medicines.csv` (4,064 دواء بأسماء تجارية)،
`who_essential_medicines_generic_names.csv` (931 دواء، أسماء علمية، إصدار 2022)،
`who_essential_medicines_2019_6th_edition.csv` (537 دواء، أسماء علمية، إصدار 2019).

## تحديث جديد: إتمام فجوات كانت مفتوحة

- ✅ **FEFO فعليًا يعمل بالفعل** - فحصت `sales_datasource.dart` بعمق: البيع
  يخصم من الدفعة الأقرب انتهاءً أولًا تلقائيًا، ضمن معاملة ذرّية كاملة
  (Transaction) تتراجع تلقائيًا عند أي خطأ. لم يكن يحتاج أي تعديل - كان يعمل
  صحيحًا من قبل.
- ✅ **تعديل دواء بعد إنشائه أصبح ممكنًا** - لم تكن موجودة أي طريقة لتصحيح
  اسم/سعر دواء بعد الإضافة. الآن: اضغط على أي دواء بالقائمة لفتح شاشة تعديل.
  تغيير السعر يُسجَّل تلقائيًا في سجل التدقيق (من غيّره، القيمة القديمة
  والجديدة). حقل السعر يُقفل لمن لا يملك صلاحية `editPrices`.
- ✅ **شاشة النسخ الاحتياطية** - زر الإنشاء اليدوي مقفل الآن لمن لا يملك
  صلاحية `backup`. (لا يوجد زر استعادة أصلاً بتصميم متعمد سابق - راجع التعليق
  في الملف - لذا صلاحية `restoreBackup` ليس لها ما تتحكم به بعد).

## ملف البذر: 4,064 دواء من "دليل المنتجات الدوائية اليمنية"

استخرجت هذا فعليًا (ليس افتراضًا) من ملف الـPDF الذي رفعته (588 صفحة، تقرير
Microsoft Access من المعهد العالي للصيدلة والعلوم الطبية بصنعاء).

**تحديث بعد فحصك للتكرار**: طلبت مني التحقق من التكرار، وأثناء الفحص اكتشفت
خطأ فعليًا في استخراجي الأول (كان ينتج عنه ~586 "دواء" وهمي باسم مثل "Package"
أو "Tablets" - كلمة تصنيف بدل اسم دواء حقيقي، بسبب خطأ في حساب عدد صفوف رأس
الجدول المتكرر بكل صفحة). صححته وأعدت الاستخراج بالكامل، ثم أزلت 28 سجلًا
مكررًا تكرارًا تامًا (نفس الاسم والتركيب والشركة والعبوة معًا). **النتيجة
النهائية: 4,064 سجل دواء نظيف** (بعد: 4,383 استخراج أول به خطأ → 4,103 بعد
تصحيح الخطأ → 4,075 بعد حذف 28 مكررًا تامًا → 4,064 بعد حذف 11 سجلاً بأحرف
غير سليمة).

**تنبيه مهم**: أسماء دواء متكررة **ليست كلها تكرارًا خاطئًا** - غالبيتها
منتجات حقيقية مختلفة بنفس الاسم التجاري (نفس الدواء بتركيزات/أشكال/عبوات
مختلفة، مثل "Ramol Syrup 60ml" و"Ramol Syrup 100ml" و"Ramol Tablets" - 7
منتجات حقيقية مختلفة باسم "Ramol" وحده). لم أحذف هذه عمدًا - حذفها كان سيفقدك
منتجات حقيقية موجودة فعلاً.

**الحقول المتوفرة**: اسم الدواء التجاري، الاسم العلمي/التركيب، التصنيف
العلاجي، الشركة المصنّعة، شكل الجرعة، الجرعة الموصى بها، دولة المنشأ، حجم
العبوة (آخر 4 حقول مرجعية فقط - النظام حاليًا لا يملك أعمدة لها في قاعدة
البيانات، ستظهر في شاشة الاستيراد ويمكنك اختيار "تجاهل" لها أو استخدامها
كمرجع أثناء المراجعة).

**لا يحتوي**: أسعار، باركود، ولا "الكمية المتوفرة" - الكتاب مرجع علمي/تجاري
وليس فاتورة موزّع، فهذه البيانات غير موجودة فيه أصلاً. بعد الاستيراد ستحتاج
إدخال السعر والكمية لكل صنف كما تفعل عادة - هذا يسرّع فقط جزء "كتابة اسم
الدواء والبحث عنه" ولا يغني عن التسعير والجرد الفعلي.

## ملفات البذر الثلاثة - أيها تستورد

هذا المشروع جمع 3 ملفات بذر مختلفة عبر المحادثة - إليك ملخص كل واحد وكيف
تقرر أيها تستورد:

**1) `yemen_pharmacy_guide_medicines.csv` - 4,064 دواء (أسماء تجارية حقيقية)**
من "دليل المنتجات الدوائية اليمنية" (المعهد العالي للصيدلة، صنعاء) الذي
رفعته أول مرة. هذا الأكثر فائدة عمليًا - أسماء تجارية فعلية (مثل "بنادول")
تبحث عنها الصيدلية يوميًا، مع الشركة المصنّعة. **هذا الملف الذي أنصح
بالبدء به.**

**2) `who_essential_medicines_generic_names.csv` - 931 دواء (أسماء علمية)**
من القائمة الوطنية الرسمية للأدوية الأساسية، **الإصدار السابع 2022** (WHO +
الهيئة العليا). أسماء علمية/عامة (INN) مثل "Paracetamol" - **ليست أسماء
تجارية**. مرجع تكميلي، ليس بديلاً عن الملف الأول.

**3) `who_essential_medicines_2019_6th_edition.csv` - 537 دواء (أسماء علمية)**
من نفس القائمة الرسمية لكن **الإصدار السادس 2019** - نسخة أقدم من الملف
رقم 2. في مقدمة نسخة 2022 نفسها نص صريح أنها تحديث لقائمة 2019، وأغلب
المحتوى متداخل بشدة بين الاثنين. **لم أدمجهما أو أحذف المكرر بينهما عمدًا -
قرارك**: عمليًا أنصح بتجاهل هذا الملف والاكتفاء بالملف رقم 2 (الأحدث رسميًا)
إلا إن كان عندك سبب محدد يستدعي نسخة 2019 تحديدًا.

كل الثلاثة استخراج آلي دقيق (جداول PDF فعلية، وليس نصًا خامًا) - راجعت عيّنات
من بداية ووسط ونهاية كل ملف وكانت نظيفة، لكن راجعها بنفسك قبل الاعتماد
عليها في البيع الفعلي، خصوصًا التركيبة العلمية لأي دواء حساس.

**كيف تستوردها**: افتح النظام ← الإعدادات ← استيراد الأدوية من Excel ← اختر
أيًا من الملفات الثلاثة ← الأعمدة ستُقترح تلقائيًا حسب اسم العمود - راجعها ثم
أكّد الاستيراد. يمكنك استيراد أكثر من ملف بالتتابع (يتخطى تلقائيًا أي باركود
مكرر - الملفين 2 و3 لا يحتويان باركود أصلاً فلن يتكرر شيء بينهما آليًا،
راجع الأسماء يدويًا إن استوردت كليهما لتفادي تكرار نفس الدواء العلمي مرتين).

## تنبيهات صادقة عامة (تنطبق على كل الحزمة)

- لم أختبر أي من هذا الكود فعليًا (بناء أو تشغيل) - بيئة عملي هنا بلا Flutter
  مثبَّت وبلا اتصال إنترنت. كل شيء مبني بمطابقة دقيقة لأنماط كودك الفعلية
  (تحققت من كل اسم عمود وكل واجهة قبل استخدامها) لكن رجاءً جرّبه وأخبرني
  بأي خطأ فعلي عند التشغيل حتى أصلحه فورًا.
- `file_picker` و`csv` أول حزمتين خارجيتين جديدتين أضفتهما - راقب رسالة أي
  تعارض إصدار عند `pub get`.
- ثلاثة أخطاء حقيقية أبلغتني بها (بلقطة شاشة فعلية) أصلحتها في آخر دفعة -
  راجع `docs/PATCH_NOTES_2026_08_BUGFIXES.md` للتفاصيل الكاملة: تعطّل استيراد
  Excel (تحوّل لـCSV)، العلوق داخل نقطة البيع بلا رجوع، وأُضيفت حساب الباقي
  النقدي للعميل.
- التفاصيل الكاملة لكل قرار (لماذا، وما البدائل التي فكرت فيها) موجودة في
  ملفات `docs/PATCH_NOTES_*.md` إن احتجتها لاحقًا.
