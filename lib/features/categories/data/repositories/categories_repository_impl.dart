import '../../domain/entities/categories_entity.dart';
import '../../domain/repositories/categories_repository.dart';
import '../datasources/categories_datasource.dart';
import '../models/categories_model.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  final CategoriesDataSource dataSource;
  CategoriesRepositoryImpl(this.dataSource);

  @override
  Future<List<CategoryEntity>> getAll() async {
    final rows = await dataSource.getAll();
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<CategoryEntity> create(String name) async {
    final row = await dataSource.create(name);
    return row.toEntity();
  }
}
