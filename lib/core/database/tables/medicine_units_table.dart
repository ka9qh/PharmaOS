import 'package:drift/drift.dart';
import 'medicines_table.dart';

@DataClassName('MedicineUnitRow')
class MedicineUnits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicineId => integer().references(Medicines, #id, onDelete: KeyAction.cascade)();
  IntColumn get levelOrder => integer()(); // 1 = Base, 2 = Next level, etc.
  TextColumn get unitName => text()(); // e.g. Pill, Strip, Pack, Carton
  IntColumn get multiplier => integer().withDefault(const Constant(1))(); // Number of (levelOrder - 1) items in this level
  RealColumn get purchasePrice => real().nullable()();
  RealColumn get sellingPrice => real().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {medicineId, levelOrder},
      ];
}
