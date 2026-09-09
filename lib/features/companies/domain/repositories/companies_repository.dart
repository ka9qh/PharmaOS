import '../entities/companies_entity.dart';

abstract class CompaniesRepository {
  Future<List<CompanyEntity>> getAll();
  Future<CompanyEntity> create(String name);
  Future<void> update(int id, String newName);
  Future<void> archive(int id);
}
