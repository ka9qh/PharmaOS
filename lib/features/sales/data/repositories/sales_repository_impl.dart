import '../../domain/entities/sales_entity.dart';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_datasource.dart';
import '../models/sales_model.dart';
import '../../../../core/security/audit_logger.dart';

class SalesRepositoryImpl implements SalesRepository {
  final SalesDataSource dataSource;
  final AuditLogger auditLogger;

  SalesRepositoryImpl({
    required this.dataSource,
    required this.auditLogger,
  });

  @override
  Future<SaleEntity> createSale({
    required List<CartLineInput> items,
    required double discount,
    required String paymentMethod,
    int? walletId,
    int? cashierId,
    int? customerId,
    int? doctorId,
    int? prescriptionId,
    double? initialPayment,
  }) async {
    final row = await dataSource.createSaleTransactional(
      items: items,
      discount: discount,
      paymentMethod: paymentMethod,
      
      cashierId: cashierId,
      customerId: customerId,
      doctorId: doctorId,
      prescriptionId: prescriptionId,
    );

    await auditLogger.log(
      actionType: 'SALE_CREATED',
      tableName: 'sales',
      recordId: row.id.toString(),
      userId: cashierId,
      newValue: 'invoice=${row.invoiceNumber}, total=${row.totalAmount}',
    );

    return row.toEntity();
  }

  @override
  Future<double> getTodaySalesTotal() => dataSource.getTodaySalesTotal();

  @override
  Future<void> suspendSale({
    required List<CartLineInput> items,
    int? cashierId,
    int? customerId,
    String? referenceNote,
  }) async {
    await dataSource.suspendSale(
      items: items,
      cashierId: cashierId,
      customerId: customerId,
      referenceNote: referenceNote,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getSuspendedSales() async {
    final rows = await dataSource.getSuspendedSales();
    return rows.map((r) => {
      'id': r.id,
      'createdAt': r.createdAt.toIso8601String(),
      'referenceNote': r.referenceNote ?? 'بدون ملاحظة',
      'cartData': r.cartData, // JSON string
    }).toList();
  }

  @override
  Future<void> deleteSuspendedSale(int id) async {
    await dataSource.deleteSuspendedSale(id);
  }
}
