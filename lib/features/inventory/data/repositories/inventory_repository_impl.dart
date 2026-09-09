import '../../domain/entities/inventory_entity.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_datasource.dart';

import '../../../../core/security/audit_logger.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryDataSource dataSource;
  final AuditLogger auditLogger;
  
  InventoryRepositoryImpl(this.dataSource, this.auditLogger);

  @override
  Future<List<StockSummary>> getStockOverview() async {
    final rows = await dataSource.getStockOverview();
    return rows
        .map((r) => StockSummary(
              medicineId: r.medicineId,
              medicineName: r.medicineName,
              totalQuantity: r.totalQuantity,
              reorderLevel: r.reorderLevel,
              barcode: r.barcode,
              sellingPrice: r.sellingPrice,
              purchasePrice: r.purchasePrice,
              batchId: r.batchId,
              batchNumber: r.batchNumber,
              expiryDate: r.expiryDate,
              qtyPerPack: r.qtyPerPack,
              qtyPerStrip: r.qtyPerStrip,
              qtyPerCarton: r.qtyPerCarton,
            ))
        .toList();
  }

  @override
  Future<int> getAvailableQuantity(int medicineId) {
    return dataSource.getAvailableQuantity(medicineId);
  }

  @override
  Future<List<BatchEntity>> getBatchesForMedicine(int medicineId) async {
    final batches = await dataSource.getBatchesForMedicine(medicineId);
    return batches.map((b) => BatchEntity(
      id: b.id,
      batchNumber: b.batchNumber,
      expiryDate: b.expiryDate,
      quantity: b.quantity,
    )).toList();
  }

  @override
  Future<void> receiveStock({
    required int medicineId,
    String? batchNumber,
    DateTime? expiryDate,
    required int quantity,
    required double purchasePrice,
  }) {
    return dataSource.receiveStock(
      medicineId: medicineId,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      quantity: quantity,
      purchasePrice: purchasePrice,
    );
  }

  @override
  Future<void> writeOffStock({
    required int medicineId,
    required int quantity,
    required String reason,
    String? notes,
    int? recordedBy,
  }) {
    return dataSource.writeOffStock(
      medicineId: medicineId,
      quantity: quantity,
      reason: reason,
      notes: notes,
      recordedBy: recordedBy,
    ).then((_) {
      auditLogger.log(
        actionType: 'WRITE_OFF',
        tableName: 'inventory_write_offs',
        recordId: medicineId.toString(),
        userId: recordedBy,
        newValue: 'quantity=$quantity, reason=$reason, notes=$notes',
      );
    });
  }

  @override
  Future<void> reconcileStock({
    required int medicineId,
    required double actualQuantity,
    required double systemQuantity,
    String? note,
    int? userId,
  }) {
    return dataSource.reconcileStock(
      medicineId: medicineId,
      actualQuantity: actualQuantity,
      systemQuantity: systemQuantity,
      note: note,
      userId: userId,
    ).then((_) {
      if (userId != null) {
        auditLogger.log(
          actionType: 'RECONCILIATION',
          tableName: 'inventory_reconciliations',
          recordId: medicineId.toString(),
          userId: userId,
          newValue: 'actual=$actualQuantity, system=$systemQuantity, note=$note',
        );
      }
    });
  }

  @override
  Future<void> deleteStockRecords(int medicineId) {
    return dataSource.deleteStockRecords(medicineId).then((_) {
      auditLogger.log(
        actionType: 'DELETE_STOCK',
        tableName: 'batches',
        recordId: medicineId.toString(),
        userId: null,
        newValue: 'Deleted all batches for medicine $medicineId',
      );
    });
  }

  @override
  Future<void> deleteSingleBatch(int batchId) {
    return dataSource.deleteSingleBatch(batchId).then((_) {
      auditLogger.log(
        actionType: 'DELETE_BATCH',
        tableName: 'batches',
        recordId: batchId.toString(),
        userId: null,
        newValue: 'Zeroed/Deleted batch $batchId',
      );
    });
  }
}
