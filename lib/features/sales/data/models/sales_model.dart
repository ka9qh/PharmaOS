import '../../../../core/database/app_database.dart';
import '../../domain/entities/sales_entity.dart';

extension SaleRowMapper on SaleRow {
  SaleEntity toEntity() => SaleEntity(
        id: id,
        invoiceNumber: invoiceNumber,
        customerId: customerId,
        totalAmount: totalAmount,
        discount: discount,
        paymentMethod: paymentMethod,
        status: status,
        createdAt: createdAt,
      );
}
