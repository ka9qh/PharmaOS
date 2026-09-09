import '../entities/returns_entity.dart';

abstract class ReturnsRepository {
  Future<SaleLookupResult?> findSaleByInvoiceNumber(String invoiceNumber);
  Future<List<SaleLookupResult>> findSalesByMedicineName(String medicineName);
  Future<List<SaleLookupResult>> getRecentSalesForReturns({int limit = 50});
  Future<PurchaseLookupResult?> findPurchaseByNumber(String purchaseNumber);

  Future<void> processBulkCustomerReturn({
    required int saleId,
    required Map<int, int> returnQuantities,
    required double totalRefundAmount,
    required String settlementMethod,
    required String paymentMethod,
    int? walletId,
    String? reason,
  });

  /// مرتجع عميل: يعيد الكمية إلى نفس الدفعة (Batch) التي بيعت منها بالضبط،
  /// ويحدّث حالة الفاتورة (completed/partially_returned/returned).
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
  });

  /// مرتجع مورد: يخصم الكمية من نفس الدفعة التي استُلمت فيها (إرجاع بضاعة للمورد).
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
  });

  Future<double> getTodayReturnsTotal();
}
