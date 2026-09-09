// مصدر بيانات الأدوية - Drift
//
// تحديث أداء (دعم 100,000+ دواء وبحث سريع جدًا):
// الفلترة تتم داخل SQL نفسه (فهرس + FTS5 عند توفره)
// مع حد أقصى (limit) لحماية الواجهة من عرض عشرات الآلاف من الصفوف دفعة واحدة.

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

abstract class MedicinesDataSource {
  Future<List<MedicineRow>> getAll({String? searchQuery, int? limit});
  Future<MedicineRow?> getByBarcode(String barcode);
  Future<MedicineRow?> getById(int id);
  Future<MedicineRow> create(MedicinesCompanion companion);
  Future<void> update(int id, MedicinesCompanion companion);
  Future<void> archive(int id);
  Future<List<MedicineRow>> getAlternatives(int medicineId, String scientificName);
  Future<int> autoCleanDuplicates();
}

class MedicinesDataSourceImpl implements MedicinesDataSource {
  final AppDatabase _db;
  MedicinesDataSourceImpl(this._db);

  static const int _defaultLimit = 50000;

  @override
  Future<List<MedicineRow>> getAll({String? searchQuery, int? limit}) async {
    final q = searchQuery?.trim();
    final effectiveLimit = limit ?? _defaultLimit;

    if (q == null || q.isEmpty) {
      final query = _db.select(_db.medicines)
        ..where((m) => m.isActive.equals(true))
        ..orderBy([(m) => OrderingTerm.asc(m.id)])
        ..limit(effectiveLimit);
      return query.get();
    }

    // 1) محاولة بحث سريع عبر FTS5 (الأنسب لدعم مخزون ضخم من الأدوية).
    final ftsIds = await _db.searchMedicineIdsFast(q, limit: effectiveLimit);
    if (ftsIds.isNotEmpty) {
      final query = _db.select(_db.medicines)
        ..where((m) => m.id.isIn(ftsIds) & m.isActive.equals(true));
      final rows = await query.get();
      final order = {for (var i = 0; i < ftsIds.length; i++) ftsIds[i]: i};
      rows.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
      return rows;
    }

    // 2) fallback: بحث LIKE
    final pattern = '%$q%';
    final query = _db.select(_db.medicines)
      ..where((m) =>
          m.isActive.equals(true) &
          (m.nameAr.like(pattern) |
              m.nameEn.like(pattern) |
              m.nameScientific.like(pattern) |
              m.barcode.like(pattern) |
              m.sku.like(pattern)))
      ..orderBy([(m) => OrderingTerm.asc(m.nameAr)])
      ..limit(effectiveLimit);
    return query.get();
  }

  @override
  Future<MedicineRow?> getByBarcode(String barcode) {
    return (_db.select(_db.medicines)..where((m) => m.barcode.equals(barcode)))
        .getSingleOrNull();
  }

  @override
  Future<MedicineRow?> getById(int id) {
    return (_db.select(_db.medicines)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<MedicineRow> create(MedicinesCompanion companion) async {
    final id = await _db.into(_db.medicines).insert(companion);
    return (_db.select(_db.medicines)..where((m) => m.id.equals(id)))
        .getSingle();
  }

  @override
  Future<void> update(int id, MedicinesCompanion companion) {
    return (_db.update(_db.medicines)..where((m) => m.id.equals(id)))
        .write(companion);
  }

  @override
  Future<void> archive(int id) {
    return (_db.update(_db.medicines)..where((m) => m.id.equals(id)))
        .write(const MedicinesCompanion(isActive: Value(false)));
  }

  @override
  Future<List<MedicineRow>> getAlternatives(int medicineId, String scientificName) async {
    final s = scientificName.trim();
    if (s.isEmpty) return [];
    final pattern = '%$s%';
    final query = _db.select(_db.medicines)
      ..where((m) =>
          m.isActive.equals(true) &
          m.id.equals(medicineId).not() &
          (m.nameScientific.like(pattern) | m.nameScientific.equals(s)))
      ..orderBy([(m) => OrderingTerm.asc(m.nameAr)])
      ..limit(50);
    return query.get();
  }

  @override
  Future<int> autoCleanDuplicates() async {
    int mergedCount = 0;
    await _db.transaction(() async {
      final rows = await _db.customSelect(
        '''
        SELECT LOWER(TRIM(name_ar)) as name, GROUP_CONCAT(id) as ids 
        FROM medicines 
        WHERE is_active = 1 
        GROUP BY LOWER(TRIM(name_ar)) 
        HAVING COUNT(id) > 1
        '''
      ).get();

      for (final row in rows) {
        final idsStr = row.read<String>('ids');
        final idsList = idsStr.split(',').map(int.parse).toList();
        
        final primaryId = idsList.first;
        for (var i = 1; i < idsList.length; i++) {
          final dupId = idsList[i];
          
          await (_db.update(_db.saleItems)..where((t) => t.medicineId.equals(dupId))).write(SaleItemsCompanion(medicineId: Value(primaryId)));
          await (_db.update(_db.purchaseItems)..where((t) => t.medicineId.equals(dupId))).write(PurchaseItemsCompanion(medicineId: Value(primaryId)));
          await (_db.update(_db.returnItems)..where((t) => t.medicineId.equals(dupId))).write(ReturnItemsCompanion(medicineId: Value(primaryId)));
          await (_db.update(_db.batches)..where((t) => t.medicineId.equals(dupId))).write(BatchesCompanion(medicineId: Value(primaryId)));
          await (_db.update(_db.inventoryWriteOffs)..where((t) => t.medicineId.equals(dupId))).write(InventoryWriteOffsCompanion(medicineId: Value(primaryId)));
          
          await archive(dupId);
          mergedCount++;
        }
      }
    });
    return mergedCount;
  }
}
