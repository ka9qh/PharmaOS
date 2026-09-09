import '../entities/accounting_entity.dart';

abstract class AccountingRepository {
  /// رصيد كل مورد = إجمالي ما اشتُري منه (paidAmount عند الفاتورة + التسديدات
  /// اللاحقة) مقابل إجمالي قيمة فواتيره - محسوب من السجل مباشرة (Ledger)
  /// وليس عمودًا مخزَّنًا، لتفادي أي تضارب بيانات لاحقًا. راجع docs/DATABASE_DESIGN.md.
  Future<List<SupplierBalance>> getSupplierBalances();

  /// جلب فواتير الشراء التي لا يزال عليها رصيد متبقٍ
  Future<List<UnpaidPurchaseInvoice>> getUnpaidPurchaseInvoices();

  /// جلب سجل التسديدات الأخيرة
  Future<List<VendorPaymentEntity>> getRecentPayments({int limit = 50});

  Future<VendorPaymentEntity> recordVendorPayment({
    required int supplierId,
    required double amount,
    required String paymentMethod,
    int? walletId,
    String? notes,
    int? recordedBy,
  });
}
