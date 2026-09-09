import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

abstract class CompaniesDataSource {
  Future<List<CompanyRow>> getAll();
  Future<CompanyRow> create(String name);
}

class CompaniesDataSourceImpl implements CompaniesDataSource {
  final AppDatabase _db;
  CompaniesDataSourceImpl(this._db);

  @override
  Future<List<CompanyRow>> getAll() {
    return (_db.select(_db.companies)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  @override
  Future<CompanyRow> create(String name) async {
    final id = await _db.into(_db.companies).insert(
          CompaniesCompanion.insert(name: name.trim()),
        );
    return (_db.select(_db.companies)..where((c) => c.id.equals(id)))
        .getSingle();
  }
}
