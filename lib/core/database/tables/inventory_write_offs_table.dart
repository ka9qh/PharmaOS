import 'package:drift/drift.dart';
import 'medicines_table.dart';
import 'users_table.dart';

@DataClassName('WriteOffRow')
class InventoryWriteOffs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pharmacyId => integer().withDefault(const Constant(1))();
  
  IntColumn get medicineId => integer().references(Medicines, #id)();
  RealColumn get quantity => real()();
  TextColumn get reason => text()(); // سبب الإتلاف (منتهي، تالف، أخرى)
  TextColumn get notes => text().nullable()();
  
  IntColumn get recordedBy => integer().nullable().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
