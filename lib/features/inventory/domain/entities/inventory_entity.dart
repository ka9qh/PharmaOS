class StockSummary {
  final int medicineId;
  final String medicineName;
  final int totalQuantity;
  final int reorderLevel;
  final String? formattedQuantity;
  final String barcode;
  final double sellingPrice;
  final double purchasePrice;
  final int? batchId;
  final String? batchNumber;
  final DateTime? expiryDate;
  final int? qtyPerPack;
  final int? qtyPerStrip;
  final int? qtyPerCarton;

  const StockSummary({
    required this.medicineId,
    required this.medicineName,
    required this.totalQuantity,
    required this.reorderLevel,
    this.formattedQuantity,
    this.barcode = '',
    this.sellingPrice = 0.0,
    this.purchasePrice = 0.0,
    this.batchId,
    this.batchNumber,
    this.expiryDate,
    this.qtyPerPack,
    this.qtyPerStrip,
    this.qtyPerCarton,
  });

  bool get isLow => totalQuantity <= reorderLevel;

  StockSummary copyWith({String? formattedQuantity}) {
    return StockSummary(
      medicineId: medicineId,
      medicineName: medicineName,
      totalQuantity: totalQuantity,
      reorderLevel: reorderLevel,
      formattedQuantity: formattedQuantity ?? this.formattedQuantity,
      barcode: barcode,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      batchId: batchId,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      qtyPerPack: qtyPerPack,
      qtyPerStrip: qtyPerStrip,
      qtyPerCarton: qtyPerCarton,
    );
  }
}

class BatchEntity {
  final int id;
  final String? batchNumber;
  final DateTime? expiryDate;
  final int quantity;

  const BatchEntity({
    required this.id,
    this.batchNumber,
    this.expiryDate,
    required this.quantity,
  });
}
