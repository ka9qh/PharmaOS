import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

abstract class CategoriesDataSource {
  Future<List<CategoryRow>> getAll();
  Future<CategoryRow> create(String name);
}

class CategoriesDataSourceImpl implements CategoriesDataSource {
  final AppDatabase _db;
  CategoriesDataSourceImpl(this._db);

  @override
  Future<List<CategoryRow>> getAll() {
    return (_db.select(_db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  @override
  Future<CategoryRow> create(String name) async {
    final id = await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(name: name.trim()),
        );
    return (_db.select(_db.categories)..where((c) => c.id.equals(id)))
        .getSingle();
  }
}
