import 'package:drift/drift.dart';
import 'users_table.dart';

// سجل تقرير إغلاق - وليس "قفل" لليوم. راجع docs/WORKFLOW.md (تم تصحيحه).
//
// تصحيح مهم: لا يوجد قيد تفرد (uniqueKeys) على date بعد الآن. صيدليات تعمل
// 24 ساعة بنوبات متعددة تحتاج إصدار أكثر من تقرير إغلاق في نفس اليوم التقويمي
// (تقرير لكل نوبة/عامل). كل صف هنا هو Snapshot لفترة عمل واحدة (من آخر إغلاق
// وحتى الآن)، وليس قفلًا يمنع أي عملية لاحقة.
@DataClassName('DayClosingRow')
class DayClosings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();

  // اليوم التقويمي الذي تم فيه هذا الإغلاق - لأغراض التجميع والعرض في السجل فقط
  DateTimeColumn get date => dateTime()();

  // بداية الفترة المُغطاة بهذا التقرير (وقت آخر إغلاق سابق، أو بداية اليوم إذا
  // كان هذا أول إغلاق على الإطلاق) - هذا ما يجعل كل تقرير خاصًا بفترة/نوبة عمل محددة
  DateTimeColumn get periodStart => dateTime()();

  RealColumn get totalSales => real()();
  RealColumn get totalReturns => real()();
  RealColumn get totalExpenses => real()();
  RealColumn get totalVendorPayments => real()();
  RealColumn get costOfGoodsSold => real()();
  RealColumn get netProfit => real()();
  RealColumn get cashInDrawer => real()();

  IntColumn get closedBy => integer().nullable().references(Users, #id)();
  TextColumn get reportPdfPath => text().nullable()();
  TextColumn get reportExcelPath => text().nullable()();
  TextColumn get backupPath => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
