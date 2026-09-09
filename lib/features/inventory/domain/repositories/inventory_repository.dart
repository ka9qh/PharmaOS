import '../entities/inventory_entity.dart';

abstract class InventoryRepository {
  Future<List<StockSummary>> getStockOverview();
  Future<int> getAvailableQuantity(int medicineId);
  Future<List<BatchEntity>> getBatchesForMedicine(int medicineId);

  Future<void> receiveStock({
    required int medicineId,
    String? batchNumber,
    DateTime? expiryDate,
    required int quantity,
    required double purchasePrice,
  });

  Future<void> writeOffStock({
    required int medicineId,
    required int quantity,
    required String reason,
    String? notes,
    int? recordedBy,
  });

  Future<void> reconcileStock({
    required int medicineId,
    required double actualQuantity,
    required double systemQuantity,
    String? note,
    int? userId,
  });

  Future<void> deleteStockRecords(int medicineId);
  Future<void> deleteSingleBatch(int batchId);
}
