import '../../../../core/database/app_database.dart';
import '../../domain/entities/customers_entity.dart';

extension CustomerRowMapper on CustomerRow {
  CustomerEntity toEntity() => CustomerEntity(id: id, name: name, phone: phone, notes: notes);
}
