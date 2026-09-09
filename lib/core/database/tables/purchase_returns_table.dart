import 'package:drift/drift.dart';
import 'users_table.dart';
import 'suppliers_table.dart';

@DataClassName('PurchaseReturnRow')
class PurchaseReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get referenceNumber => text()(); // رقم فاتورة المرتجع
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  RealColumn get totalAmount => real()(); // إجمالي قيمة المرتجع
  TextColumn get paymentMethod => text().withDefault(const Constant('آجل'))(); // غالباً خصم من الحساب (آجل) أو نقدي
  IntColumn get recordedBy => integer().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
