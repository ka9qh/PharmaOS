import 'package:drift/drift.dart';
import 'users_table.dart';
import 'warehouses_table.dart';
import 'medicines_table.dart';
import 'batches_table.dart';

@DataClassName('StockTransferRow')
class StockTransfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get referenceNumber => text()(); // رقم الحركة
  IntColumn get fromWarehouseId => integer().references(Warehouses, #id)();
  IntColumn get toWarehouseId => integer().references(Warehouses, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  IntColumn get batchId => integer().references(Batches, #id)();
  IntColumn get quantity => integer()();
  
  IntColumn get transferredBy => integer().references(Users, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
