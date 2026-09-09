import 'package:drift/drift.dart';
import 'medicines_table.dart';

// دفعات المخزون: تتبع الكمية وتاريخ الصلاحية لكل استلام بضاعة على حدة (FEFO)
@DataClassName('BatchRow')
class Batches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  IntColumn get quantity => integer()();
  RealColumn get purchasePrice => real()();
  IntColumn get warehouseId => integer().nullable()(); // Added for Multi-Warehousing
  DateTimeColumn get receivedAt => dateTime().withDefault(currentDateAndTime)();
}
