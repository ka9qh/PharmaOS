import 'package:drift/drift.dart';
import 'suppliers_table.dart';
import 'users_table.dart';
import 'wallets_table.dart';
import 'purchases_table.dart';

@DataClassName('VendorPaymentRow')
class VendorPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  IntColumn get purchaseId => integer().nullable().references(Purchases, #id)();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  
  TextColumn get paymentMethod => text().withDefault(const Constant('نقدي'))(); // 'نقدي', 'محفظة'
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();
  
  IntColumn get recordedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
