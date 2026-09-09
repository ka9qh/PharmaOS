class PurchaseReturnEntity {
  final int id;
  final String referenceNumber;
  final int supplierId;
  final String supplierName;
  final double totalAmount;
  final String paymentMethod;
  final DateTime createdAt;
  final String? notes;
  final List<PurchaseReturnItemEntity> items;

  PurchaseReturnEntity({
    required this.id,
    required this.referenceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    this.notes,
    required this.items,
  });
}

class PurchaseReturnItemEntity {
  final int medicineId;
  final String medicineName;
  final int batchId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String reason;

  PurchaseReturnItemEntity({
    required this.medicineId,
    required this.medicineName,
    required this.batchId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.reason,
  });
}
