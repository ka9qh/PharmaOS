import 'package:drift/drift.dart';
import '../database/app_database.dart';

class MedicineUnitConfig {
  final int id;
  final int medicineId;
  final int levelOrder;
  final String unitName;
  final int multiplier;
  final double? purchasePrice;
  final double? sellingPrice;

  const MedicineUnitConfig({
    required this.id,
    required this.medicineId,
    required this.levelOrder,
    required this.unitName,
    required this.multiplier,
    this.purchasePrice,
    this.sellingPrice,
  });

  factory MedicineUnitConfig.fromRow(dynamic row) {
    return MedicineUnitConfig(
      id: row.id,
      medicineId: row.medicineId,
      levelOrder: row.levelOrder,
      unitName: row.unitName,
      multiplier: row.multiplier,
      purchasePrice: row.purchasePrice,
      sellingPrice: row.sellingPrice,
    );
  }
}

class MedicineUnitsService {
  final dynamic _db;
  MedicineUnitsService(this._db);

  Future<List<MedicineUnitConfig>> getUnits(int medicineId) async {
    final query = _db.select(_db.medicineUnits)
      ..where((t) => t.medicineId.equals(medicineId))
      ..orderBy([(t) => OrderingTerm(expression: t.levelOrder, mode: OrderingMode.asc)]);
    final rows = await query.get();
    return rows.map((r) => MedicineUnitConfig.fromRow(r)).toList();
  }

  Future<void> saveUnits(int medicineId, List<MedicineUnitConfig> units) async {
    await _db.transaction(() async {
      // حذف الوحدات القديمة
      await (_db.delete(_db.medicineUnits)..where((t) => t.medicineId.equals(medicineId))).go();
      
      // إدراج الوحدات الجديدة
      for (final unit in units) {
        await _db.into(_db.medicineUnits).insert(
              MedicineUnitsCompanion.insert(
                medicineId: unit.medicineId,
                levelOrder: unit.levelOrder,
                unitName: unit.unitName,
                multiplier: Value(unit.multiplier),
                purchasePrice: Value(unit.purchasePrice),
                sellingPrice: Value(unit.sellingPrice),
              ),
            );
      }
    });
  }

  Future<void> clearUnits(int medicineId) async {
    await (_db.delete(_db.medicineUnits)..where((t) => t.medicineId.equals(medicineId))).go();
  }
}
