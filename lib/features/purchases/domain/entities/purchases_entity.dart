// مدخل سطر واحد عند إنشاء فاتورة شراء - كل سطر يُنشئ دفعة (Batch) جديدة عند الحفظ
class PurchaseLineInput {
  final int medicineId;
  final String medicineName;
  final int quantity; // الكمية بوحدة الأساس
  final double unitCost; // التكلفة لوحدة الأساس
  final double? sellingPrice; // سعر البيع المراد تحديثه (اختياري)
  final String unitName;
  final int selectedQuantity;
  final String? batchNumber;
  final DateTime? expiryDate;
  final int? qtyCarton;
  final int? qtyPack;
  final int? qtyStrip;
  final int? qtyPill;

  const PurchaseLineInput({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitCost,
    this.sellingPrice,
    required this.unitName,
    required this.selectedQuantity,
    this.batchNumber,
    this.expiryDate,
    this.qtyCarton,
    this.qtyPack,
    this.qtyStrip,
    this.qtyPill,
  });
}

class PurchaseItemEntity {
  final int medicineId;
  final String medicineName;
  final int quantity;
  final double unitCost;
  final double subtotal;
  final String? unitName;
  final int? selectedQuantity;
  final int? qtyCarton;
  final int? qtyPack;
  final int? qtyStrip;
  final int? qtyPill;

  const PurchaseItemEntity({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
    this.unitName,
    this.selectedQuantity,
    this.qtyCarton,
    this.qtyPack,
    this.qtyStrip,
    this.qtyPill,
  });
}

class PurchaseEntity {
  final int id;
  final String purchaseNumber;
  final String? supplierInvoiceRef;
  final int supplierId;
  final String supplierName;
  final double totalAmount;
  final double paidAmount;
  final String? invoiceImagePath;
  final DateTime createdAt;

  const PurchaseEntity({
    required this.id,
    required this.purchaseNumber,
    this.supplierInvoiceRef,
    required this.supplierId,
    required this.supplierName,
    required this.totalAmount,
    required this.paidAmount,
    this.invoiceImagePath,
    required this.createdAt,
  });

  double get remainingAmount => totalAmount - paidAmount;
}
