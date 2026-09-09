# دفعة نظام الصلاحيات المتقدم (Users/Roles/Permissions) - أغسطس 2026

## ماذا بُني فعليًا

نظام صلاحيات حقيقي بطبقتين:
1. **افتراضي حسب الدور** (`core/security/role_guard.dart`) - 7 أدوار الآن
   (أضفت `pharmacist` و`employee`) × 14 صلاحية (أضفت 8 لم تكن موجودة:
   `deleteInvoice`, `printReports`, `openDay`, `closeDay`, `editInventory`,
   `editMedicineData`, `backup`, `restoreBackup`).
2. **تخصيص فردي لكل مستخدم** (`core/security/permissions_service.dart` + جدول
   `user_permissions` جديد) - يسمح لصاحب الصيدلية بتفعيل أو تعطيل أي صلاحية
   لمستخدم معيّن تحديدًا، متجاوزًا افتراضي دوره. هذا يحقق حرفيًا متطلب "كل
   صلاحية مستقلة ويمكن تفعيلها أو تعطيلها" من مواصفات المشروع.

الصلاحيتان تُدمَجان في `AuthUser.effectivePermissions` عند تسجيل الدخول (مرة
واحدة، ثابتة طوال الجلسة - تغيير صلاحيات مستخدم بجلسة مفتوحة يُطبَّق من دخوله
التالي، قرار مقصود لتفادي تعقيد إعادة الحساب اللحظي).

## شاشة الصلاحيات الجديدة

`features/permissions/*` تحوّلت من TODO فارغ لميزة كاملة تعمل: قائمة
المستخدمين على اليسار، وعند اختيار مستخدم تظهر كل الصلاحيات الـ14 مع مفتاح
تشغيل/إيقاف لكل واحدة + مؤشر "افتراضي الدور" أو "مخصَّص يدويًا" + زر إعادة
للافتراضي. متاحة من لوحة التحكم ← الإدارة ← الصلاحيات. العرض متاح للجميع،
التعديل يتطلب صلاحية `manageUsers` (نفس فلسفة شاشة المستخدمين تمامًا).

## كل الملفات المعدّلة/الجديدة في هذه الدفعة

| الملف | التغيير |
|---|---|
| `core/security/role_guard.dart` | +2 دور، +8 صلاحية، تسميات عربية |
| `core/security/permissions_service.dart` | **جديد** - القراءة/الكتابة الفعلية |
| `core/database/app_database.dart` | schemaVersion 2→3، جدول `user_permissions` |
| `core/di/service_locator.dart` | تسجيل PermissionsService + ميزة Permissions كاملة |
| `features/auth/domain/entities/auth_entity.dart` | + `effectivePermissions` و`.can()` |
| `features/auth/data/models/auth_model.dart` | `toEntity()` يقبل الصلاحيات الفعلية |
| `features/auth/data/repositories/auth_repository_impl.dart` | حساب الصلاحيات عند الدخول |
| `features/auth/presentation/screens/auth_screen.dart` | توجيه ذكي: POS إن ملك `usePos`، وإلا لوحة التحكم |
| `features/permissions/*` (كل الطبقات الـ8) | **من TODO فارغ لميزة كاملة** |
| `features/users/presentation/screens/users_screen.dart` | +دورين بالقائمة، فحص صلاحية فعلي بدل الدور فقط |
| `features/users/presentation/widgets/users_widget.dart` | تسميات الدورين الجديدين |
| `features/reports/presentation/controllers/reports_controller.dart` | يقبل `AuthUser` بدل `AppRole` |
| `features/reports/presentation/screens/reports_screen.dart` | تحديث سطر الاستدعاء المطابق |
| `features/dashboard/presentation/screens/dashboard_screen.dart` | إخفاء رقم الربح بدون `viewProfits` + زر "الصلاحيات" |

## تحذير مهم عن الترقية (Migration)

إن كانت لديك قاعدة بيانات بعد تجربة الدفعة السابقة (schemaVersion 2)، ستُرقَّى
تلقائيًا لـ 3 عند أول تشغيل - لا حذف بيانات. إن لم تكن جرّبت الدفعة السابقة
بعد، ابدأ من نسخة نظيفة لتفادي تراكم تعقيد الاختبار.

## ما لم يُبنَ عمدًا (قرار نطاق)

ميزة `features/roles/` (لا زالت TODO فارغة) - الأدوار حاليًا ثابتة بالكود
(enum من 7 قيم)، وليست قابلة لإنشاء دور مخصص جديد من الواجهة. نظام التخصيص
الفردي أعلاه يغطي معظم الحاجة العملية دون هذا التعقيد الإضافي. أخبرني إن كنت
فعليًا تحتاج "أنشئ دورًا جديدًا باسمه الخاص" من الواجهة - هذه ميزة أكبر منفصلة.

## بخصوص التعارضين السابقين - تم الحسم بناءً على توضيحك

1. **الطباعة الحرارية**: أُلغيت تحديدًا لطباعة **الفواتير/الإيصالات** في POS
   (لم تكن مبنية أصلاً، فلا شيء تغيّر في الكود). طباعة **ملصق الباركود** في
   شاشة الأدوية بقيت كما هي (ليست طباعة حرارية بالمعنى التقني - حوار طباعة
   ويندوز عادي يفتح لأي طابعة مثبّتة، حرارية أو غيرها).
2. **الفروع**: مؤجَّلة كما طلبت سابقًا - لم يتغيّر شيء إضافي هنا.
