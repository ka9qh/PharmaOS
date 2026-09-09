import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/needed_item_entity.dart';

class NeededItemsDataSource {
  final AppDatabase _db;
  NeededItemsDataSource(this._db);

  Future<List<NeededItemEntity>> getAll({bool includeResolved = false}) async {
    final query = _db.select(_db.neededItems);
    if (!includeResolved) {
      query.where((t) => t.isResolved.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toEntity).toList();
  }

  Future<NeededItemEntity> create({
    required String itemName,
    String? notes,
    String? customerName,
  }) async {
    final id = await _db.into(_db.neededItems).insert(
      NeededItemsCompanion.insert(
        itemName: itemName,
        notes: Value(notes),
        customerName: Value(customerName),
      ),
    );
    return NeededItemEntity(
      id: id,
      itemName: itemName,
      notes: notes,
      customerName: customerName,
      createdAt: DateTime.now(),
    );
  }

  Future<void> resolve(int id) async {
    await (_db.update(_db.neededItems)..where((t) => t.id.equals(id))).write(
      NeededItemsCompanion(
        isResolved: const Value(true),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.neededItems)..where((t) => t.id.equals(id))).go();
  }

  NeededItemEntity _toEntity(NeededItemRow row) {
    return NeededItemEntity(
      id: row.id,
      itemName: row.itemName,
      notes: row.notes,
      customerName: row.customerName,
      isResolved: row.isResolved,
      createdAt: row.createdAt,
      resolvedAt: row.resolvedAt,
    );
  }
}
