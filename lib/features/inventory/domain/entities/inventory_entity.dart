import '../../../medicines/domain/entities/medicines_entity.dart';

class StockSummary {
  final int medicineId;
  final String medicineName;
  final String? nameEn;
  final String? nameScientific;
  final int? categoryId;
  final String? categoryName;
  final int? companyId;
  final String? companyName;
  final int? supplierId;
  final String? supplierName;
  final String unit;
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
  final double? packSellingPrice;
  final double? packPurchasePrice;
  final double? stripSellingPrice;
  final double? stripPurchasePrice;
  final double? cartonSellingPrice;
  final double? cartonPurchasePrice;
  final int medicineType;

  const StockSummary({
    required this.medicineId,
    required this.medicineName,
    this.nameEn,
    this.nameScientific,
    this.categoryId,
    this.categoryName,
    this.companyId,
    this.companyName,
    this.supplierId,
    this.supplierName,
    this.unit = 'باكت',
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
    this.packSellingPrice,
    this.packPurchasePrice,
    this.stripSellingPrice,
    this.stripPurchasePrice,
    this.cartonSellingPrice,
    this.cartonPurchasePrice,
    this.medicineType = 1,
  });

  bool get isLow => totalQuantity <= reorderLevel;

  MedicineEntity toMedicineEntity() {
    return MedicineEntity(
      id: medicineId,
      nameAr: medicineName,
      nameEn: nameEn,
      nameScientific: nameScientific,
      categoryId: categoryId,
      categoryName: categoryName,
      companyId: companyId,
      companyName: companyName,
      supplierId: supplierId,
      supplierName: supplierName,
      sku: barcode,
      barcode: barcode,
      unit: unit,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      qtyPerPack: qtyPerPack,
      qtyPerStrip: qtyPerStrip,
      qtyPerCarton: qtyPerCarton,
      packPurchasePrice: packPurchasePrice,
      packSellingPrice: packSellingPrice,
      stripPurchasePrice: stripPurchasePrice,
      stripSellingPrice: stripSellingPrice,
      cartonPurchasePrice: cartonPurchasePrice,
      cartonSellingPrice: cartonSellingPrice,
      reorderLevel: reorderLevel,
      isActive: true,
      medicineType: medicineType,
    );
  }

  StockSummary copyWith({
    String? formattedQuantity,
  }) {
    return StockSummary(
      medicineId: medicineId,
      medicineName: medicineName,
      nameEn: nameEn,
      nameScientific: nameScientific,
      categoryId: categoryId,
      categoryName: categoryName,
      companyId: companyId,
      companyName: companyName,
      supplierId: supplierId,
      supplierName: supplierName,
      unit: unit,
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
      packSellingPrice: packSellingPrice,
      packPurchasePrice: packPurchasePrice,
      stripSellingPrice: stripSellingPrice,
      stripPurchasePrice: stripPurchasePrice,
      cartonSellingPrice: cartonSellingPrice,
      cartonPurchasePrice: cartonPurchasePrice,
      medicineType: medicineType,
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
