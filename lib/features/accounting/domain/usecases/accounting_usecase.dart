import '../entities/accounting_entity.dart';
import '../repositories/accounting_repository.dart';

class GetSupplierBalancesUseCase {
  final AccountingRepository _repo;
  const GetSupplierBalancesUseCase(this._repo);
  Future<List<SupplierBalance>> call() => _repo.getSupplierBalances();
}

class RecordVendorPaymentUseCase {
  final AccountingRepository _repo;
  const RecordVendorPaymentUseCase(this._repo);

  Future<VendorPaymentEntity> call({
    required int supplierId,
    required double amount,
    String? notes,
    int? recordedBy,
  }) {
    return _repo.recordVendorPayment(
      supplierId: supplierId,
      amount: amount,
      paymentMethod: 'نقدي',
      notes: notes,
      recordedBy: recordedBy,
    );
  }
}
