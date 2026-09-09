import '../../domain/entities/returns_entity.dart';
import '../../domain/repositories/returns_repository.dart';
import '../datasources/returns_datasource.dart';
import '../../../../core/security/audit_logger.dart';

class ReturnsRepositoryImpl implements ReturnsRepository {
  final ReturnsDataSource dataSource;
  final AuditLogger auditLogger;

  ReturnsRepositoryImpl({
    required this.dataSource,
    required this.auditLogger,
  });

  @override
  Future<SaleLookupResult?> findSaleByInvoiceNumber(String invoiceNumber) {
    return dataSource.findSaleByInvoiceNumber(invoiceNumber);
  }

  @override
  Future<List<SaleLookupResult>> findSalesByMedicineName(String medicineName) {
    return dataSource.findSalesByMedicineName(medicineName);
  }

  @override
  Future<List<SaleLookupResult>> getRecentSalesForReturns({int limit = 50}) {
    return dataSource.getRecentSalesForReturns(limit: limit);
  }

  @override
  Future<PurchaseLookupResult?> findPurchaseByNumber(String purchaseNumber) {
    return dataSource.findPurchaseByNumber(purchaseNumber);
  }

  @override
  Future<void> createCustomerReturn({
    required int saleItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    required double refundAmount,
    required String settlementMethod,
    required String paymentMethod,
    int? walletId,
    String? reason,
  }) async {
    await dataSource.createCustomerReturnTransactional(
      saleItemId: saleItemId,
      quantity: quantity,
      qtyCarton: qtyCarton,
      qtyPack: qtyPack,
      qtyStrip: qtyStrip,
      qtyPill: qtyPill,
      reason: reason,
      processedBy: null, // Since we removed it from interface, or we can inject AuthProvider. For now null.
    );
    await auditLogger.log(
      actionType: 'CUSTOMER_RETURN',
      tableName: 'sale_items',
      recordId: saleItemId.toString(),
      userId: null,
      newValue: 'quantity=$quantity, amount=$refundAmount, reason=$reason',
    );
  }

  @override
  Future<void> processBulkCustomerReturn({
    required int saleId,
    required Map<int, int> returnQuantities,
    required double totalRefundAmount,
    required String settlementMethod,
    required String paymentMethod,
    int? walletId,
    String? reason,
  }) async {
    await dataSource.processBulkCustomerReturn(
      saleId: saleId,
      returnQuantities: returnQuantities,
      reason: reason,
      processedBy: null,
    );
    await auditLogger.log(
      actionType: 'BULK_CUSTOMER_RETURN',
      tableName: 'sales',
      recordId: saleId.toString(),
      userId: null,
      newValue: 'items_returned=${returnQuantities.length}, totalRefund=$totalRefundAmount, reason=$reason',
    );
  }

  @override
  Future<void> createVendorReturn({
    required int purchaseItemId,
    required int quantity,
    required int qtyCarton,
    required int qtyPack,
    required int qtyStrip,
    required int qtyPill,
    required double refundAmount,
    required String settlementMethod,
    required String paymentMethod,
    int? walletId,
    String? reason,
  }) async {
    await dataSource.createVendorReturnTransactional(
      purchaseItemId: purchaseItemId,
      quantity: quantity,
      qtyCarton: qtyCarton,
      qtyPack: qtyPack,
      qtyStrip: qtyStrip,
      qtyPill: qtyPill,
      reason: reason,
      processedBy: null,
    );
    await auditLogger.log(
      actionType: 'VENDOR_RETURN',
      tableName: 'purchase_items',
      recordId: purchaseItemId.toString(),
      userId: null,
      newValue: 'quantity=$quantity, amount=$refundAmount, reason=$reason',
    );
  }

  @override
  Future<double> getTodayReturnsTotal() {
    return dataSource.getTodayReturnsTotal();
  }
}
