import '../entities/companies_entity.dart';
import '../repositories/companies_repository.dart';

class ListCompaniesUseCase {
  final CompaniesRepository _repo;
  const ListCompaniesUseCase(this._repo);
  Future<List<CompanyEntity>> call() => _repo.getAll();
}

class CreateCompanyUseCase {
  final CompaniesRepository _repo;
  const CreateCompanyUseCase(this._repo);
  Future<CompanyEntity> call(String name) => _repo.create(name);
}

class UpdateCompanyUseCase {
  final CompaniesRepository _repo;
  const UpdateCompanyUseCase(this._repo);
  Future<void> call(int id, String newName) async {}
}
class ArchiveCompanyUseCase {
  final CompaniesRepository _repo;
  const ArchiveCompanyUseCase(this._repo);
  Future<void> call(int id) async {}
}
