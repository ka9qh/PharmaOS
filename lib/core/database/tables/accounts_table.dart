import 'package:drift/drift.dart';

@DataClassName('AccountRow')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // كود الحساب (مثل 1101) - فريد لتسهيل شجرة الحسابات
  TextColumn get code => text().unique()();
  
  // اسم الحساب (مثل: صندوق المعرض، بنك الراجحي، الإيرادات..)
  TextColumn get name => text()();
  
  // نوع الحساب: 'Asset' (أصول), 'Liability' (خصوم), 'Equity' (حقوق ملكية), 'Revenue' (إيرادات), 'Expense' (مصروفات)
  TextColumn get type => text()();
  
  // الحساب الأب (إن وجد) لتشكيل شجرة هرمية
  IntColumn get parentId => integer().nullable().references(Accounts, #id)();
  
  // هل هو حساب رئيسي (لا يمكن القيد عليه مباشرة) أم فرعي (يقبل القيود)
  BoolColumn get isHeader => boolean().withDefault(const Constant(false))();
  
  // الرصيد الحالي (للتسهيل في العرض بدل جمعه من القيود كل مرة، على الرغم من أن الرصيد الفعلي يستخرج من القيود)
  RealColumn get balance => real().withDefault(const Constant(0))();
  
  // هل يقبل التعديل أم أنه حساب أساسي (System Account) محمي
  BoolColumn get isSystemAccount => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
