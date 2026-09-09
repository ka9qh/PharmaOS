import 'package:drift/drift.dart';
import 'sales_table.dart';
import 'purchases_table.dart';
import 'users_table.dart';
import 'wallets_table.dart';

// مرتجع واحد إما مرتبط بفاتورة بيع (مرتجع عميل) أو فاتورة شراء (مرتجع مورد)
// - أحدهما فقط يكون غير فارغ. راجع docs/DATABASE_DESIGN.md و WORKFLOW.md
@DataClassName('ReturnRow')
class Returns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  IntColumn get purchaseId => integer().nullable().references(Purchases, #id)();
  
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  TextColumn get settlementMethod => text().withDefault(const Constant('refund'))(); // 'refund', 'deduction', 'replacement'
  TextColumn get paymentMethod => text().withDefault(const Constant('نقدي'))(); // 'نقدي', 'محفظة' (if refund)
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();
  
  TextColumn get reason => text().nullable()();
  IntColumn get processedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
