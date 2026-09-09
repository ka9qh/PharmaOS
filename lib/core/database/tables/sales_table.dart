import 'package:drift/drift.dart';
import 'users_table.dart';
import 'customers_table.dart';
import 'wallets_table.dart';
import 'doctors_table.dart';
import 'prescriptions_table.dart';

@DataClassName('SaleRow')
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  TextColumn get invoiceNumber => text()();
  IntColumn get cashierId => integer().nullable().references(Users, #id)();

  // غير فارغ فقط عندما paymentMethod = 'آجل' - البيع بالدين لعميل محدد
  // (راجع docs/WORKFLOW.md قسم البيع الآجل، أُضيف في Phase 9)
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  
  // Phase 2: ربط الفاتورة بطبيب أو وصفة
  IntColumn get doctorId => integer().nullable().references(Doctors, #id)();
  IntColumn get prescriptionId => integer().nullable().references(Prescriptions, #id)();

  RealColumn get totalAmount => real()();
  
  // الضرائب
  RealColumn get subTotal => real().withDefault(const Constant(0.0))(); // المبلغ قبل الضريبة
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))(); // قيمة الضريبة الإجمالية

  RealColumn get discount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('نقدي'))(); // 'نقدي', 'آجل', 'محفظة'

  // إذا كانت طريقة الدفع محفظة، يتم تحديد المعرف هنا
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();

  // completed | returned | partially_returned - راجع docs/DATABASE_DESIGN.md
  // ميزة Returns (مرحلة لاحقة) ستستخدم هذا الحقل بدلاً من حذف أي فاتورة نهائيًا.
  TextColumn get status => text().withDefault(const Constant('completed'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {invoiceNumber},
      ];
}
