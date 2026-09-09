import '../entities/categories_entity.dart';
import '../repositories/categories_repository.dart';

class ListCategoriesUseCase {
  final CategoriesRepository _repo;
  const ListCategoriesUseCase(this._repo);
  Future<List<CategoryEntity>> call() => _repo.getAll();
}

class CreateCategoryUseCase {
  final CategoriesRepository _repo;
  const CreateCategoryUseCase(this._repo);
  Future<CategoryEntity> call(String name) => _repo.create(name);
}

class UpdateCategoryUseCase {
  final CategoriesRepository _repo;
  const UpdateCategoryUseCase(this._repo);
  Future<void> call(int id, String newName) async {}
}
class ArchiveCategoryUseCase {
  final CategoriesRepository _repo;
  const ArchiveCategoryUseCase(this._repo);
  Future<void> call(int id) async {}
}
class UpdateCategoriesOrderUseCase {
  final CategoriesRepository _repo;
  const UpdateCategoriesOrderUseCase(this._repo);
  Future<void> call(List<int> ids) async {}
}
