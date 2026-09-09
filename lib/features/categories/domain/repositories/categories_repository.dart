import '../entities/categories_entity.dart';

abstract class CategoriesRepository {
  Future<List<CategoryEntity>> getAll();
  Future<CategoryEntity> create(String name);
}
