import '../../../../core/database/app_database.dart';
import '../../domain/entities/suppliers_entity.dart';

extension SupplierRowMapper on SupplierRow {
  SupplierEntity toEntity() => SupplierEntity(
        id: id,
        name: name,
        nameEn: nameEn,
        nameAr: nameAr,
        shortName: shortName,
        representedCompanies: representedCompanies,
        contactInfo: contactInfo,
        notes: notes,
      );
}
