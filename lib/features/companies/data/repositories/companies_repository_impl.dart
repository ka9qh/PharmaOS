
import '../../domain/entities/companies_entity.dart';
import '../../domain/repositories/companies_repository.dart';
import '../datasources/companies_datasource.dart';
import '../models/companies_model.dart';

class CompaniesRepositoryImpl implements CompaniesRepository {
  @override
  Future<void> archive(int id) async {}
  @override
  Future<void> update(int id, String newName) async {}
  final CompaniesDataSource dataSource;
  CompaniesRepositoryImpl(this.dataSource);

  @override
  Future<List<CompanyEntity>> getAll() async {
    final rows = await dataSource.getAll();
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<CompanyEntity> create(String name) async {
    final row = await dataSource.create(name);
    return row.toEntity();
  }
}

