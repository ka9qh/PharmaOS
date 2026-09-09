class MedicineEntity {
  final int id;
  final String nameAr;
  final String? nameEn;
  final String? nameScientific;
  final int? categoryId;
  final String? categoryName;
  final int? companyId;
  final String? companyName;
  final int? supplierId;
  final String? supplierName;
  final String sku;
  final String barcode;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final int? qtyPerPack;
  final int? qtyPerStrip;
  final int? qtyPerCarton;
  final double? packPurchasePrice;
  final double? packSellingPrice;
  final double? stripPurchasePrice;
  final double? stripSellingPrice;
  final double? cartonPurchasePrice;
  final double? cartonSellingPrice;
  final int reorderLevel;
  final bool isActive;
  final String? reserveField1;
  final String? reserveField2;
  final String? reserveField3;
  final int medicineType; // 0: None, 1: Pills, 2: Injections, 3: Glass, 4: Diapers, 5: Cosmetics

  const MedicineEntity({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.nameScientific,
    this.categoryId,
    this.categoryName,
    this.companyId,
    this.companyName,
    this.supplierId,
    this.supplierName,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    this.qtyPerPack,
    this.qtyPerStrip,
    this.qtyPerCarton,
    this.packPurchasePrice,
    this.packSellingPrice,
    this.stripPurchasePrice,
    this.stripSellingPrice,
    this.cartonPurchasePrice,
    this.cartonSellingPrice,
    required this.reorderLevel,
    required this.isActive,
    this.reserveField1,
    this.reserveField2,
    this.reserveField3,
    required this.medicineType,
  });

  MedicineEntity copyWith({
    String? nameAr,
    String? nameEn,
    String? nameScientific,
    int? categoryId,
    String? categoryName,
    int? companyId,
    String? companyName,
    int? supplierId,
    String? supplierName,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    int? qtyPerPack,
    int? qtyPerStrip,
    int? qtyPerCarton,
    double? packPurchasePrice,
    double? packSellingPrice,
    double? stripPurchasePrice,
    double? stripSellingPrice,
    double? cartonPurchasePrice,
    double? cartonSellingPrice,
    int? reorderLevel,
    bool? isActive,
    String? reserveField1,
    String? reserveField2,
    String? reserveField3,
    int? medicineType,
  }) {
    return MedicineEntity(
      id: id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      nameScientific: nameScientific ?? this.nameScientific,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      sku: sku,
      barcode: barcode,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      qtyPerPack: qtyPerPack ?? this.qtyPerPack,
      qtyPerStrip: qtyPerStrip ?? this.qtyPerStrip,
      qtyPerCarton: qtyPerCarton ?? this.qtyPerCarton,
      packPurchasePrice: packPurchasePrice ?? this.packPurchasePrice,
      packSellingPrice: packSellingPrice ?? this.packSellingPrice,
      stripPurchasePrice: stripPurchasePrice ?? this.stripPurchasePrice,
      stripSellingPrice: stripSellingPrice ?? this.stripSellingPrice,
      cartonPurchasePrice: cartonPurchasePrice ?? this.cartonPurchasePrice,
      cartonSellingPrice: cartonSellingPrice ?? this.cartonSellingPrice,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      isActive: isActive ?? this.isActive,
      reserveField1: reserveField1 ?? this.reserveField1,
      reserveField2: reserveField2 ?? this.reserveField2,
      reserveField3: reserveField3 ?? this.reserveField3,
      medicineType: medicineType ?? this.medicineType,
    );
  }
}
