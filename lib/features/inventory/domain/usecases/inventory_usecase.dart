import '../entities/inventory_entity.dart';
import '../repositories/inventory_repository.dart';

class GetStockOverviewUseCase {
  final InventoryRepository _repo;
  const GetStockOverviewUseCase(this._repo);
  Future<List<StockSummary>> call() => _repo.getStockOverview();
}

class GetAvailableQuantityUseCase {
  final InventoryRepository _repo;
  const GetAvailableQuantityUseCase(this._repo);
  Future<int> call(int medicineId) => _repo.getAvailableQuantity(medicineId);
}

class ReceiveStockUseCase {
  final InventoryRepository _repo;
  const ReceiveStockUseCase(this._repo);

  Future<void> call({
    required int medicineId,
    String? batchNumber,
    DateTime? expiryDate,
    required int quantity,
    required double purchasePrice,
  }) {
    return _repo.receiveStock(
      medicineId: medicineId,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      quantity: quantity,
      purchasePrice: purchasePrice,
    );
  }
}

class WriteOffStockUseCase {
  final InventoryRepository _repo;
  const WriteOffStockUseCase(this._repo);

  Future<void> call({
    required int medicineId,
    required int quantity,
    required String reason,
    String? notes,
    int? recordedBy,
  }) {
    return _repo.writeOffStock(
      medicineId: medicineId,
      quantity: quantity,
      reason: reason,
      notes: notes,
      recordedBy: recordedBy,
    );
  }
}

class DeleteStockRecordsUseCase {
  final InventoryRepository _repo;
  const DeleteStockRecordsUseCase(this._repo);
  Future<void> call(int medicineId) => _repo.deleteStockRecords(medicineId);
}
