import '../entities/sales_entity.dart';
import '../repositories/sales_repository.dart';

class CreateSaleUseCase {
  final SalesRepository _repo;
  const CreateSaleUseCase(this._repo);

  Future<SaleEntity> call({
    required List<CartLineInput> items,
    required double discount,
    required String paymentMethod,
    int? cashierId,
    int? customerId,
    int? doctorId,
    int? prescriptionId,
  }) {
    return _repo.createSale(
      items: items,
      discount: discount,
      paymentMethod: paymentMethod,
      cashierId: cashierId,
      customerId: customerId,
      doctorId: doctorId,
      prescriptionId: prescriptionId,
    );
  }
}

class GetTodaySalesTotalUseCase {
  final SalesRepository _repo;
  const GetTodaySalesTotalUseCase(this._repo);
  Future<double> call() => _repo.getTodaySalesTotal();
}
