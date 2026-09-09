import '../entities/purchases_entity.dart';

abstract class PurchasesRepository {
  /// ينشئ فاتورة شراء كاملة بشكل ذرّي: يُنشئ دفعة (Batch) جديدة لكل سطر،
  /// ويسجل بنود الفاتورة، دون المساس بأي دفعات موجودة سابقًا (على عكس البيع،
  /// الشراء لا يحتاج FEFO - فقط إضافة مخزون جديد).
  Future<PurchaseEntity> createPurchase({
    required int supplierId,
    String? supplierInvoiceRef,
    required List<PurchaseLineInput> items,
    required double paidAmount,
    String? invoiceImagePath,
  });

  Future<List<PurchaseEntity>> listRecent({int limit = 50});

  Future<void> addPaymentToPurchase({
    required int purchaseId,
    required double amount,
    required String paymentMethod,
    int? walletId,
  });
}
