import '../entities/purchase_returns_entity.dart';

class PurchaseReturnItemInput {
  final int medicineId;
  final int batchId;
  final int quantity;
  final double unitPrice;
  final String reason;

  PurchaseReturnItemInput({
    required this.medicineId,
    required this.batchId,
    required this.quantity,
    required this.unitPrice,
    required this.reason,
  });
}

abstract class PurchaseReturnsRepository {
  Future<PurchaseReturnEntity> createPurchaseReturn({
    required int supplierId,
    required String paymentMethod,
    required List<PurchaseReturnItemInput> items,
    int? recordedBy,
    String? notes,
  });

  Future<List<PurchaseReturnEntity>> getAllPurchaseReturns();
}
