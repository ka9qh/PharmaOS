import 'package:drift/drift.dart';
import 'users_table.dart';
import 'customers_table.dart';

@DataClassName('HeldInvoiceRow')
class HeldInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cashierId => integer().nullable().references(Users, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  TextColumn get referenceNote => text().nullable()(); // مثلاً "العميل أبو محمد ذهب للسيارة"
  TextColumn get cartData => text()(); // JSON string للمنتجات في السلة
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
