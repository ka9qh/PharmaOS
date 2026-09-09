import '../../../../core/database/app_database.dart';
import '../../domain/entities/categories_entity.dart';

extension CategoryRowMapper on CategoryRow {
  CategoryEntity toEntity() => CategoryEntity(
    id: id, 
    name: name,
    nameEn: nameEn,
    nameAr: nameAr,
  );
}
