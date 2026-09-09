import '../../../../core/database/app_database.dart';
import '../../domain/entities/companies_entity.dart';

extension CompanyRowMapper on CompanyRow {
  CompanyEntity toEntity() => CompanyEntity(
    id: id, 
    name: name,
    nameEn: nameEn,
    nameAr: nameAr,
    countryAr: countryAr,
    countryEn: countryEn,
  );
}
