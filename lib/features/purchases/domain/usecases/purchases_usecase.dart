import '../entities/purchases_entity.dart';
import '../repositories/purchases_repository.dart';

class CreatePurchaseUseCase {
  final PurchasesRepository _repo;
  const CreatePurchaseUseCase(this._repo);

  Future<PurchaseEntity> call({
    required int supplierId,
    String? supplierInvoiceRef,
    required List<PurchaseLineInput> items,
    required double paidAmount,
    String? invoiceImagePath,
  }) async {
    return _repo.createPurchase(
      supplierId: supplierId,
      supplierInvoiceRef: supplierInvoiceRef,
      items: items,
      paidAmount: paidAmount,
      invoiceImagePath: invoiceImagePath,
    );
  }
}

class ListPurchasesUseCase {
  final PurchasesRepository _repo;
  const ListPurchasesUseCase(this._repo);
  Future<List<PurchaseEntity>> call({int limit = 50}) => _repo.listRecent(limit: limit);
}
