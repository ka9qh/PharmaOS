import '../entities/returns_entity.dart';
import '../repositories/returns_repository.dart';

class FindSaleByInvoiceUseCase {
  final ReturnsRepository _repo;
  const FindSaleByInvoiceUseCase(this._repo);
  Future<SaleLookupResult?> call(String invoiceNumber) =>
      _repo.findSaleByInvoiceNumber(invoiceNumber);
}

class FindPurchaseByNumberUseCase {
  final ReturnsRepository _repo;
  const FindPurchaseByNumberUseCase(this._repo);
  Future<PurchaseLookupResult?> call(String purchaseNumber) =>
      _repo.findPurchaseByNumber(purchaseNumber);
}

class CreateCustomerReturnUseCase {
  final ReturnsRepository _repo;
  const CreateCustomerReturnUseCase(this._repo);
  Future<void> call({
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
  }) {
    return _repo.createCustomerReturn(
      saleItemId: saleItemId,
      quantity: quantity,
      qtyCarton: qtyCarton,
      qtyPack: qtyPack,
      qtyStrip: qtyStrip,
      qtyPill: qtyPill,
      refundAmount: refundAmount,
      settlementMethod: settlementMethod,
      paymentMethod: paymentMethod,
      walletId: walletId,
      reason: reason,
    );
  }
}

class CreateVendorReturnUseCase {
  final ReturnsRepository _repo;
  const CreateVendorReturnUseCase(this._repo);
  Future<void> call({
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
  }) {
    return _repo.createVendorReturn(
      purchaseItemId: purchaseItemId,
      quantity: quantity,
      qtyCarton: qtyCarton,
      qtyPack: qtyPack,
      qtyStrip: qtyStrip,
      qtyPill: qtyPill,
      refundAmount: refundAmount,
      settlementMethod: settlementMethod,
      paymentMethod: paymentMethod,
      walletId: walletId,
      reason: reason,
    );
  }
}
